# Carmack Council

A multi-agent development framework for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Named practitioners serve as domain experts — each with dedicated reference documents encoding their philosophy — running a structured **spec, plan, implement, review** workflow.

The council is chaired by John Carmack's engineering philosophy: simplicity over cleverness, concrete over abstract, economic over aesthetic. Every recommendation traces to a named expert and a specific principle.

## The Workflow

```
/spec-writer  →  /council-plan  →  /council-implement  →  /council-review
    ↑                                                           |
    └───────────────────────────────────────────────────────────┘
```

1. **Spec Writer** — Produces structured specifications with Job Stories, Gherkin acceptance criteria, and three-tier boundaries. Adaptive complexity: small changes get 200 words, features get 500–800, products get up to 2,000.

2. **Council Plan** — Carmack chairs nine domain experts who independently advise on how to build the feature. Interactive discovery with the developer, then parallel subagent dispatch. Produces a sequenced, dependency-ordered implementation plan with no code.

3. **Council Implement** — Executes the plan task by task. Loads each expert's reference document before implementing their task. Verifies (type check, lint, test) after every task. Produces an implementation log.

4. **Council Review** — Nine domain experts independently review the code in parallel, each in their own context window. The Chair merges, deduplicates, and prioritises into P1/P2/P3 findings. Automated checks (tsc, lint, vitest, cypress) run first.

## The Council

| Expert | Domain | Reference Doc |
|--------|--------|--------------|
| Troy Hunt | Security | `security.md` |
| Martin Fowler | Refactoring / Structure | `refactoring.md` |
| Kent C. Dodds | Frontend Quality | `quality-frontend.md` |
| Matteo Collina | Backend Quality | `quality-backend.md` |
| Brandur Leach | Postgres Quality | `quality-postgres.md` |
| Vercel Performance | Performance | External rules |
| Simon Willison | LLM Pipeline Quality | `quality-llm.md` |
| Karri Saarinen | UI Quality | `quality-ui.md` |
| Vitaly Friedman | UX Quality | `quality-ux.md` |
| Kent Beck | Test Quality | `quality-testing.md` |

Not every expert participates in every skill. The plan uses all ten. The review uses nine (no Willison — most code reviews don't involve LLM pipelines). The implementer loads the relevant expert per task.

## Installation

### Quick install

Download individual `.skill` packages from the [`dist/`](dist/) directory:

- [`council-review.skill`](dist/council-review.skill) — Code review with nine parallel experts
- [`council-plan.skill`](dist/council-plan.skill) — Feature planning with nine parallel experts
- [`council-implement.skill`](dist/council-implement.skill) — Plan execution with expert-guided implementation
- [`spec-writer.skill`](dist/spec-writer.skill) — Structured specification generation

Each `.skill` file is a self-contained zip archive with the SKILL.md and all required reference documents bundled inside. Install via Claude Code's skill installation.

### From source

```bash
git clone https://github.com/SamHudson/carmack-council.git
cd carmack-council
chmod +x scripts/build.sh
./scripts/build.sh
```

This reads each skill's `manifest.json`, copies the declared references from the shared `references/` directory into each skill folder, validates, packages into `.skill` files in `dist/`, and cleans up.

## Repo Structure

```
carmack-council/
├── README.md
├── STACK.md              # Every stack-specific assumption, listed
├── LICENSE               # MIT
├── references/           # Single source of truth for all reference docs
│   ├── security.md
│   ├── quality-backend.md
│   ├── quality-frontend.md
│   ├── quality-postgres.md
│   ├── quality-testing.md
│   ├── quality-llm.md
│   ├── quality-ui.md
│   ├── quality-ux.md
│   ├── refactoring.md
│   └── spec-writer/      # Spec-writer-specific references
│       ├── anti-patterns.md
│       ├── acceptance-criteria-guide.md
│       ├── feature-spec.md
│       ├── product-spec.md
│       ├── small-change.md
│       └── boundary-examples.md
├── skills/
│   ├── council-review/
│   │   ├── SKILL.md
│   │   └── manifest.json
│   ├── council-plan/
│   │   ├── SKILL.md
│   │   └── manifest.json
│   ├── council-implement/
│   │   ├── SKILL.md
│   │   └── manifest.json
│   └── spec-writer/
│       ├── SKILL.md
│       └── manifest.json
├── scripts/
│   ├── build.sh
│   ├── package_skill.py
│   └── quick_validate.py
└── dist/                 # Pre-built .skill packages
    ├── council-review.skill
    ├── council-plan.skill
    ├── council-implement.skill
    └── spec-writer.skill
```

## Forking for Your Stack

These skills are opinionated for a specific stack (Next.js App Router / tRPC / Prisma / Neon / Clerk / CSS Modules + BEM / Railway). **We ship opinionated — you fork and adapt.**

See [`STACK.md`](STACK.md) for:
- Every stack-specific assumption across all skills and references
- Which files contain each assumption
- A step-by-step guide for adapting to your stack

General approach:
1. Update the Stack Context sections in each SKILL.md
2. Update the subagent prompt templates that reference specific technologies
3. Update reference documents where stack-specific patterns are described
4. Run `./scripts/build.sh` to rebuild packages

The principles are universal — simplicity, correctness, economic thinking. Only the stack-specific patterns change.

## How It Works

Each skill is a SKILL.md file (the instruction set) plus reference documents (the domain knowledge). The SKILL.md tells Claude Code how to orchestrate — which subagents to spawn, what phases to follow, what output format to use. The reference docs give each subagent deep domain expertise.

The key architectural pattern is **parallel subagents with independent context windows**. When council-review runs, the Chair (orchestrator) doesn't read every file — it builds a structural map, writes a context brief, then dispatches nine subagents in parallel. Each subagent gets its own 200k context window, reads only its domain-relevant files, and produces findings independently. The Chair then merges, deduplicates, and prioritises.

This scales to large codebases because no single context window needs to hold everything. The Chair orchestrates; the experts deep-read.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with skill support
- Python 3.6+ (for the build script)

## License

MIT — see [LICENSE](LICENSE).
