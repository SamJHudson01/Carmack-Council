# Stack Assumptions

The Carmack Council skills are opinionated for the stack below. If you use a different stack, fork and adapt. This file lists every stack-specific assumption, where it appears, and what to change.

## The Stack

| Layer | Technology | Alternative examples |
|-------|-----------|---------------------|
| Framework | Next.js App Router | Remix, SvelteKit, Nuxt |
| Language | TypeScript (strict mode) | — |
| API layer | tRPC | REST, GraphQL |
| ORM | Prisma | Drizzle, Kysely, TypeORM |
| Database | Neon (serverless Postgres) | Supabase, PlanetScale, RDS |
| Auth | Clerk | NextAuth, Lucia, Auth0 |
| Styling | CSS Modules + BEM | Tailwind, styled-components, vanilla-extract |
| Deployment | Railway (long-lived containers) | Vercel, Fly.io, AWS |
| Product type | B2B SaaS (~4k users) | — |

---

## Where Assumptions Live

### SKILL.md files — Stack Context sections

Every SKILL.md has a "Stack Context" section near the top. This is the primary place to update.

| File | What to change |
|------|---------------|
| `skills/council-review/SKILL.md` | Stack Context section (lines ~12–26). Update framework, API layer, ORM, DB, auth, styling, deployment target. Update the "B2B SaaS at ~4k users" scale statement. |
| `skills/council-plan/SKILL.md` | Stack Context section (lines ~12–23). Same stack list. |
| `skills/council-implement/SKILL.md` | Stack Context section (lines ~12–23). Same stack list. |
| `skills/spec-writer/SKILL.md` | No stack context section — spec-writer is stack-agnostic by design. |

### SKILL.md files — Subagent prompts

The council-review and council-plan SKILL.md files contain subagent prompt templates that reference specific technologies.

| Pattern | Where it appears | What to change |
|---------|-----------------|---------------|
| "tRPC" / "No REST routes" | council-review subagent prompts (Collina, Dodds, Leach), council-plan subagent prompts | Replace with your API layer |
| "Prisma" / "Neon" | council-review subagent prompts (Leach, Collina), council-plan subagent prompts | Replace with your ORM/DB |
| "CSS Modules + BEM" / "never suggest Tailwind" | council-review subagent prompts (Dodds, Saarinen), council-plan subagent prompts | Replace with your styling approach |
| "Clerk" | council-review and council-plan Stack Context | Replace with your auth provider |
| "Server Components" / "Server Actions" | council-review and council-plan subagent prompts | Remove if not using RSC-based framework |
| "Railway" / "NOT Vercel serverless" | council-review Stack Context | Replace with your deployment target; if serverless, re-enable the `waitUntil()` and lifetime warnings |
| "B2B SaaS" / "~4k users" | council-review and council-plan | Replace with your product type and scale |
| `~/.claude/skills/react-best-practices/rules/` | council-review Vercel subagent, council-plan Vercel subagent, council-implement reference table | This is a third-party skill. Replace with your own performance reference doc, or remove the Vercel subagent |
| `skills/ui-architect/SKILL.md` | council-review Saarinen subagent, council-plan Saarinen subagent | Optional read — remove if you don't have this skill |
| `skills/ux-architect/SKILL.md` | council-review Friedman subagent, council-plan Friedman subagent | Optional read — remove if you don't have this skill |
| `skills/test-architect/SKILL.md` | council-review Beck subagent | Optional read — remove if you don't have this skill |

### Reference documents

The reference docs contain stack-specific patterns and examples throughout. These are the most work to adapt.

| Reference | Stack assumptions | What to change |
|-----------|-----------------|---------------|
| `references/security.md` | Clerk auth, tRPC middleware, Next.js middleware, Prisma queries | Replace with your auth/API/ORM security patterns |
| `references/quality-backend.md` | tRPC procedures, Next.js Server Actions, Prisma client, Railway deployment | Replace with your API layer, ORM, and deployment patterns |
| `references/quality-frontend.md` | React, Next.js App Router, Server/Client Components, CSS Modules + BEM | Replace with your frontend framework and styling approach |
| `references/quality-postgres.md` | Prisma ORM, Neon serverless Postgres, PgBouncer | Replace with your ORM and Postgres provider. Core Postgres principles (schema design, migrations, transactions) are universal |
| `references/quality-testing.md` | Vitest, Cypress, tRPC test utilities | Replace with your test framework and tooling |
| `references/quality-llm.md` | General LLM pipeline principles — largely stack-agnostic. References Braintrust for evals | Replace eval tooling references if using a different platform |
| `references/quality-ui.md` | CSS Modules + BEM, dark theme, Inter + JetBrains Mono fonts, Linear-inspired aesthetic | Replace with your design system, theme, fonts, and aesthetic |
| `references/quality-ux.md` | B2B SaaS, data-dense analytical interface | Adjust for your product type and user context |
| `references/refactoring.md` | tRPC, Prisma, Next.js patterns | Replace with your stack's refactoring patterns. Core refactoring principles are universal |

### Spec-writer references

The spec-writer references (`references/spec-writer/`) are stack-agnostic. No changes needed for a different stack.

---

## How to Fork

1. **Edit this file** — Update "The Stack" table with your technologies.
2. **Update Stack Context sections** — In each SKILL.md, replace the Stack Context block.
3. **Update subagent prompts** — Search for the patterns listed above and replace.
4. **Update reference docs** — This is the heavy lift. Each reference doc has stack-specific examples woven throughout. Replace them with equivalent patterns from your stack. The principles themselves (e.g., "crash on programmer errors, handle operational errors") are universal — only the examples change.
5. **Rebuild** — Run `./scripts/build.sh` to produce updated `.skill` packages.

Start with the SKILL.md files (fast, high impact), then work through the reference docs one at a time.
