# Security Reference — Carmack × Hunt

Philosophy: John Carmack. Specifics: Troy Hunt + OWASP 2025.
Stack context: Next.js App Router / React / TypeScript / tRPC / Prisma / Neon (serverless Postgres) / Clerk (auth) / CSS Modules + BEM.

Every finding must describe the **concrete attack vector** — not just "this is insecure."
When Carmack and Hunt independently converge on a principle, it earns its place here.

---

## Principle 1: If it's syntactically possible, it statistically exists

*Carmack: "If a vulnerability is syntactically possible, it statistically exists in your codebase."*
*Hunt: "It's us — the organic matter — that despite the best of intentions make bad choices that introduce serious risks."*

The reviewer's job is to hunt for **classes of flaws**, not individual bugs. If the codebase uses string interpolation in one SQL query, assume every query is suspect until proven otherwise.

### What to check

**SQL Injection (OWASP A05)**
- Any raw SQL with string interpolation or concatenation — `${}` template literals in query strings
- Prisma raw queries: `prisma.$queryRaw` or `prisma.$executeRaw` with user input — use `Prisma.sql` tagged template for parameterisation
- Prisma's standard query API is safe by default — the risk is when developers reach for raw queries
- Stored procedures that concatenate internally (Hunt: "ORMs and stored procedures won't save you" if you concatenate inside them)
- Severity: **P1 always.** Hunt's 3-year-old executed SQLi with an automated tool. If exploitation is child's play, there is no excuse.

**Command injection**
- User input passed to `child_process.exec()`, `eval()`, `Function()`, `vm.runInContext()`
- Template strings in shell commands
- Severity: **P1**

**XSS (OWASP A05)**
- `dangerouslySetInnerHTML` without sanitisation
- User content rendered outside React's JSX escaping (direct DOM manipulation, `innerHTML`)
- Server-rendered HTML with unsanitised user input in Next.js API routes or `getServerSideProps`
- Missing or weak Content Security Policy — see Principle 6
- Severity: **P1** for stored XSS, **P2** for reflected

**Path traversal**
- User input in `fs.readFile()`, `fs.writeFile()`, file path construction
- Upload filenames used directly without sanitisation
- Severity: **P1**

---

## Principle 2: Automate defences — human vigilance always fails at scale

*Carmack: "It is irresponsible to not use [static analysis]. Anything that can be mechanically checked should be."*
*Hunt: "Security scanning needs to be continuous, not just a one off, not on an annual basis, not just on major changes but all the time."*

Both agree: if you're relying on developers to remember to do the right thing, you've already lost. Hunt built ASafaWeb because a $6B company (Black & Decker) had publicly exposed error logs. Carmack's entire static analysis essay argues automation is a moral obligation.

### What to check

**Linting and type safety as security**
- Is TypeScript in `strict` mode? Loose types hide exploitable assumptions.
- Are there `any` types on API boundaries, request handlers, or database results? Each one is an unchecked assumption.
- Is ESLint configured with security-relevant rules? (`no-eval`, `no-implied-eval`, `no-new-func`)
- Severity: **P2** for `strict: false`, **P3** for scattered `any` types

**Dependency scanning**
- Is `npm audit` or equivalent running in CI?
- Are dependencies pinned with a lockfile committed?
- Are there outdated packages with known CVEs?
- Severity: **P2** (Hunt's gap area — supplement with OWASP A03 supply chain guidance)

**Continuous validation**
- tRPC procedures: is every mutation and query using `.input()` with a Zod schema? tRPC without input validation is just a fancy RPC with no contract.
- Are Zod schemas strict enough? `.string()` accepts anything — use `.email()`, `.url()`, `.min()`, `.max()`, `.regex()` where the domain demands it.
- Input validation at the tRPC boundary is the automated equivalent of Carmack's assertions. If it's not validated at entry, assume it's exploitable.
- Severity: **P1** for missing validation on mutation procedures, **P2** for query procedures

---

## Principle 3: Minimise state — the less you store, the less you lose

*Carmack: "State is the enemy. Mutable shared state is the root of most bugs."*
*Hunt: "You cannot lose what you do not have."*

Both converge on minimalism. Carmack says state breeds bugs; Hunt says data you collect becomes data that gets breached. CloudPets stored children's voice recordings in unauthenticated S3. South Africa's entire population was exposed via a backup sitting on a public server for 2.5 years.

### What to check

**Data minimisation (OWASP A04, A06)**
- Is the app collecting data it doesn't need? Every unnecessary field is breach surface.
- Are Prisma queries using `select` or `include` to limit returned fields, or returning entire models? (Hunt: Spoutible's API returned bcrypt hashes, 2FA secrets, backup codes, and password reset tokens because the framework automatically serialised entire database entities.) Prisma's default `findMany` returns ALL columns — use `select` to return only what the client needs.
- Is PII stored in logs? Search for `console.log`, logging middleware that dumps request bodies or tRPC inputs.
- Are Neon database backups encrypted and access-controlled? Are preview branches cleaned up?
- Severity: **P1** for PII in logs or over-exposed query results, **P2** for unnecessary data collection

**Clerk-synced user data**
- If syncing Clerk user data to Neon via Prisma: are you storing only what you need in your `User` model? (clerkId, maybe email — not tokens, not auth metadata)
- Is the Clerk webhook payload being stored raw in a Prisma `Json` field? Strip it to essentials.
- Severity: **P2**

**Secrets management**
- Secrets in source code, `.env` files committed to git, environment variable defaults in code
- API keys, database URLs, Clerk secret keys hardcoded anywhere
- Next.js `NEXT_PUBLIC_` prefix on secrets that should be server-only (this is the #1 Next.js secret leak)
- Severity: **P1**

---

## Principle 4: Use the type system as armour

*Carmack: "Use const everywhere. Favour references over pointers. Use the type system to prove absence of flaw classes."*
*Hunt: Demonstrated that 67% of scanned ASP.NET sites had configuration vulnerabilities — defaults kill you.*

In a TypeScript/Next.js stack, the type system is your first line of defence. Carmack's "bondage and discipline languages" argument: restrictions aren't limitations, they're velocity.

### What to check

**Type safety at boundaries**
- tRPC provides end-to-end type safety from Zod input → procedure → client. Are there any places where this chain is broken? (`any` casts, untyped context, manual fetch calls bypassing tRPC)
- Are Prisma-generated types used throughout, or are query results cast to `any` or manual interfaces?
- Are Clerk's `auth()` and `currentUser()` return types properly narrowed before use?
- Severity: **P2** for broken type chains, **P3** for weak typing internally

**Configuration as code**
- Next.js security headers set in `next.config.js`? (See Principle 6)
- Default error pages exposing stack traces in production? (`NODE_ENV` checked)
- Debug/development routes accessible in production?
- Severity: **P1** for exposed stack traces/debug routes, **P2** for missing security headers

---

## Principle 5: Shrink the attack surface

*Carmack: "The single most effective strategy for defect reduction is code reduction."*
*Hunt: "Third-party dependencies increasingly feature [in breaches]... 'a third party' doesn't absolve you of responsibility."*

Every dependency, every endpoint, every feature is attack surface. Hunt traces cascading breaches through third-party failures. Carmack argues the best code is no code.

### What to check

**Unused endpoints and dead code (OWASP A02)**
- API routes that exist but aren't called by any client code
- Development/test endpoints still accessible (`/api/debug`, `/api/seed`, `/api/test-*`)
- Commented-out code that reveals internal logic or previous implementations
- Severity: **P2** for exposed test endpoints, **P3** for dead code

**Dependency surface (OWASP A03)**
- Does every dependency earn its place? Could a 3-line utility replace a package?
- Are there dependencies pulling in massive transitive trees for trivial functionality?
- Client-side: are CDN scripts loaded with Subresource Integrity (SRI) hashes?
- Severity: **P3** unless a dependency has a known CVE (**P1**)

---

## Principle 6: Make code transparent to analysis

*Carmack: "Write code that cooperates with analysis tools. If the tool can't reason about it, neither can a reviewer."*
*Hunt: "ALWAYS MONITOR YOUR CSP REPORTS... 'test in production' with report-only before enforcing."*

Security headers and CSP aren't bolt-ons — they're the automated analysis layer for the browser. Hunt runs CSP on both troyhunt.com and haveibeenpwned.com and calls himself "a big proponent."

### What to check

**Content Security Policy (OWASP A05)**
- Is CSP set? In Next.js, check `next.config.js` headers or middleware.
- Is it `default-src 'self'` with specific additions, or wide open?
- Is `unsafe-inline` or `unsafe-eval` present? Each one defeats the purpose.
- Are nonces or SHA-256 hashes used for inline scripts?
- Is `frame-ancestors 'none'` set? (Supersedes X-Frame-Options)
- Is CSP in report-only mode during rollout? (Hunt: enforce only after monitoring)
- Severity: **P2** for missing CSP, **P1** for `unsafe-inline` on a site handling user data

**Other security headers**
- `Strict-Transport-Security` (HSTS): present with `max-age` ≥ 1 year, `includeSubDomains`, `preload`
- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: strict-origin-when-cross-origin` (minimum)
- `Permissions-Policy`: camera, microphone, geolocation disabled unless needed
- Severity: **P2** for missing HSTS, **P3** for other missing headers

**HTTPS (OWASP A04)**
- Hunt's position is absolute: HTTPS everywhere, no exceptions. He proved HTTPS is faster than HTTP (enables HTTP/2). "All websites should use HTTPS, even if they don't include private content."
- Check: are there any hardcoded `http://` URLs in API calls, redirects, or asset loading?
- Are cookies set with the `Secure` flag?
- Severity: **P1** for cookies without Secure flag, **P2** for mixed content

---

## Principle 7: Deploy assertions as tripwires

*Carmack: "Assertions catch assumption violations before they become exploitable."*
*Hunt: On the Nissan LEAF — "Clearly the answer is to implement appropriate authorisation on all API calls, which when building an app in the first place would be a trivial feature to add."*

Every access control check is an assertion. Every input validation is an assertion. The absence of an assertion is a vulnerability.

### What to check

**Broken Access Control — the #1 OWASP category (A01)**

This is where Clerk *doesn't* save you. Clerk handles authentication (who are you?). Authorisation (what can you do?) is entirely your problem.

- **tRPC middleware**: is auth enforced via a `protectedProcedure` middleware, or are individual procedures checking `ctx.auth` ad hoc? A missing middleware on one procedure is an open door. The correct pattern is an `authedProcedure` base that all protected routes inherit from.
- **tRPC context**: is the Clerk session properly injected into tRPC context? If `ctx.userId` is undefined and unchecked, every downstream query runs unauthenticated.
- **IDOR (Insecure Direct Object Reference)**: can a user access another user's data by changing an ID in the tRPC input? Hunt's VTech example: incrementing a parent ID in `getKids` returned any child's data. "The level of sophistication involved here is being able to count."
- **Row-level security**: when querying Prisma, is the `where` clause filtering by the authenticated user's ID? Or can you omit the filter and get other users' data? (Hunt's TicTocTrack: removing a single URL parameter returned every user.)
- **Server Components vs Client Components**: is authorisation checked in Server Components/tRPC procedures, or only in client-side code that can be bypassed?
- **Clerk middleware scope**: is the Next.js middleware protecting all sensitive routes, or only some? Check for routes that slipped through.
- **Webhook validation**: is the Clerk webhook signature verified with `svix`? An unvalidated webhook endpoint is a direct write path into your database.
- Severity: **P1 always.** Broken access control is #1 on OWASP 2025 for a reason.

**Rate limiting**
- Are mutation endpoints rate-limited? (Especially: login attempts if you have any custom auth flows, password resets, API keys)
- Is there rate limiting on expensive queries?
- Hunt's HIBP API enforces one request per 1,500ms per IP.
- Severity: **P2**

---

## Principle 8: Treat code review as security education

*Carmack: Reviews are how the team builds shared understanding of what "correct" means.*
*Hunt: "Education is the best ROI on security spend. Ever." Writing secure code costs zero extra effort at development time. Finding the same bug in QA costs an order of magnitude more. Finding it in production costs catastrophically more (TalkTalk: £42M).*

This principle is meta — it's about how the reviewer writes findings. Every security finding should teach, not just flag. Explain the attack vector. Show what an attacker would do. Make it visceral.

### Reviewer guidance

- Don't write "this endpoint is insecure." Write "this endpoint returns all users when you remove the `userId` parameter — an attacker would enumerate your entire user table."
- Reference real breaches when the pattern matches. Hunt's case studies make risks concrete.
- The finding should make the developer never want to write that pattern again.

---

## Principle 9: Assume breach — design for the failure case

*Carmack: "If a mistake is possible, it will eventually happen."*
*Hunt: "Absence of evidence is not evidence of absence."*

Don't just prevent breaches — design so that when something fails, the blast radius is contained.

### What to check

**Error handling and information leakage (OWASP A02, A10)**
- Do error responses expose stack traces, SQL errors, file paths, or internal service names?
- Are Postgres errors propagated to the client? (Column names, table names, constraint names — all leak schema information.)
- Is there a global error boundary that returns generic errors to clients?
- Are unhandled promise rejections caught? (Node.js default: crash the process. Next.js: 500 with potential info leak.)
- Severity: **P1** for SQL/stack traces in production responses, **P2** for verbose error messages

**Session and token management**
- Clerk handles sessions, but: are there any custom tokens, API keys, or session identifiers in your code?
- If yes: are they cryptographically random, time-limited, and single-use where appropriate?
- Are expired/revoked tokens actually rejected, or just unchecked?
- Severity: **P1** for custom auth tokens without expiry, **P2** for other issues

**Credential stuffing awareness (OWASP A07)**
- Hunt traces the 2017 Uber breach, 2022 Uber breach, and 2023 23andMe breach all to credential stuffing from prior breaches.
- Even with Clerk: if your app stores any credentials, keys, or secrets that users provide (API keys for integrations, etc.), are these encrypted at rest?
- Severity: **P2**

---

## Principle 10: Know your gaps

*Carmack: epistemic humility — you can't fix what you don't know is broken.*
*Hunt: "We take security seriously" — otherwise known as "we didn't take it seriously enough."*

### Areas this doc is weaker on (supplement from other sources)

- **Modern supply chain attacks**: dependency confusion, npm/PyPI typosquatting, build pipeline compromise (OWASP A03). Hunt's supply chain coverage is client-side focused (SRI + CSP). For npm-specific risks, supplement with Socket.dev analysis and SLSA framework.
- **CI/CD pipeline integrity**: code signing, deployment key management, GitHub Actions security (OWASP A08). Not Hunt's domain.
- **Detection engineering**: logging architecture, SIEM, anomaly detection (OWASP A09). Hunt covers post-breach disclosure, not pre-breach detection.
- **Exception handling as security**: fail-safe vs fail-open design, resilience patterns (OWASP A10). Newest OWASP category, weakest coverage.

---

## Quick Reference: Severity Guide

| Severity | Pattern | Examples |
|----------|---------|----------|
| **P1 — Fix Now** | Exploitable vulnerability, data exposure, access control bypass | SQLi, missing auth on API routes, IDOR, PII in logs, secrets in code, exposed stack traces |
| **P2 — Fix Soon** | Defence gap that increases attack surface or blast radius | Missing CSP, no rate limiting, weak typing at boundaries, over-fetched API data, missing HSTS |
| **P3 — Consider** | Hygiene issue that compounds over time | Dead endpoints, unnecessary dependencies, scattered `any` types, missing SRI on CDN scripts |
