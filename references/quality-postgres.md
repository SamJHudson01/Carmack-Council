# Postgres Quality Reference — Carmack × Brandur × Prisma × Neon

Philosophy: John Carmack. Postgres expertise: Brandur Leach (Crunchy Data, ex-Stripe). ORM layer: Prisma documentation + community. Serverless Postgres: Neon documentation.
Stack context: Next.js App Router / React / TypeScript / tRPC / Prisma / Neon (serverless Postgres) / Clerk / CSS Modules + BEM.

Every finding must describe the **concrete failure mode** — not just "this is bad practice."
Security patterns are in security.md (Hunt). Backend error handling is in quality-backend.md (Collina). Performance tuning is in the Vercel skill. This doc covers: data integrity, transaction safety, migration correctness, schema design, query correctness, and connection management on Neon.

---

## Principle 1: Constraints are assertions — the database is the last line of defence

*Carmack: assertions catch assumption violations before they cause corruption.*
*Brandur: "Your database can and should act as a foundational substrate that offers your application profound leverage for fast and correct operation."*

Database constraints are the only safety layer that cannot be bypassed by any code path — not by raw SQL, not by other applications, not by future developers who don't read the docs, not by Prisma bugs. TypeScript catches type errors at compile time. Prisma validates at the client. But only the database enforces invariants at the point of data entry.

Brandur: **"You can get away without constraints and schemas, but only by internalizing a nihilistic understanding that your production data isn't cohesive."**

### What to check

**Missing CHECK constraints**
- Prices that should be positive, quantities that should be non-negative, string lengths that have business limits. Without CHECK constraints, the database accepts any value the type allows.
- Prisma does NOT support CHECK constraints natively (GitHub #3388, 286+ upvotes). Must add via `prisma migrate dev --create-only`, then edit the migration SQL: `ALTER TABLE "product" ADD CONSTRAINT "price_positive" CHECK (price > 0)`.
- Prisma doesn't handle CHECK violation errors with typed error codes — you get `PrismaClientUnknownRequestError`. Catch and translate in tRPC middleware alongside other Prisma errors (see quality-backend.md).
- Severity: **P2** for business-critical fields (prices, quantities, statuses). **P3** for advisory constraints.

**Missing compound unique constraints**
- If `(tenantId, email)` isn't `@@unique`, duplicate registrations are possible. No code path intends to create them, but under concurrent requests, they happen. This is the isolation level race that Brandur demonstrates — two transactions both check, both get empty, both insert.
- Named compound uniques enable `findUnique` with compound keys: `@@unique(fields: [userId, workspaceId], name: "membership_key")`.
- Severity: **P1** for business identity fields (tenant + email, user + workspace, org + slug). **P2** for non-critical uniqueness.

**Missing foreign key indexes**
- Postgres does NOT automatically index foreign key columns. Prisma's `@relation` creates the FK constraint but NOT the index. Without the index, `DELETE` on a parent row triggers a sequential scan of the entire child table to verify no references exist. Real-world case: deleting 50k records took ~100ms with an index, ~30 minutes without — 10,000× slower.
- Fix: add `@@index([foreignKeyField])` to every model that has a `@relation`.
- Severity: **P2** — works fine at small scale, catastrophic at production scale.

**NOT NULL discipline**
- Brandur: **"Nullable columns are literally the default in DDL — you'll get one unless you're really thinking about what you're doing and explicitly use NOT NULL."**
- Prisma gets this right: fields without `?` are NOT NULL. But review for fields marked `?` without a business reason. Every nullable column is unstructured state — NULL obeys three-valued logic that violates human intuition.
- Severity: **P3** for unnecessary nullable fields. **P2** if nullable fields are used in WHERE clauses or JOINs without NULL handling.

**Constraints as defence-in-depth for isolation level races**
- Even with SERIALIZABLE isolation, add UNIQUE constraints. Brandur: **"Although SERIALIZABLE will protect you from a duplicate insert, an added UNIQUE will act as one more check to protect your application against incorrectly invoked transactions or buggy code."**
- Two independent safety layers are always better than one.
- Severity: **P2** for relying solely on application logic for uniqueness.

---

## Principle 2: Transactions are the unit of correctness — understand what isolation buys you

*Carmack: if a race condition is syntactically possible, it will happen in production.*
*Brandur: "Transactions are really just a really good idea. Maybe the best idea in robust service design."*

### What to check

**Check-then-act patterns under READ COMMITTED**
- Prisma's interactive transactions default to READ COMMITTED. Under this isolation, two interleaved transactions can both SELECT to check a condition, both see the same state, both proceed — violating the invariant that neither violated individually. This is write skew.
- Concrete example: two transactions both check if a user email exists, both get empty results, both INSERT — creating a duplicate even though each transaction correctly checked first.
- For check-then-act operations, escalate to SERIALIZABLE:
  ```typescript
  await prisma.$transaction(async (tx) => { /* ... */ }, {
    isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
  });
  ```
- SERIALIZABLE raises `ERROR: could not serialize access` on conflict. The application MUST catch and retry. Without retry logic, SERIALIZABLE transactions just fail.
- Severity: **P1** for financial operations, access control decisions, or any check-then-act on shared state. **P2** for other check-then-act patterns.

**Interactive transactions holding connections**
- `$transaction(async (tx) => {})` holds a database connection for the entire callback duration. With `connection_limit=1` on Neon, all other queries are blocked.
- **The deadlock bug:** using `prisma` (the root client) instead of `tx` inside the callback. The root client tries to acquire a connection from the pool. The pool has 1 connection, held by the transaction. Result: deadlock until the 5s timeout, then `P2028: Transaction already closed`.
- Rules: never do network requests or slow processing inside `$transaction()`. Always use `tx`, never `prisma`, inside the callback. Prefer batch transactions (`$transaction([q1, q2])`) when no conditional logic is needed — they don't hold a connection.
- Severity: **P1** for using `prisma` instead of `tx` inside a transaction (guaranteed deadlock with `connection_limit=1`). **P2** for slow operations inside transactions.

**Side effects inside transactions — the outbox problem**
- Enqueueing a job INSIDE a transaction: the job may execute before the transaction commits, failing on data that doesn't exist yet.
- Enqueueing AFTER a transaction: the process may crash between commit and enqueue — data persists but the job is lost. Brandur: **"It's a problem that's far more nefarious; you almost certainly won't notice when it happens."**
- Fix: the transactionally staged job drain (outbox pattern). Insert a job record into a `staged_jobs` table within the same transaction as the data change. A separate enqueuer polls and forwards. Transactional isolation means the enqueuer can't see uncommitted jobs. Rollbacks discard the job with the data.
- Severity: **P2** for side effects (emails, webhooks, queue jobs) triggered inside or immediately after transactions. **P1** if the side effect involves money or external API mutations.

**Transaction duration on Neon**
- Long transactions prevent VACUUM from cleaning dead tuples. Dead rows accumulate, table bloat grows, all queries slow down. Brandur describes a production incident where an analytical query caused a job queue spike to 10,000+ jobs because dead rows couldn't be cleaned.
- On Neon's PgBouncer (transaction mode), connections are returned after each transaction. Long transactions hold scarce connections.
- Set `idle_in_transaction_session_timeout` to 10s and `statement_timeout` to 10s to kill zombie transactions.
- Severity: **P2** for transactions that could exceed a few seconds. **P1** for unbounded transaction duration (e.g., processing a file inside a transaction).

**Idempotency for foreign state mutations**
- When a tRPC procedure calls an external API (payment processor, email provider, webhook) inside a flow that also writes to the database, the external call is outside the ACID boundary. Brandur: **"Once we make our first foreign state mutation, we're committed one way or another. We've pushed data into a system beyond our own boundaries and we shouldn't lose track of it."**
- Even internal services count: **"It's tempting to treat emitting records to Kafka as part of atomic operations because they have such a high success rate that they feel like they are. They're not."**
- The idempotency key pattern: client sends a unique key, server records key + response, retries return the stored response. For the full atomic-phase pattern, you need `$queryRaw` with SERIALIZABLE isolation.
- Severity: **P2** for external API calls without idempotency protection. **P1** for payment or financial mutations without idempotency.

---

## Principle 3: Migrations are production operations — every DDL has a lock cost

*Carmack: if it CAN lock a table, it WILL lock in production.*
*strong_migrations: classify operations as dangerous if they block reads/writes for more than a few seconds.*

Every schema change acquires a lock. The question is: which lock, and for how long?

### The lock reference

| Operation | Lock | Blocks reads? | Blocks writes? |
|---|---|---|---|
| `CREATE INDEX` (standard) | SHARE | No | **Yes** |
| `CREATE INDEX CONCURRENTLY` | SHARE UPDATE EXCLUSIVE | No | No |
| `ALTER TABLE ... SET NOT NULL` | ACCESS EXCLUSIVE | **Yes** | **Yes** |
| `ADD COLUMN ... DEFAULT` (Pg 11+, non-volatile) | ACCESS EXCLUSIVE (brief, metadata only) | Brief | Brief |
| `ALTER COLUMN TYPE` (rewrite) | ACCESS EXCLUSIVE | **Yes** | **Yes** |
| `DROP TABLE` / `TRUNCATE` | ACCESS EXCLUSIVE | **Yes** | **Yes** |
| `ADD FOREIGN KEY` (validating) | SHARE ROW EXCLUSIVE | No | **Yes (both tables)** |

### What to check

**Indexes created without CONCURRENTLY**
- Prisma does NOT use `CREATE INDEX CONCURRENTLY` by default (GitHub #14456). Adding `@@index` generates plain `CREATE INDEX` which blocks all writes for the duration of the index build. On a large table, this is minutes to hours of write downtime.
- Fix: `npx prisma migrate dev --create-only`, edit the migration SQL to add `CONCURRENTLY`, ensure it's the ONLY statement in the migration file (Prisma wraps multi-statement migrations in a transaction, which is incompatible with `CONCURRENTLY`).
- Severity: **P1** on any table with significant data. **P3** on small reference tables.

**SET NOT NULL on existing columns**
- Prisma generates `ALTER COLUMN ... SET NOT NULL` when you remove `?` from a field. This requires a full table scan with ACCESS EXCLUSIVE lock — blocks all reads AND writes while scanning every row to verify the constraint.
- Safe pattern: (1) add CHECK constraint without validation (`NOT VALID` — brief metadata lock), (2) validate separately (SHARE UPDATE EXCLUSIVE — allows reads and writes), (3) on Postgres 12+, `SET NOT NULL` skips the scan if a validated CHECK already proves it, (4) drop the CHECK.
- Severity: **P1** on tables with >100k rows. **P3** on small tables.

**Column drops without two-phase deploy**
- Prisma generates immediate `ALTER TABLE DROP COLUMN` when you remove a field from the schema. During a rolling deploy, old instances still reference the column — runtime exceptions.
- Safe pattern: Phase 1 — remove the field from the Prisma schema, deploy code that doesn't use the column. Phase 2 — after all instances run the new code, create and run the drop migration.
- Severity: **P2** in rolling deploy environments. **P3** if deploys are atomic (all instances swap simultaneously).

**Column renames — Prisma's data loss trap**
- Prisma generates `DROP COLUMN` + `ADD COLUMN` for renames — this DESTROYS the data in the column. Must use `--create-only` and manually edit to `ALTER TABLE RENAME COLUMN`.
- Brandur's alternative for table renames: rename the table, create an updatable view with the old name, deploy code using the new name, drop the view.
- Severity: **P1** — data loss.

**Type changes that cause table rewrites**
- Safe (metadata-only): `varchar(100)` → `varchar(200)`, `varchar(n)` → `text`, increasing decimal precision.
- Dangerous (full rewrite with ACCESS EXCLUSIVE): `integer` → `bigint` (4→8 bytes physical size change), `varchar` → `integer`, `text` → `integer`, `timestamp` → `date`.
- Prisma generates straight `ALTER COLUMN ... TYPE` — full rewrite for dangerous changes. Manual intervention required for large tables.
- Severity: **P1** for type changes on large tables. Check the Postgres docs for whether a specific conversion is metadata-only or requires a rewrite.

**Adding foreign keys without NOT VALID**
- Standard `ADD FOREIGN KEY` blocks writes on BOTH the source and target tables while validating all existing rows. Fix: add with `NOT VALID` (brief lock, no validation), then `VALIDATE CONSTRAINT` separately (allows reads and writes during validation).
- Severity: **P2** — blocks two tables simultaneously.

**Large backfills in a single statement**
- A single `UPDATE users SET col = 'default'` on a large table acquires row locks on all affected rows, generates massive WAL, and can cause replication lag.
- Fix: batch in groups of 1,000-10,000 rows with pauses between batches. Use `WHERE col IS NULL` for idempotency. Run outside a transaction.
- Prisma has no built-in batching — use `$executeRaw` with manual batching.
- Severity: **P2** for backfills on tables with >100k rows.

---

## Principle 4: Queries must be bounded, correct under NULL, and explicit about what they fetch

*Carmack: if an unbounded query is possible, someone will call it on a table with 500k rows.*
*Brandur: every SELECT * and every missing LIMIT is a ticking time bomb.*

### What to check

**Unbounded queries**
- `findMany()` without `take` returns every row. Works with 100 rows in dev, causes OOM or timeout with 100k+ rows in production.
- Enforce via Client Extension:
  ```typescript
  const prisma = new PrismaClient().$extends({
    query: {
      $allModels: {
        findMany({ args, query }) {
          args.take = args.take ?? 100;
          return query(args);
        },
      },
    },
  });
  ```
- Severity: **P2** for any `findMany` without `take` on a table that could grow. **P1** on tables that already have significant data.

**SELECT * via Prisma**
- `findMany()` without `select` returns all scalar fields — including passwords, PII, large text/jsonb columns. Use `select` to limit fields, or `omit` (since Prisma 5.9.0) to exclude specific sensitive fields.
- Cross-reference with quality-backend.md: tRPC output validation provides a second layer against PII leaks.
- Severity: **P2** for queries returning user/billing models to the client without field filtering.

**NULL handling — three-valued logic traps**
- The NOT-with-NULL trap: `{ sentiment: { not: 'NEGATIVE' } }` generates `WHERE sentiment != 'NEGATIVE'`. In SQL, `NULL != 'NEGATIVE'` evaluates to `NULL` (not `TRUE`) — NULL rows are silently excluded from results.
- `undefined` in Prisma `where` is a no-op — the filter is silently omitted. `null` filters for `IS NULL`. This distinction is critical and non-obvious.
- `NOT IN` with NULLs: `WHERE id NOT IN (SELECT col FROM t)` returns NO rows if any subquery value is NULL. Use `NOT EXISTS` instead.
- Aggregation: `SUM` of no rows returns `NULL`, not `0`. Use `COALESCE(SUM(amount), 0)`.
- Severity: **P2** for NULL-related logic bugs in business queries. **P3** for cosmetic NULL issues.

**N+1 queries**
- The classic: `findMany` then a loop with `findUnique` inside. Fix: use `include` for eager-loading or `relationLoadStrategy: 'join'` (Prisma 5.8.0+) for a single LATERAL JOIN query.
- Prisma auto-batches `findUnique()` calls in the same tick into `WHERE id IN (...)` — but only for scalar equality filters. Does not work with `findMany()` or relation filters.
- Detection: enable query logging with `new PrismaClient({ log: ['query'] })` and look for repeated SELECT patterns.
- Severity: **P2** — performance degrades linearly with data size.

**Offset pagination under concurrent writes**
- Offset-based (`skip`/`take`): if a row is inserted before the current page, you see a duplicate on the next page. If deleted, you miss one. Offset also scans and discards all skipped rows.
- Cursor-based (Prisma's `cursor` API) uses `WHERE id > cursor` — consistent results, efficient at any depth.
- Severity: **P3** for admin/internal pages. **P2** for customer-facing paginated lists where duplicates or missing items are visible.

**Upsert race conditions**
- Prisma uses native `INSERT...ON CONFLICT` only when specific criteria are met (no nested queries, single model, single unique field, matching values between `where` and `create`). Otherwise it falls back to SELECT + INSERT/UPDATE — which is NOT atomic.
- Concurrent upserts with `update: {}` (empty update): both attempt INSERT, one hits `P2002: Unique constraint failed`. Fix: provide a non-empty `update` object (e.g., set the same value) to force native `ON CONFLICT`. For maximum safety, use raw `INSERT...ON CONFLICT DO UPDATE`.
- Severity: **P2** for upserts on high-contention keys. **P3** for low-contention.

---

## Principle 5: Schema design choices compound — get them right from day one

*Carmack: minimise unstructured state. Every optional field, JSON blob, and soft delete is a liability.*
*Brandur: "For services that run in production, the better defined the schema and the more self-consistent the data, the easier life is going to be."*

### What to check

**DateTime without timezone — Prisma's silent trap**
- Prisma's `DateTime` maps to `TIMESTAMP(3)` — timestamp WITHOUT time zone. During DST transitions, the same wall clock time occurs twice. Without timezone info, it's ambiguous which one you meant.
- Fix: add `@db.Timestamptz(6)` to every DateTime field from day one. `TIMESTAMPTZ` converts to UTC on storage — unambiguous.
- Prisma internally converts to UTC before writing, partially working around the problem. But other tools accessing the database directly won't know the values are UTC.
- Severity: **P2** — insidious. Works fine until you have users across timezones or hit a DST transition.

**IDs generated at ORM level instead of database level**
- `@default(cuid())` and `@default(uuid())` generate IDs in the Prisma client, not the database. The database column has no DEFAULT. Inserts via raw SQL, other tools, or database migrations produce no ID.
- `@default(uuid())` generates UUIDv4 as TEXT (36 chars). UUIDv4 inserts at random B-tree positions — index bloat 26-27% larger than sequential inserts. Inserting 50M rows: UUIDv4 took 20 minutes vs UUIDv7's 1:46 minutes.
- Fix: `@default(dbgenerated("gen_random_uuid()")) @db.Uuid` for native UUID storage at 16 bytes. When Postgres 18 ships, switch to `dbgenerated("uuidv7()")` for sequential UUIDs.
- CUID v1 is deprecated by its creator due to security concerns (leaks creation time and host fingerprint).
- Severity: **P3** for ID generation location (advisory). **P2** for UUIDs stored as TEXT instead of native UUID type (storage and performance impact at scale).

**JSON columns for structured domain data**
- JSON fields have no constraints, no foreign keys, no type enforcement. Prisma's `Json` type maps to `JsonValue` in TypeScript — effectively `any`. Brandur describes Heroku storing a JSON config blob: customers stored multi-megabyte payloads in a field with no size limit.
- Appropriate for: webhook payloads, user preferences, audit metadata — truly unstructured data.
- A schema design failure when: the data has a known shape, needs querying/joining/constraining, or represents core domain entities.
- Severity: **P2** for JSON columns storing structured domain data that should be relational. **P3** for JSON used appropriately.

**Soft delete — the invisible tax**
- Brandur: **"Soft deletion logic bleeds out into all parts of your code. Forgetting that extra predicate on deleted_at can have dangerous consequences."** And: **"As far as I'm aware, never once, in ten plus years, did anyone at any of these places ever actually use soft deletion to undelete something."** (Heroku, Stripe, Crunchy Data.)
- Soft-deleted records still occupy UNIQUE constraints — a user who deletes their account can't re-register with the same email. Partial unique indexes (`WHERE deleted_at IS NULL`) work but Prisma doesn't support them natively — must add via raw SQL, and Prisma can't use `findUnique`/`upsert` with them.
- Foreign keys become advisory with soft delete — a "deleted" parent can still be referenced.
- Brandur's alternative: hard delete + a `deleted_record` archive table. Atomic delete-and-archive via CTE. Normal queries need no `deleted_at IS NULL` filter. FKs still work. GDPR purging is trivial.
- Severity: **P3** — this is architectural advice, not a bug. Escalate to **P2** if soft delete is causing query correctness issues (missing `WHERE deleted_at IS NULL` predicates).

**Enum types — adding is safe, removing is dangerous**
- `ALTER TYPE ... ADD VALUE` is safe but cannot run inside a transaction block. Removing or renaming enum values requires recreating the entire type — Prisma generates a complex sequence that has been a source of migration bugs (multiple GitHub issues).
- Alternative: lookup tables with FK constraints. Adding/removing values is INSERT/DELETE. Can add metadata. FK ensures validity. Easier migrations.
- Severity: **P3** — use enums for truly stable value sets (status codes, roles). Use lookup tables for values that change.

---

## Principle 6: Connection management on Neon — every connection is scarce

*Carmack: understand the lifecycle of every resource you allocate.*
*Neon: PgBouncer in transaction mode, connection limits are hard constraints.*

### What to check

**Not using the connection pooler**
- Neon's `-pooler` hostname runs PgBouncer in transaction mode, supporting up to 10,000 concurrent client connections. Without it, you're limited to Postgres `max_connections` (104 on the smallest compute). At ~4k users, connection exhaustion without the pooler is guaranteed.
- Prisma CLI and migrations must use the direct (non-pooled) connection. Application code uses the pooled connection.
- Severity: **P1** for application code connecting directly to Neon without the pooler.

**connection_limit not set to 1 for serverless**
- Prisma's default connection pool is `num_physical_cpus * 2 + 1` — typically 5+ connections per client instance. In serverless, each function invocation creates its own PrismaClient. 200 concurrent functions × 5 connections = 1,000 connections, exceeding Postgres limits.
- Fix: `?connection_limit=1` in the connection string. Error symptoms: "Timed out fetching a new connection from the connection pool", "too many connections for role".
- Severity: **P1** for serverless deployments without `connection_limit=1`.

**Timeouts not configured for cold starts**
- Neon auto-suspends idle computes after 5 minutes by default. Activation takes 500ms to a few seconds. Prisma's default `connect_timeout` (5s) may be exceeded, producing `P1001: Can't reach database server`.
- Fix: `?connect_timeout=15&pool_timeout=15` in the connection string.
- Severity: **P2** — affects first requests after idle periods. At ~4k users the database likely stays active during business hours.

**Session-level features through the pooler**
- Neon's PgBouncer runs in transaction mode. Session-level features don't work: `SET`, `LISTEN/NOTIFY`, temporary tables, `WITH HOLD CURSOR`, and session-level advisory locks (`pg_advisory_lock`).
- Use transaction-level advisory locks (`pg_advisory_xact_lock`) instead — they release when the transaction ends.
- Severity: **P1** for session-level advisory locks through the pooler (silently broken). **P2** for other session features.

**Recommended connection string:**
```env
DATABASE_URL="postgresql://user:pass@ep-xxx-pooler.region.aws.neon.tech/dbname?sslmode=require&connection_limit=1&connect_timeout=15&pool_timeout=15"
DIRECT_URL="postgresql://user:pass@ep-xxx.region.aws.neon.tech/dbname?sslmode=require"
```

---

## Principle 7: Prisma's defaults are wrong for production — know the overrides

*Carmack: if the default is dangerous and changing it requires manual intervention, every new developer will hit the default.*

This is a master checklist. Every item below is a Prisma default that requires manual override for production correctness on Neon.

| What Prisma Does | What You Need | How to Fix | Severity |
|---|---|---|---|
| `TIMESTAMP(3)` for DateTime | `TIMESTAMPTZ(6)` | Add `@db.Timestamptz(6)` | P2 |
| `CREATE INDEX` (blocks writes) | `CREATE INDEX CONCURRENTLY` | `--create-only`, edit SQL, single statement per migration | P1 |
| No FK indexes | `@@index([fkField])` | Add manually to every relation | P2 |
| No CHECK constraints | Raw SQL in migrations | `--create-only`, edit migration | P2 |
| `SET NOT NULL` via full table scan | CHECK constraint pattern | `--create-only`, edit migration | P1 |
| Immediate `DROP COLUMN` | Two-phase deploy | Manual deploy coordination | P2 |
| `DROP + ADD` for renames | `RENAME COLUMN` | `--create-only`, edit migration | P1 |
| ~5 connection pool | `connection_limit=1` | URL parameter | P1 |
| 5s connect timeout | 15s for Neon cold starts | URL parameter | P2 |
| Unbounded `findMany` | Default `take` | Client Extension | P2 |
| All fields returned | Explicit `select` or `omit` | Per-query discipline | P2 |
| `cuid()`/`uuid()` as TEXT | `@db.Uuid` with `dbgenerated()` | Schema change | P3 |
| No partial unique indexes | Raw SQL | `--create-only`, edit migration | P2 |
| Upsert may not be atomic | Raw `ON CONFLICT` for critical paths | `$executeRaw` | P2 |

### The overriding migration review rule

Every `prisma migrate dev` output must be reviewed before deployment. Run `--create-only` for any migration that touches an existing table with data. Read the generated SQL. Check against the lock reference table in Principle 3. If the migration acquires ACCESS EXCLUSIVE or SHARE locks on a table with significant data, rewrite it.

---

## Gaps: What This Doc Doesn't Cover

- **Security patterns**: SQL injection, access control, IDOR, secrets. Covered by **security.md (Hunt)**.
- **Backend error handling**: Prisma error leakage through tRPC, error formatting, retry logic. Covered by **quality-backend.md (Collina)**.
- **Performance tuning**: `EXPLAIN ANALYZE`, index type selection (B-tree, GIN, GiST), partitioning, VACUUM tuning, query planner statistics. This is a correctness doc, not a DBA guide.
- **Enterprise scale**: Read replicas, sharding, multi-region, logical replication. At ~4k users, premature.
- **Postgres administration**: `pg_stat_statements`, backup strategies, user/role management, `pg_repack`. Out of scope for code review.
- **ORM comparisons**: The ORM is Prisma. The doc works with it, not against it.

---

## Quick Reference: Severity Guide

| Severity | Pattern | Examples |
|----------|---------|----------|
| **P1 — Fix Now** | Data loss, data corruption, guaranteed production incidents | Column renames via DROP+ADD, `SET NOT NULL` on large tables, non-concurrent index creation on large tables, `prisma` instead of `tx` in interactive transactions, missing pooler connection, default connection pool in serverless, session advisory locks through PgBouncer, missing compound uniques on business identity fields |
| **P2 — Fix Soon** | Correctness bugs that compound or manifest at scale | READ COMMITTED for check-then-act, side effects inside transactions, long transaction duration, unbounded queries, SELECT * returning PII, NULL logic bugs, DateTime without timezone, missing FK indexes, missing CHECK constraints, upsert race conditions, soft delete correctness issues, offset pagination on customer-facing lists |
| **P3 — Consider** | Schema hygiene and architectural guidance | ORM-level ID generation, JSON for appropriate use cases, enum vs lookup table choice, unnecessary nullable fields, cursor pagination on internal pages, CUID deprecation |

### The Overriding Filter

Before writing any finding, apply the Carmack-Brandur synthesis:

1. **Is there a database constraint that could enforce this invariant?** If yes and it's missing, flag it. The constraint is the assertion. (Brandur: the database is the foundational substrate.)
2. **Can this migration lock a production table?** If yes, check the lock type and table size. If ACCESS EXCLUSIVE on a table with data, the migration must be rewritten. (Carmack: if it CAN lock, it WILL.)
3. **Is this query bounded?** No `take` on `findMany`, no `select` on sensitive data, no NULL handling in WHERE clauses — flag it. (Both: unbounded operations are ticking time bombs.)
4. **Does this transaction hold a scarce connection?** On Neon with `connection_limit=1`, every interactive transaction blocks all other queries. Keep transactions short. (Both: understand the lifecycle of every resource.)
5. **Is Prisma's default safe here?** Prisma's defaults are optimised for developer experience, not production correctness. Check the override table. (Carmack: if the default is wrong and requires manual intervention, every new developer will hit the default.)
