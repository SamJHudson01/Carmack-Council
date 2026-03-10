# Backend Quality Reference — Carmack × Collina × tRPC

Philosophy: John Carmack. Runtime expertise: Matteo Collina (Fastify, Pino, Node.js TSC). Patterns: tRPC community + Next.js App Router.
Stack context: Next.js App Router / React / TypeScript / tRPC / Prisma / Neon (serverless Postgres) / Clerk / CSS Modules + BEM.

Every finding must describe the **concrete failure mode** — not just "this is bad practice."
Security patterns are in security.md (Hunt). Performance is in the Vercel skill. Prisma/Neon/Postgres depth is in quality-postgres.md (Brandur). This doc covers: async correctness, error handling discipline, tRPC procedure design, and Next.js backend patterns.

---

## Principle 1: Programmer errors are assertion failures — crash, don't recover

*Carmack: assertions are tripwires. When an invariant is violated, halt execution.*
*Collina (via Joyent): "The best way to recover from programmer errors is to crash immediately."*

The Joyent error handling model classifies errors into two categories:

**Operational errors** — run-time problems experienced by correctly-written programs: network timeout, invalid user input, 503 from a dependency. Action: handle, retry with backoff, or propagate to the caller.

**Programmer errors** — bugs: reading property of `undefined`, wrong argument types, missing required fields. Action: crash immediately. The process is in an unknown state.

The argument for crashing is devastating and directly relevant to the Prisma/Neon stack. From the Joyent guide: continuing after a programmer error risks *"(1) Some piece of state shared by requests may be left null, undefined, or otherwise invalid. (2) A database connection may be leaked. (3) Worse, a postgres connection may be left inside an open transaction. This causes postgres to 'hang on' to old versions of rows in the table because they may be visible to that transaction. This can stay open for weeks, resulting in a table whose effective size grows without bound — causing subsequent queries to slow down by orders of magnitude."*

In serverless, each invocation dies after execution — "let it crash" is the default. But connection pool state persists across warm invocations on the same container. A leaked Prisma connection in one invocation poisons the pool for subsequent warm starts.

### What to check

**Swallowed errors**
- Empty catch blocks: `.catch(() => {})`, `catch (e) { /* ignore */ }`
- Unhandled rejection handlers that only log: `process.on('unhandledRejection', console.error)` — this disables the tripwire. Since Node.js v15, unhandled rejections crash the process by default. That's correct.
- Collina: **"The biggest problem is knowing that somebody will catch your errors. Especially with long promise chains and long async await, you need to know there is somebody at the end catching your things."**
- Concrete rule: never add `.catch(() => {})` to suppress a rejection you don't understand. If you can't explain what the rejection means and what state the process is in after catching it, let it crash.
- Severity: **P1** when the swallowed error involves database connections or shared state. **P2** for other cases.

**Mixed delivery mechanisms**
- Functions that throw synchronously in some code paths and reject asynchronously in others. Joyent: **"A given function should deliver operational errors either synchronously (with throw) or asynchronously (with a callback or event emitter), but not both."** Callers can't catch errors reliably when delivery is mixed.
- Severity: **P2**

**Retry storms**
- Every layer retrying independently. Joyent: **"If every layer of the stack thinks it needs to retry on errors, the user can end up waiting much longer than they should because each layer didn't realize that the underlying layer was also retrying."**
- In the tRPC stack: if tRPC middleware retries, AND the Prisma client retries, AND TanStack Query retries — a single transient failure triggers exponential retry amplification.
- Severity: **P2** when retries aren't documented/coordinated across layers.

**Async functions as event handlers**
- Passing an `async` function to `.on('data')` or any EventEmitter. Collina (JS Party #103): **"An async function can throw, and the promise will reject. But the problem is that nobody right now is catching that rejection for you."** The rejection goes unhandled, the resource is never cleaned up.
- Severity: **P1** — this is a memory leak and an unhandled rejection in one.

---

## Principle 2: Never hide what the event loop is doing

*Carmack: if you can't see the cost, you can't reason about correctness.*
*Collina: built Fastify because Express hides the runtime. Built Pino because logging shouldn't be opaque. Built Clinic.js because manual debugging is unreliable.*

### What to check

**Event loop blocking**
- Synchronous operations in tRPC procedures: `JSON.parse` on large payloads, `fs.readFileSync`, synchronous crypto, CPU-bound loops.
- Collina (USENIX SREcon 2023): **"The most common problem is an exhaustion of resources that allows the application to denial of service itself."** With 100 requests each requiring 30ms of synchronous work, the last request waits the accumulated time of all prior.
- In serverless: each invocation is isolated, so one blocked invocation doesn't block others. But **cold start time compounds with blocking** — 200ms of synchronous module initialisation adds to every cold request.
- Severity: **P1** for synchronous I/O in request paths. **P2** for CPU-bound work that could be deferred.

**Promises do NOT yield to the event loop**
- This is the most dangerous async misconception. Collina (Fosstodon, November 2024): **"Contrary to popular belief, in Node.js promises (and async/await) would not yield to the event loop."**
- `await` yields to the microtask queue, which is drained completely *before* the event loop proceeds to timers, I/O, or any other phase. A chain of synchronously-resolved promises stays entirely within microtasks.
- Concrete failure: a tRPC procedure that processes a large array with `await` inside a loop where each iteration resolves synchronously (in-memory transforms wrapped in `async`) blocks the entire event loop.
- Fix: insert `await new Promise(resolve => setImmediate(resolve))` periodically in CPU-bound async loops to yield.
- Severity: **P2** when the loop processes unbounded input. **P3** for small bounded loops.

**`process.nextTick` starvation**
- Recursive `process.nextTick` calls starve the event loop — I/O can never be processed. The `nextTick` queue drains between every event loop phase, before microtasks.
- Use `setImmediate` for yielding — it fires in the "check" phase, allowing I/O to process between iterations.
- Severity: **P1** for recursive `nextTick`. **P3** for single-use `nextTick` (usually fine).

**Hidden middleware costs**
- A procedure like `orgProcedure.input(z.object({...})).mutation(...)` hides that three middleware functions run before the resolver. If one middleware calls `currentUser()` (HTTP call to Clerk), that latency is invisible at the call site.
- Use `auth()` (reads JWT locally) unless you need the full user object. Know what each middleware costs.
- Severity: **P3** — this is transparency, not a bug. Escalate to **P2** if middleware makes external calls without the team knowing.

**Logging that hides its cost**
- Collina created Pino because logging was a throughput bottleneck. Benchmarks: Bunyan reduces throughput by ~70%, Winston by ~50%. Pino increases throughput by 40% over express-winston.
- Collina: **"You should not have very expensive logging because if you have very expensive logging, then you will be inclined to log less and not more."**
- Core Pino principles: JSON only in production (machines consume logs, not humans). Log to stdout, transport elsewhere in worker threads. Child loggers per request for context. Never format in-process.
- Severity: **P2** for using Winston/Bunyan in production. **P3** for logging without structured JSON.

---

## Principle 3: Validate at the boundary, sanitise at the exit

*Carmack: deploy assertions as tripwires — catch assumption violations before they propagate.*
*Collina + tRPC: Zod schemas at procedure boundaries ARE the tripwires.*

### What to check

**Loose Zod schemas**
- `.string()` where `.email()`, `.uuid()`, `.url()`, `.min()`, `.max()` is needed. Cost: a typo in the client sends `"undefined"` (the string) as a user ID, which queries the DB and returns null instead of failing fast at validation.
- Every tRPC mutation MUST have an `.input()` with a Zod schema. Every query with parameters likewise.
- Severity: **P2** for mutations without input validation. **P3** for queries with overly loose schemas.

**Prisma errors leaking through tRPC to the client**
- **This is a critical finding.** When a Prisma error propagates unhandled through tRPC: tRPC wraps it as `INTERNAL_SERVER_ERROR`, but **the original error message is still sent to the client**. Stack traces are stripped in production, messages are not.
- Concrete leak: a Prisma unique constraint error sends `"Unique constraint failed on the fields: (email)"` — revealing schema field names. A `prisma.create()` with wrong fields sends the expected schema shape.
- Fix: sanitise in `errorFormatter` (replace all `INTERNAL_SERVER_ERROR` messages with a generic string) AND translate known Prisma errors in middleware (P2002 → `CONFLICT`, P2025 → `NOT_FOUND`).
- Severity: **P1** — this is information disclosure. Cross-reference with security.md.

**Missing output validation on sensitive procedures**
- tRPC supports `.output()` for validating return values. If output validation fails, the server returns `INTERNAL_SERVER_ERROR` instead of leaking data.
- A procedure returning a full Prisma user model without output validation includes every field — including any sensitive ones the client shouldn't see.
- Use sparingly (adds runtime overhead) but mandate for procedures that return user data, billing data, or anything with PII.
- Severity: **P2** for procedures returning user/billing models without output filtering.

**Server Actions without validation**
- Every `'use server'` function compiles into a public HTTP POST endpoint. The action ID is visible in client bundles. Anyone can invoke it with arbitrary payloads via `curl`.
- Always validate inputs server-side with Zod — TypeScript types don't exist at runtime. Always check auth inside each action — don't assume it's only callable from an authenticated page.
- Consider `next-safe-action` for composable middleware (auth, rate limiting, structured results).
- Severity: **P1** for mutations without server-side validation. **P2** for missing auth checks in actions.

---

## Principle 4: The `protectedProcedure` pattern — auth as a type constraint

*Carmack: make the wrong thing impossible rather than trusting humans to do the right thing.*
*tRPC: middleware narrows context types, converting runtime checks into compile-time constraints.*

This is THE auth pattern for this stack. Auth logic lives in middleware, not in individual procedure resolvers.

### What to check

**Auth enforced ad hoc instead of via middleware**
- Procedures that check `ctx.auth.userId` inside the resolver body instead of using `protectedProcedure`. Cost: one developer forgets the check, one procedure is unprotected.
- With `protectedProcedure`, the resolver receives `ctx.auth` with `userId: string` (not `string | null`). If a developer accidentally uses `publicProcedure` for a protected route, they get a type error when accessing `ctx.auth.userId` as non-nullable.
- Severity: **P1** for unprotected procedures that should require auth. **P2** for ad hoc checks that work but aren't enforced by the type system.

**Missing org-scoped middleware for multi-tenant B2B**
- A `protectedProcedure` confirms the user exists but doesn't confirm they have access to the requested organisation's data. An `orgProcedure` that extends `protectedProcedure` with an `orgId` check is needed.
- Without this: every procedure that touches org-scoped data must manually verify org membership. One miss = IDOR.
- Severity: **P1** if org-scoped data is accessible without org verification.

**Middleware ordering bugs**
- Middleware executes in `.use()` chain order. If `orgMiddleware` runs before `authMiddleware`, `ctx.user` is still nullable — causing runtime errors or redundant null checks.
- Swallowed errors in middleware: if middleware catches an error and doesn't re-throw, the client receives a success response with undefined data. This is the tRPC equivalent of an empty catch block.
- Severity: **P2**

**tRPC v10+ design note:** Router-level middleware was deliberately removed. All auth enforcement is via procedure composition, not router configuration. This is correct — it's more composable and makes auth visible at the procedure definition.

---

## Principle 5: Resource management — connections, streams, cleanup

*Carmack: understand the lifecycle of every resource you allocate.*
*Collina: every unconsumed body, unclosed stream, and leaked listener is a resource that compounds.*

### What to check

**Unconsumed response bodies**
- HTTP calls to external services (via `fetch` or `undici`) where the response body is not consumed. Collina (Node Congress 2024): **"Something very important to remember is whenever you get a body, please consume the body."** Unconsumed bodies hold connections open, exhausting the connection pool.
- In tRPC middleware that makes HTTP calls: always read the response body even if you only need the status code.
- Severity: **P2** — connection pool exhaustion is a slow leak that manifests under load.

**Missing backpressure handling**
- Writing to streams without checking the return value of `.write()`. When `.write()` returns `false`, you MUST stop and wait for the `drain` event. Ignoring this is the most common backpressure bug.
- The failure mode is a GC death spiral: more memory allocated → longer GC pauses → event loop blocked during GC → more memory accumulates.
- Concrete risk in this stack: CSV file upload processing, database result streaming, any producer-consumer pipeline.
- Fix: use `stream.pipeline()` (handles backpressure, error propagation, cleanup) rather than `.pipe()` (doesn't propagate errors). For async iteration, use `for await...of` with error handling — never pass async functions as `.on('data')` handlers.
- Severity: **P1** for file upload/download paths without backpressure. **P2** for internal pipelines.

**Event listener leaks**
- `emitter.on('data', handler)` without corresponding cleanup. Over time, listeners accumulate, each holding references to closed-over scope. Node.js warns when >10 listeners are on one event.
- Always use `emitter.once()` for one-shot handlers. Clean up with `emitter.off()` in `finally` blocks.
- Severity: **P2**

**AbortController for cancellation**
- Long-running operations without cancellation support. `AbortController` signals allow cleanup when a request is terminated by the client or a timeout fires.
- In serverless: background work after `return` may be killed when the function terminates. `waitUntil()` (where available) extends lifetime for cleanup — but this is platform-specific.
- Severity: **P3** — good practice but not a correctness bug unless resources are leaked.

---

## Principle 6: tRPC architecture — routers, cache, and the server boundary

*Carmack: architecture earns its boundaries through demonstrated need, not speculative design.*
*tRPC: type safety justifies the abstraction — but know what it hides.*

### What to check

**Router organisation**
- Domain-driven sub-routers: one router per entity, merged into `appRouter`. Nested routers (`user.list`, `post.create`) provide natural namespacing and map to TanStack Query keys (`utils.user.invalidate()`).
- `t.mergeRouters` pitfall: if two merged routers have procedures with the same name, **one silently overwrites the other** — no TypeScript error, no runtime error, just lost functionality. Prefer nested routers.
- Severity: **P1** for `mergeRouters` name collisions (silent data loss). **P3** for disorganised routers.

**Cache invalidation bugs (correctness, not performance)**
- Forgetting to invalidate related queries after mutation: creating a post invalidates `post.list` but not `post.count` or dashboard summaries. The user sees stale counts.
- Optimistic updates without `await utils.cancel()` — outgoing refetches overwrite the optimistic update.
- Optimistic updates without `onSettled` invalidation — on error, the UI stays in the optimistic state permanently.
- For apps displaying invoice status, subscription state, or team membership: stale data is a correctness bug, not a performance tradeoff.
- Severity: **P2** when stale data affects business-critical state. **P3** for cosmetic staleness.

**Server Actions vs tRPC — wrong boundary choice**
- tRPC: preferred for data fetching from Client Components and complex API interactions where TanStack Query (caching, polling, invalidation) is needed.
- Server Actions: preferred for form mutations and simple data updates benefiting from progressive enhancement and `revalidatePath`/`revalidateTag`.
- Flag: Server Actions used for data fetching (creates non-cacheable POST requests, invisible in APM tools). Flag: tRPC used for simple form submissions where a Server Action would be simpler.
- Real-world evidence: Documenso migrated back from all-Server-Actions to tRPC due to monitoring difficulty and build corruption.
- Severity: **P3** — wrong choice adds complexity but isn't a correctness bug.

**Next.js middleware misuse**
- Database queries in middleware: Edge runtime can't maintain persistent connections — no Prisma. This won't work at all.
- Consuming `request.json()` in middleware without cloning: the route handler gets nothing.
- Relying solely on middleware for auth: CVE-2025-29927 demonstrated middleware bypass via `x-middleware-subrequest` header. Always validate auth at the data access layer too — which `protectedProcedure` provides.
- Severity: **P1** for auth only in middleware with no data-layer check. **P2** for database calls in Edge middleware (will error). **P3** for body consumption issues.

**Multi-tenant cache safety**
- Cache keys that don't incorporate tenant ID. If User A's cached data is served to User B, this is a data leak, not a performance issue.
- Permission changes: user's role is downgraded but cached data still shows admin-level content.
- Severity: **P1** for cross-tenant cache leaks. **P2** for stale permission data.

---

## Principle 7: Structured logging — observability as correctness

*Carmack: automate what can be checked mechanically.*
*Collina: "If you have very expensive logging, then you will be inclined to log less."*

### What to check

**Logging architecture**
- Use Pino. Log to stdout. Transport in worker threads (Pino v7+). JSON only in production — `pino-pretty` in dev only.
- Collina: **"Just send to standard output, and then somebody else will pick those things up and ship it where it needs to be shipped. Which is the philosophy of cloud-based logging anyway."**
- Child loggers per request with pre-populated metadata (request ID, user ID, org ID). All subsequent logs from that child include the context automatically.
- Severity: **P3** for non-structured logging. **P2** for logging that blocks the event loop (synchronous transports in production).

**The mechanical verification stack**
- TypeScript strict mode + `protectedProcedure`: auth enforced at compile time.
- Zod schemas: input validation is mechanical. `.uuid()` catches what `.string()` passes.
- Output validation: mechanical check that procedures don't leak unexpected fields.
- `errorFormatter` sanitisation: mechanical check that `INTERNAL_SERVER_ERROR` messages never reach the client with raw Prisma details.
- ESLint rules: `no-floating-promises` catches unhandled rejections at lint time. `require-await` flags async functions that don't use `await` (unnecessary promise overhead).
- Severity: **P2** for missing `no-floating-promises` ESLint rule. **P3** for other missing mechanical checks.

---

## Gaps: What This Doc Doesn't Cover

- **Security patterns**: SQL injection, XSS, CSRF, access control, secrets management. Covered by **security.md (Hunt)**.
- **Performance optimisation**: bundle size, re-renders, caching strategy, Suspense streaming, auto-scaling. Covered by **Vercel performance skill**.
- **Prisma/Neon/Postgres depth**: transaction safety, migration patterns, schema design, connection pooling configuration. Covered by **quality-postgres.md (Brandur)**.
- **Frontend patterns**: component architecture, testing, state management. Covered by **quality-frontend.md (Dodds)**.
- **WebSocket subscriptions at scale**: tRPC supports WebSocket and SSE subscriptions, but at early stage this is manageable. If subscription count grows significantly, revisit resource monitoring.
- **Fastify-specific patterns**: plugin system, decorators, lifecycle hooks. We're on Next.js — only Collina's Node.js runtime principles apply.
- **DevOps/infrastructure**: Docker, CI/CD, deployment strategies. Out of scope.

---

## Quick Reference: Severity Guide

| Severity | Pattern | Examples |
|----------|---------|----------|
| **P1 — Fix Now** | Errors that corrupt state, leak data, or crash silently | Swallowed errors on DB operations, Prisma errors leaking schema to client, unprotected procedures, auth only in middleware, async event handlers, missing backpressure on file uploads, `mergeRouters` name collisions, cross-tenant cache leaks, Server Actions without validation |
| **P2 — Fix Soon** | Patterns that hide runtime behaviour or compound | Event loop blocking, promises not yielding, ad hoc auth checks, middleware ordering bugs, unconsumed response bodies, listener leaks, stale business-critical cache, output validation missing on sensitive data, retry storms, Winston/Bunyan in production, missing `no-floating-promises` |
| **P3 — Consider** | Transparency and hygiene | Hidden middleware costs, non-structured logging, disorganised routers, wrong Server Action vs tRPC choice, unnecessary `async` wrappers, missing AbortController |

### The Overriding Filter

Before writing any finding, apply the Collina-Carmack synthesis:

1. **Is this error handled or swallowed?** If swallowed, flag it. (Both: failing silently is worse than crashing.)
2. **Is the runtime behaviour visible?** If the event loop cost, middleware cost, or logging cost is hidden, flag it. (Collina: make the runtime transparent.)
3. **Is validation mechanical?** If a human must remember to validate, flag it. If the type system or Zod enforces it, it's correct. (Both: automate what can be checked.)
4. **Is auth enforced by types?** If a developer can forget to check auth without a type error, the architecture is wrong. (Carmack: make the wrong thing impossible.)
5. **Can this leak across tenants?** Cache keys, connection state, error messages — anything shared must be tenant-scoped. (Both: if it's possible, it will happen.)
