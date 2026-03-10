# The Carmack Council

An ultra-opinionated, multi-agent development framework for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Founded on my personal belief that off-the-shelf Claude Code skills often lead to average results, and stack specific skills based on real world, battle tested engineering principles leads to awesomeness. 

## But why The Carmack Council?

Named after legendary engineer John Carmack, and based on his engineering philosophy: simplicity over cleverness, concrete over abstract, economic over aesthetic. 

This stack was built for my own use with no initial intention to actually release it to the public, and as such uses my preferred stack:

- Next.js App Router
- tRPC
- Prisma
- Neon
- Clerk
- CSS Modules + BEM
- Railway

I have reasons (ranging from solid to near arbitrary) for picking all of these technologies. This is what I used pre-AI, because it allowed me to get new projects spun up and working in a short space of time, whilst offering great performance, generous free tiers and decent scalability. 

I'm aware that some people hate this stack or elements of it. I'm OK with that. The main point of the repo is to introduce the council concept, and it's easy enough to adapt this to your preferred/existing stack.

The council is chaired by John Carmack and includes nine domain experts: 

| Expert | Domain | Reference Doc |
|--------|--------|--------------|
| Troy Hunt | Security | `security.md` | https://www.troyhunt.com/ 
| Martin Fowler | Refactoring / Structure | `refactoring.md` | https://martinfowler.com/
| Kent C. Dodds | Frontend Quality | `quality-frontend.md` | https://kentcdodds.com/
| Matteo Collina | Backend Quality | `quality-backend.md` | https://nodeland.dev/
| Brandur Leach | Postgres Quality | `quality-postgres.md` | https://brandur.org/
| Vercel Performance | Performance | External rules | https://vercel.com/
| Simon Willison | LLM Pipeline Quality | `quality-llm.md` | https://simonwillison.net/
| Karri Saarinen | UI Quality | `quality-ui.md` | https://karrisaarinen.com/
| Vitaly Friedman | UX Quality | `quality-ux.md` | https://www.smashingmagazine.com/author/vitaly-friedman/
| Kent Beck | Test Quality | `quality-testing.md` | https://kentbeck.com/

The whole point of this approach is that all plans, implementation work and reviews are grounded in the publicly shared principles of some of the world's leading engineers and designers. Not widely regarded best practices. Not based on examples from docs. But the strong opinions of the people who build/design software that I love.

These guys are all total ballers and I enourage you to check out their sites, buy their books, use their products and enroll in their courses.

## Disclaimer
If somehow a member of the council stumbles upon this repo, please know that the reason you're here is because I (and many others) see you as pretty much the absolute leader in your domain. I basically think you're awesome, and fanboy hard on your work. 

If you feel like I've misrepresented you, made you look bad or just don't want your name on this at all, feel free to reach out. I'm happy to make changes.



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
git clone https://github.com/SamJHudson01/Carmack-Council.git
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
