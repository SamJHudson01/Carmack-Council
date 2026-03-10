# Conventions

Accepted patterns from council reviews. Plans and implementations must respect these — never recommend against an accepted convention without explicit justification.

Last updated: 2026-02-25

---

## Prisma Schema (Brandur)

- **Primary keys**: `@id @default(cuid())` on all models. ORM-level generation. Do not omit the default. Prisma v7's `cuid()` generates CUID2 strings — always validate with `z.string().cuid2()`, never `z.string().cuid()` (CUID1 format requires a `c` prefix that CUID2 doesn't guarantee).
- **Timestamps**: `@db.Timestamptz(6)` on both `createdAt` and `updatedAt`. Never use Prisma's default `TIMESTAMP(3)`.
- **Column mapping**: `@map("snake_case")` on every multi-word column. `@@map("snake_case_plural")` on every model.
- **updatedAt**: `@updatedAt` on the `updatedAt` field for automatic update.
- **Explicit referential actions**: Every `@relation` MUST specify explicit `onDelete` behavior. Use `Cascade` when child is owned by parent. Use `SetNull` when child should survive parent deletion.
- **Nullable discipline**: Prefer NOT NULL with sensible defaults over nullable fields. JSON fields are `Json` (not `Json?`) with `DEFAULT '{}'::jsonb` at the DDL level.
- **CHECK constraints**: Use for data integrity (e.g., JSON payload size limits, enum-like string columns, numeric ranges). Added via two-phase migration pattern. For business-critical rules, create BOTH a Zod schema AND a CHECK constraint — cross-reference the two in comments.
- **Indexes**: Explicit `@@index` on foreign keys that Prisma doesn't auto-index. `@unique` constraints provide their own index — don't duplicate.
- **groupBy constraints**: Prisma 7 requires every field in `orderBy` to also appear in `by`. Using `take` with `groupBy` triggers implicit deterministic ordering that can fail. Prefer omitting `orderBy` and `take` from `groupBy` unless the grouped field set is sufficient for ordering. If `take` is needed, only order by fields already in `by`.
- **Named constraints and indexes**: All indexes use `map: "{table}_{columns}_{idx|uniq}"`. CHECK constraints use `{table_prefix}_{description}` format.
- **VarChar limits match Zod schemas**: Text columns with known business length limits MUST use `@db.VarChar(N)`. The VarChar limit should match the corresponding Zod schema's `.max()` value.
- **JSONB versioned storage**: All JSONB data MUST be validated through Zod `safeParse` at the read boundary. Use versioned discriminated unions on `schemaVersion`. When evolving JSONB shapes, add a new version — NEVER modify a FROZEN schema. JSONB columns MUST have `CHECK (octet_length < N)` constraints.
- **Serializable isolation for check-then-act**: All check-then-act patterns MUST use `Prisma.TransactionIsolationLevel.Serializable` AND be wrapped with `withSerializableRetry`. Use READ COMMITTED only for single-row operations. Document the isolation level choice on every `$transaction`.
- **Connection string validation**: `DATABASE_URL` must include all five required connection parameters documented in `lib/db.ts`. Runtime validation enforces this in production. Prisma CLI uses `DIRECT_URL` (non-pooled), application code uses `DATABASE_URL` (pooled via PrismaNeon adapter).

## Migrations (Brandur)

- **Two-file pattern for constraints**: File 1 creates/alters the table. File 2 adds CHECK constraints as `NOT VALID` then `VALIDATE CONSTRAINT` separately. Even on empty tables, follow this pattern to build muscle memory.
- **Always use `--create-only`**: Review generated SQL before applying. Edit the migration to add DDL-level defaults, CHECK constraints, and correct any Prisma defaults.
- **Verify generated SQL**: Confirm `CREATE UNIQUE INDEX` appears where expected, FK references use `ON DELETE CASCADE`, and no unexpected `CREATE INDEX` duplicates unique constraint indexes.
- **Index creation with CONCURRENTLY**: Index creation on tables with existing data MUST use `CREATE INDEX CONCURRENTLY` in a dedicated single-statement migration file.

## Migration Hygiene (Brandur)

- **Never delete a migration directory after it has been applied.** Prisma tracks applied migrations by directory name and file checksum in `_prisma_migrations`. Deleting a local migration that exists in the remote DB creates "ghost" rows — drift that blocks all future migrations. If a migration needs to be undone, write a new migration that reverses its effects.
- **Never edit a migration file after it has been applied.** Prisma checksums every migration SQL file. Editing a file after it has been applied causes a checksum mismatch, which Prisma treats as drift and refuses to proceed. If the SQL needs correcting, write a new migration with the fix.
- **Always use `--create-only` and review before applying.** Never let `prisma migrate dev` auto-apply. Generate with `--create-only`, review the SQL, hand-edit if needed (CHECK constraints, `RENAME COLUMN` instead of DROP+ADD, `CONCURRENTLY`, etc.), then apply. This is the only reliable way to catch destructive Prisma defaults.
- **Partial unique indexes require hand-written SQL.** Prisma cannot express `WHERE` clauses on unique indexes. These must be added in the CHECK constraints migration file (File 2 of the two-file pattern). Handle violations as `PrismaClientUnknownRequestError` (not `PrismaClientKnownRequestError`) in application code.
- **Column renames must use `ALTER TABLE RENAME COLUMN`.** Prisma's default migration for a renamed field is DROP + ADD, which destroys data. Always edit the generated SQL to use `RENAME COLUMN` instead.

## tRPC (Collina)

- **Router organisation**: One router per entity in `lib/trpc/procedures/`. Composed as peer sub-routers in `lib/trpc/router.ts`. Never nest features inside unrelated routers.
- **Procedure tiers**: `authedProcedure` for cheap CRUD reads/writes (no rate limit). `protectedProcedure` for expensive AI/scraping calls (rate-limited). Never use `protectedProcedure` for database-only operations.
- **Middleware chain**: `withLogger` -> `validateCsrf` -> `isAuthed` -> `isRateLimited` (protected only) -> `translatePrismaErrors`. Logger runs first so all subsequent middleware has `ctx.log`.
- **ctx.dbUserId**: All database queries use `ctx.dbUserId` from the auth middleware. Never accept a userId parameter from client input for ownership queries.
- **Error translation**: Prisma errors are caught by `translatePrismaErrors` middleware and converted to tRPC error codes. P2002 -> CONFLICT, P2025 -> NOT_FOUND, CHECK violations -> BAD_REQUEST. Raw Prisma error codes never leak to the client. `cause` is preserved in dev, stripped in production.
- **Explicit select fields**: All Prisma queries MUST use explicit `select` to specify only the fields needed. Extract shared select constants (like `BOARD_CARD_SELECT`) for queries that return the same shape across multiple procedures. List/dashboard queries MUST exclude large JSONB columns.
- **Discriminated union result types**: API functions that can fail MUST return a discriminated union with `{ success: true; data: T }` / `{ success: false; error: string; retryable: boolean }`. Never throw from pipeline-level functions; reserve throws for programmer errors.
- **deleteMany for ownership-safe deletes**: Delete operations on user-owned records MUST use `deleteMany` with compound WHERE (`{ id, userId }`) and check the returned `count`. If count is 0, throw `NOT_FOUND`. Never use bare `delete` for user-owned records.

## Error Handling (Hunt x Collina x Dodds)

- **Error formatter strips internal details**: The tRPC error formatter MUST replace `INTERNAL_SERVER_ERROR` messages with a generic string. Never pass raw error messages from Prisma, external APIs, or internal logic to the client. Stack traces are stripped in production.
- **Operational vs programmer error classification**: All catch blocks MUST classify errors as operational or programmer. Operational errors (network failures, timeouts, connection issues): log and handle gracefully. Programmer errors (TypeError, schema mismatches): re-throw (or log with `[BUG]` prefix in fire-and-forget paths). The default for unknown errors is "potentially serious."
- **User-facing error transformation**: Never display `error.message` from tRPC directly in the UI. Always transform via `getUserFacingError()` which returns `{ message: string, isRetryable: boolean }`. Show retry buttons only when `isRetryable` is true. Error messages pass through three sanitisation layers: server error formatter, server `toUserFacingError()`, client `getUserFacingError()`.
- **Sensitive data exclusion from logs**: Never log the full body of external API error responses — they may echo user-submitted content. Log only the HTTP status code and a descriptive category. For database errors, log only the error code in production.
- **Best-effort saves after expensive operations**: When a database write follows an expensive operation (AI pipeline), wrap the save in a best-effort try-catch that does not propagate to the client. Dedup and operational errors should be logged and swallowed. Include a `saved: boolean` flag in the response.

## API Clients (Collina)

- **Signal composition**: `AbortSignal.any([callerSignal, AbortSignal.timeout(perCallTimeout)])` — compose, don't discard. Every async function accepts an optional `AbortSignal`.
- **Retry pattern**: `retryWithBackoff<T>()` with exponential backoff. Signal-based cancellation — no deadline arithmetic. Permanent vs transient error classification prevents retry storms.
- **Retry storm prevention**: Chain orchestrator uses `maxRetries: 1` for inner calls. Retry once on retryable failure at the chain level.
- **Body consumption**: Always consume response bodies on error (`await response.text()`) to release TCP connections back to the pool, even when the body is not logged.
- **External response shape validation**: Always validate the shape of external API responses before accessing nested properties, even after a 200 OK. Treat structurally malformed 200 responses as permanent failures — do not retry them.
- **Config constants**: All timeouts, retries, model names, and limits in `lib/api/config.ts`. Never inline magic numbers. API keys must be accessed through dedicated getter functions that throw on missing values.
- **Provider function contract**: New AI provider clients MUST implement the `ProviderFn` type signature. The chain orchestrator's `STEP_PROVIDER` map controls which provider handles each step.
- **No content logging**: Log status codes, timing, and error categories. Never log request/response bodies — they contain user-submitted data.

## File Uploads (Hunt x Collina)

- **Busboy streaming**: File uploads use standalone Next.js route handlers (not tRPC) with Busboy for streaming multipart. tRPC doesn't handle multipart streaming.
- **Auth preamble**: Every upload route manually validates: Clerk auth, CSRF (double-submit cookie via `lib/csrf.ts`), and rate limit. Copy the exact pattern from existing upload routes.
- **Per-user directories**: Upload files stored in user-specific subdirectories (`getUploadDir(userId)`) for filesystem-level isolation.
- **File ownership**: `registerFileOwner(fileId, userId)` on upload, `verifyFileOwner(fileId, userId)` in the processing procedure. One-time use — `clearFileOwner` after verification.
- **Filename sanitisation**: Strip directory traversal, null bytes, unsafe characters. Use `basename()` + character allowlist.
- **Cleanup**: Delete files immediately after processing in `finally` blocks. The periodic cleanup sweep is a safety net, not the primary mechanism.

## Frontend — Data Fetching (Vercel x Dodds)

- **SSR prefetch + HydrationBoundary**: Every dashboard page uses a Server Component `page.tsx` that calls `createCaller` to prefetch data server-side, populates a `QueryClient`, and wraps the Client Component in `HydrationBoundary`. This eliminates client-side loading waterfalls.
- **Suspense + loading.tsx**: Wrap async Server Components in `<Suspense fallback={<Skeleton />}>`. Create a `loading.tsx` file in every route segment for navigation-level loading state.
- **TanStack Query configuration**: Global `staleTime` is 30 seconds (`query-client-config.ts`). Per-query overrides only where needed (e.g. HypothesisChat messages at 10s). `retry: false` globally (AI calls are expensive). `refetchOnWindowFocus: true` globally.
- **TRPCProvider scoped to dashboard**: Place providers at the lowest common ancestor. `ClerkProvider` at root, `TRPCProvider` at dashboard layout. Public pages ship no tRPC JavaScript.
- **error.tsx**: Route-segment error boundaries with reset functionality at every dashboard route.

## Frontend — Components (Dodds)

- **CSS Modules + BEM**: All styling via `.module.css` files with BEM naming. Never Tailwind. Never inline styles except dynamic values.
- **Server Components by default**: Client Components only where interactivity is needed (forms, modals, drag-and-drop, state).
- **next/dynamic for secondary zones**: Lazy-load interactive areas that aren't visible on initial page load (modals, upload areas) via `next/dynamic` with `ssr: false`. Preload on hover where appropriate. **`ssr: false` is only valid inside Client Components** — Server Components cannot use `next/dynamic` with `ssr: false`. To render a Client Component from a Server Component, import it directly (Next.js code-splits at the `'use client'` boundary automatically).
- **useReducer for complex state**: When state elements are interdependent (lists with add/edit/delete/reorder + server-driven updates), use `useReducer` with a discriminated action union. Not multiple `useState` calls.
- **Discriminated union status**: Model multi-phase async flows as a single discriminated union type (`{ phase: 'idle' } | { phase: 'loading' } | { phase: 'error'; message: string }`). Not boolean flags.
- **tRPC cache as source of truth**: The tRPC/React Query cache owns persisted state. `useReducer` owns only in-flight optimistic state between mutation fire and server confirmation. Invalidate queries on success, rollback reducer on error.
- **Native HTML drag-and-drop**: Custom hooks built on native `DragEvent` and `dataTransfer` (see `use-dnd.ts`). Do not add `@dnd-kit` or other DnD libraries.
- **Modal/dialog accessibility**: Every modal must use: overlay with `role="presentation"` + click-outside close, panel with `role="dialog"` + `aria-modal="true"` + `aria-label` + `tabIndex={-1}`, `useFocusTrap(panelRef, onClose)`, and `useScrollLock(true)`.
- **data-cy attributes for E2E**: Add `data-cy` attributes to all elements targeted by Cypress E2E tests. Use descriptive kebab-case names. Component tests use Testing Library queries (`getByRole`, `getByLabelText`).

## Frontend — Testing (Dodds)

- **Integration tests over unit tests**: Test through the rendered DOM using `getByRole` and `getByText`, not by asserting on hook return values or reducer state. "Write tests. Not too many. Mostly integration."
- **Mock tRPC at module boundary**: `vi.mock('@/lib/trpc/client')` — test the full component with mocked API responses, not individual hooks.
- **Colocate test files**: Test files in `__tests__/` mirroring the source directory structure.

## E2E — Cypress (Bahmutov)

- **Auth setup hierarchy**: `loginAndReset('admin')` → `ensureTeamContext()` → `db:seed*` tasks. `loginAndReset` handles sign-in (cached via `cy.session`), team creation, Clerk metadata, and scoped data reset. `ensureTeamContext` returns `{ teamId, userId, clerkUserId }` for passing to seed tasks.
- **Seed via `cy.task`, not UI**: All test data created through `db:seed*` Prisma tasks in `cypress.config.ts`. Only the feature under test goes through the UI. Login is the one exception — it uses `cy.session` cached Clerk sign-in.
- **tRPC batched response format**: All `cy.intercept` stubs MUST use the tRPC batch wrapper: `{ body: [{ result: { data: ... } }] }`. Errors use `{ body: [{ error: { message, code, data: { code, httpStatus } } }] }`. Forgetting the outer array causes silent test failures.
- **Server-rendered pages don't fire client-side tRPC GETs**: Pages prefetched via `createCaller` in Server Components produce no client-side GET. Never `cy.wait('@getList')` on initial page load — use `data-cy` content assertions as page-ready gates. Client-side mutations and interaction-triggered queries can still be intercepted.
- **Dynamic intercepts for mutations that invalidate**: When a mutation's `onSettled` calls `utils.*.invalidate()`, the refetch hits the GET intercept. A static intercept returning stale/empty data will wipe the optimistic cache update. Use a counter-based dynamic intercept: return empty on first call (initial load), return updated data on subsequent calls (post-invalidation refetch).
- **Intercepts before visit**: Register `cy.intercept()` BEFORE `cy.visit()`. The app makes network calls on startup — late intercepts cause race conditions.
- **One spec per feature**: Specs live in `cypress/e2e/{domain}/{feature}.cy.ts`. Each spec under 2 minutes. `@smoke` tag on critical-path tests for CI fast path. `beforeEach` sets up state; no `afterEach` cleanup.

## Frontend — File Organisation (Dodds)

- **Colocate by feature**: Page, Client Component, reducer, CSS Module, and error boundary all live in the same route directory (e.g., `app/dashboard/context/`). Don't scatter across `lib/`, `styles/`, and `app/`.
- **Shared schemas separate from feature schemas**: Feature-specific Zod schemas go in their own module (e.g., `lib/schemas/company-context.ts`). The main `lib/schemas.ts` is for cross-cutting analysis pipeline schemas only.

## Security (Hunt)

- **CSRF double-submit cookie**: All mutations (tRPC and upload routes) validate CSRF via the cookie + header pattern in `lib/csrf.ts`. Non-HttpOnly cookie (client must read it), Secure in production, SameSite=Strict.
- **SSRF protection**: All user-supplied URLs pass through `lib/url-validation.ts` before any server-side fetch. Comprehensive DNS resolution + private IP blocking.
- **Rate limiting by authenticated user**: Rate limiting must be keyed by authenticated user ID, not IP address. All expensive operations (AI calls, file uploads) share the same rate limit namespace. Use `checkRateLimit()` from `lib/rate-limit.ts`.
- **Security headers**: All five security headers (HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy, Permissions-Policy) must remain in `next.config.ts`. CSP is managed in `middleware.ts`. Never remove `frame-ancestors 'none'` or weaken HSTS.
- **Dual CSP**: Enforcing header with per-request nonce + `'strict-dynamic'` (primary XSS defence) + `'unsafe-inline'` (backwards-compat fallback ignored by modern browsers). Report-only header uses the same nonce without `'unsafe-inline'` for stricter monitoring. Both headers and the `x-nonce` request header share a single `generateCspNonce()` value per request. `style-src 'unsafe-inline'` is permanent (required by Clerk CSS-in-JS).
- **No secrets in client bundles**: No `NEXT_PUBLIC_` prefix on sensitive env vars. Secrets in `.env.local` only.
- **Row-level ownership**: Every database query filters by `ctx.dbUserId`. Never trust client-supplied IDs for authorization — use them only for record lookup within the user's own data.

## Deployment (Carmack)

- **Railway persistent containers**: Long-lived process. In-memory state (rate limiters, caches, timers) survives across requests.
- **Fire-and-forget is safe**: `void fn().catch()` for background work. No `waitUntil()` needed. The process stays alive.
- **Single instance**: In-memory rate limiting is acceptable. No Redis needed at ~4k users.
- **IP headers trusted**: `x-forwarded-for` set by Railway's proxy, not user-controllable.

## Pipeline Architecture (Fowler x Collina)

- **Pipeline functions are pure orchestrators**: They accept typed input + AbortSignal and return typed output. They know nothing about Prisma, tRPC, or HTTP. The tRPC procedure handles persistence and error translation.
- **Synchronous where wall-clock math allows**: If the pipeline fits within a 90-second budget, keep it synchronous (single request/response). Only use fire-and-forget (status column + polling + reaper) for operations that genuinely exceed 2+ minutes.
- **Promise.allSettled for parallel steps**: When multiple independent operations run in parallel, use `Promise.allSettled` to collect results. Partition into successes and failures. Never let one failure abort the others.
- **Separate dispatchers by I/O profile**: Different input types (file upload, URL scrape, text pass-through) have different timeout characteristics. Separate functions with calibrated timeouts, not one generic handler.
- **Context injection via ChainInput**: Company/user context is added as an optional field on the existing `ChainInput` type. Content-builders append it. Prompt templates don't change.

### Pipeline & Orchestrator Tiers (Leach × Fowler)

Not all orchestration logic has the same shape. Do not force Tier 2 or Tier 3 shapes into Tier 1. The transaction boundary is the correctness specification, not plumbing to be abstracted away.

- **Tier 1 — Pure orchestrators**: No DB access, no Prisma imports. Accept typed input + `AbortSignal`, return a discriminated union (`{ success: true; data: T } | { success: false; error: string; retryable: boolean }`). The tRPC procedure handles persistence and error translation. Examples: `runAnalysisPipeline`, `runComparisonSynthesis`, `runComparisonPipeline`, `executeRefinement`. Testable with zero module-level mocks — mock only the injected dependencies.
- **Tier 2 — Transactional units**: Accept a `tx` parameter (Prisma interactive transaction client). Own the body of a Serializable transaction. MUST NOT import `db` from `@/lib/db` — the root client inside a transaction body deadlocks under Neon's `connection_limit=1`. The procedure wraps the Tier 2 function in `withSerializableRetry(() => db.$transaction(tx => fn(tx, ...), { isolationLevel: Serializable }))`. Examples: `persistRefinement`, `persistUndo`, `claimFollowUpSlot`. Testable by passing a mock `tx` — zero module-level mocks.
- **Tier 3 — Self-contained pipelines**: Own their entire DB lifecycle including terminal-state guarantees (every row reaches `complete` or `failed`). Import `db` directly. The fire-and-forget caller relies on the pipeline guaranteeing terminal state. Example: `runVideoPipeline`. Testing requires full module-level mocks — the real fix is integration tests.

## Backend Patterns (Collina)

- **Pino structured logging**: All server-side logging uses Pino via `lib/logger.ts`. Use `createLogger('module-name')` for module-level children. Use `ctx.log` inside tRPC procedures (bound with `requestId`, `userId`, `procedure`). Thread loggers through function chains via optional `logger?: Logger` parameters. Use `fatal` level for programmer errors (enables Axiom alerting on `level == 60`). Use numeric `{ durationMs }` fields instead of formatted timing strings. Never log user content (AI responses, observation text, prompt text) — log `{ responseLength, label }` instead. Redaction paths in the root logger prevent sensitive fields from reaching Axiom.
- **Fire-and-forget pattern**: Fire-and-forget async operations MUST use `void promise.catch(handler)` with an error classifier. The promise MUST guarantee terminal state (no stuck rows). Background timers must be idempotent, use `.unref()`, and start from `startBackgroundTasks()`.
- **Types derived from schemas**: All domain types with corresponding Zod schemas MUST be derived using `z.infer<typeof schema>`. Define schemas in `lib/schemas.ts`, derive types in `lib/types.ts`. Never manually duplicate a schema as a TypeScript interface.
- **Zod schema strictness tiers**: STRICT schemas (write boundary, no `.catch()`) for validating AI outputs at the pipeline boundary. LENIENT schemas (read boundary, `.catch()` on every optional/evolving field) for reading JSONB from the database.
