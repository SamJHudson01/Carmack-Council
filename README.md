# The Carmack Council

An ultra-opinionated, multi-agent development framework for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Founded on my personal belief that off-the-shelf Claude Code skills often lead to average results, and stack specific skills based on real world, battle tested engineering principles lead to awesomeness. 

## But why The Carmack Council?

Named after GOAT engineer and all around legend John Carmack, and built on his engineering philosophy: simplicity over cleverness, concrete over abstract, economic over aesthetic.

This skill was built for my own use with no initial intention to actually release it, and as such is tuned to my preferred greenfield stack:

- Next.js App Router
- tRPC
- Prisma
- Neon
- Clerk
- CSS Modules + BEM
- Railway

I have reasons (ranging from solid to near arbitrary) for picking all of these. This is what I used pre-AI because it let me ship fast with decent performance, generous free tiers and good scalability.

Some people hate this stack or elements of it. I'm OK with that. The point is the council concept — adapting it to your stack is straightforward.

The council is chaired by John Carmack and includes 10 domain experts:

| Expert | Domain | Reference Doc | Link |
|--------|--------|--------------|------|
| Troy Hunt | Security | `security.md` | https://www.troyhunt.com/ |
| Martin Fowler | Refactoring / Structure | `refactoring.md` | https://martinfowler.com/ |
| Kent C. Dodds | Frontend Quality | `quality-frontend.md` | https://kentcdodds.com/ |
| Matteo Collina | Backend Quality | `quality-backend.md` | https://nodeland.dev/ |
| Brandur Leach | Postgres Quality | `quality-postgres.md` | https://brandur.org/ |
| Vercel Performance | Performance | External rules | https://vercel.com/ |
| Simon Willison | LLM Pipeline Quality | `quality-llm.md` | https://simonwillison.net/ |
| Karri Saarinen | UI Quality | `quality-ui.md` | https://karrisaarinen.com/ |
| Vitaly Friedman | UX Quality | `quality-ux.md` | https://www.smashingmagazine.com/author/vitaly-friedman/ |
| Kent Beck | Test Quality | `quality-testing.md` | https://kentbeck.com/ |

Every plan, implementation decision and review finding is grounded in the publicly shared expertise of domain leaders who build and design world-class software. Not "best practices." Not docs examples. The strong opinions of engineers and designers whose work is next level.

They're all total ballers. Check out their sites, buy their books, use their products, enroll in their courses.



## The Workflow

```
/spec-writer  →  /council-plan  →  /council-implement  →  /council-review
    ↑                                                           |
    └───────────────────────────────────────────────────────────┘
```

1. **Spec Writer** — Produces structured specifications with Job Stories, Gherkin acceptance criteria, and three-tier boundaries. Adaptive complexity: small changes get 200 words, features get 500–800, products get up to 2,000.

2. **Council Plan** — Carmack chairs 10 domain experts who independently advise on how to build the feature. Interactive discovery with the developer, then parallel subagent dispatch. Produces a sequenced, dependency-ordered implementation plan with no code.

3. **Council Implement** — Executes the plan task by task. Loads each expert's reference document before implementing their task. Verifies (type check, lint, test) after every task. Produces an implementation log.

4. **Council Review** — Ten domain experts independently review the code in parallel, each in their own context window. The Chair merges, deduplicates, and prioritises into P1/P2/P3 findings. Automated checks (tsc, lint, vitest) run first. New conventions surfaced during review are flagged for the user to accept into conventions.md


### The Vercel Performance Expert
The Vercel Performance subagent references ~/.claude/skills/react-best-practices/rules/ — this is a separate Vercel skill, not part of this repo. If you don't have it installed, the Vercel subagent will fail gracefully (no recommendations returned), and the other nine experts will work fine. The review and plan will note "Vercel — no findings" in the breakdown, which is accurate if slightly misleading. you can also just delete the Vercel expert from the Skill.md file

If you want the full 10-expert experience, install the [Vercel React Best Practices](https://github.com/vercel-labs/agent-skills) skill separately. If you don't care about Next.js performance auditing, ignore this entirely — the council works without it.


## Installation

### Quick install

Download individual `.skill` packages from the [`dist/`](dist/) directory:

- [`council-review.skill`](dist/council-review.skill) — Code review with 10 parallel experts
- [`council-plan.skill`](dist/council-plan.skill) — Feature planning with 10 parallel experts
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

The key architectural pattern is **parallel subagents with independent context windows**. When council-review runs, the Chair (orchestrator) doesn't read every file — it builds a structural map, writes a context brief, then dispatches 10 subagents in parallel. Each subagent gets its own 200k context window, reads only its domain-relevant files, and produces findings independently. The Chair then merges, deduplicates, and prioritises.

This scales to large codebases because no single context window needs to hold everything. The Chair orchestrates; the experts deep-read.

## conventions.md

The council learns. When a review surfaces a pattern worth keeping — an error handling approach, a naming convention, a component structure — you accept it into `conventions.md` at your project root. All three downstream skills read this file: **council-plan** respects conventions when architecting tasks, **council-implement** follows them when writing code, and **council-review** skips them when scanning for findings. The council never flags accepted patterns as issues and never plans against decisions you've already made.

You can also add your own conventions directly — anything you want the council to treat as settled. If your team has a preferred pattern for API error responses or a rule about where shared types live, add it. The council doesn't care whether a convention came from a review or from you. It just respects what's in the file.

This is what gives the workflow its compound effect. The first review is cold. By the tenth, the council knows your codebase's accepted patterns and only flags genuine new issues.

The file is simple — each convention is a short entry describing what the pattern is and why it exists. See [`example_conventions.md`](example_conventions.md) for the format.

## Disclaimer
If somehow a member of the council stumbles upon this repo, please know that the reason you're here is because I (and many others) see you as pretty much the absolute leader in your domain. I basically think you're awesome, and fanboy hard on your work. 

If you feel like I've misrepresented you, made you look bad or just don't want your name on this at all, feel free to reach out. I'm happy to make changes. 

Please don't sue me x

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with skill support
- Python 3.6+ (for the build script)

## License

MIT — see [LICENSE](LICENSE).
