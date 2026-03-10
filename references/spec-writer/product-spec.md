# Template: Product / System Spec

Use this template for new products, major system redesigns, or multi-feature epics. This is the heaviest tier — but 2,000 words is still a ceiling, not a target. If a section has nothing useful to say, skip it. The goal is still the shortest document that makes "done" unambiguous.

**Key difference from Feature tier:** Product specs are often broken into phases and may spawn multiple feature specs. This template defines the full scope and then recommends decomposition into implementable chunks.

---

## Output Format

```markdown
# Spec: [product/system name]

**Date:** [YYYY-MM-DD]
**Status:** Draft | Confirmed | In Progress | Done

## Vision

[3–5 sentences. What this product/system is, who it's for, and why it matters. The "why now" is as important as the "what." If someone reads only this section, they should understand the ambition and the bet.]

## Problem Statement

[What problem exists today. Who has this problem. What they currently do about it (workaround, competitor product, manual process). Why existing solutions fall short. Be specific about pain — "users are frustrated" is weak. "Users spend 20 minutes per day manually reconciling data between two systems" is strong.]

## Target Users

[Who are the primary users? Secondary users? What do they care about? What do they NOT care about? Keep to 2–3 user segments maximum. If you're listing more, you haven't prioritised.]

### User segment 1: [name]
- **Context:** [When and why they encounter this problem]
- **Primary need:** [The one thing they care about most]
- **Success looks like:** [Observable behaviour change]

### User segment 2: [name]
- **Context:** [When and why they encounter this problem]
- **Primary need:** [The one thing they care about most]
- **Success looks like:** [Observable behaviour change]

## Scope

### In scope (v1)
- [Concrete capability 1]
- [Concrete capability 2]
- [Concrete capability 3]

### Out of scope (v1) — future consideration
- [Capability explicitly deferred to v2+]
- [Integration that's not needed yet]

### Non-goals
- [Thing this product deliberately does NOT optimise for — even if users might expect it]

## Stories

[Group stories by user segment or feature area. For product-tier specs, stories define the major capabilities — each story here may later become its own feature spec.]

### [Feature area 1]

#### Story 1.1: [situation summary]

**When** [situation/trigger], **I want to** [action/capability], **so I can** [outcome/benefit].

**Acceptance Criteria:**

Given [precondition]
When [single trigger]
Then [expected outcome]

Given [error/edge condition]
When [trigger that should fail gracefully]
Then [expected error handling]

#### Story 1.2: [situation summary]

**When** [situation/trigger], **I want to** [action/capability], **so I can** [outcome/benefit].

**Acceptance Criteria:**

Given [precondition]
When [single trigger]
Then [expected outcome]

Given [error/edge condition]
When [trigger that should fail gracefully]
Then [expected error handling]

### [Feature area 2]

[Continue pattern — group stories logically]

## Technical Context

[Only constraints that affect the entire product. Stack decisions, hosting constraints, third-party integrations, compliance requirements, performance budgets.]

- **Stack:** [Language, framework, key dependencies — only if decided]
- **Integrations:** [External APIs, auth providers, payment processors]
- **Constraints:** [Compliance, data residency, performance SLAs, accessibility standards]
- **Existing systems:** [What this must interoperate with]

## Boundaries

### ✅ Always
- [Convention that applies across the entire product]
- [Quality gate — e.g., "Every user-facing feature must have acceptance tests"]
- [Architectural rule — e.g., "All external API calls go through a service layer"]

### ⚠️ Ask first
- [Infrastructure decisions — e.g., "Database technology selection"]
- [External commitments — e.g., "Third-party API contracts"]
- [Scope additions — e.g., "Any feature not listed in the Stories section"]

### 🚫 Never
- [Data handling — e.g., "Store payment credentials outside PCI-compliant storage"]
- [Security — e.g., "Implement custom authentication instead of using the specified auth provider"]
- [Architecture — e.g., "Create direct database access from client-side code"]

## Success Metrics

[How do we know this product is working? Define metrics for launch and for 30/60/90 days post-launch.]

### Launch criteria (v1 is done when)
- [Binary success criterion — e.g., "A new user can complete the core workflow end-to-end"]
- [Quality bar — e.g., "Zero P1 bugs, fewer than 3 P2 bugs"]

### 30-day success
- [Usage metric — e.g., "50 active users completing at least one workflow per week"]
- [Quality metric — e.g., "p95 response time under 500ms"]

## Recommended Decomposition

[Break the product spec into implementable chunks. Each chunk should be achievable in 1–3 days of agent or developer work. Order them by dependency — what must be built first.]

### Phase 1: [foundation]
- Story 1.1 + Story 1.2 — [why these first]

### Phase 2: [core feature]
- Story 2.1 + Story 2.2 — [what this unlocks]

### Phase 3: [enhancement]
- Remaining stories — [only after core is validated]

[Each phase can be extracted into its own Feature-tier spec when ready for implementation.]

## Assumptions

- [Any assumption made during spec writing that hasn't been confirmed]
- [Mark each: (confirmed) or (unconfirmed)]

## Open Questions

- [Genuine unknowns that need answers before or during implementation]
- [Don't pretend you have all the answers — Figma's PRD template taught this well]

---

*After implementing each phase, compare results against the acceptance criteria for that phase's stories and list any unmet requirements.*
```

---

## Rules for Product Specs

1. **This spec defines scope and boundaries — it does NOT replace feature specs.** Each phase should eventually get its own feature-tier spec before implementation. This document is the map; feature specs are the turn-by-turn directions.
2. **Vision must answer "why now."** Not just what the product does, but why this is the right time to build it. Without "why now," every product idea looks equally valid.
3. **2–3 user segments maximum.** If you're building for more than 3 distinct user types in v1, you haven't prioritised. Ship for one well, then expand.
4. **Stories grouped by feature area, not by user.** At product scale, feature areas are the natural decomposition unit. User-centric grouping creates cross-cutting stories that are impossible to implement incrementally.
5. **Recommended Decomposition is mandatory.** A product spec without phasing is a wish list. The phases define what gets built first, and therefore what gets validated first.
6. **Open Questions section is mandatory.** Pretending all questions are answered is how products ship the wrong thing. Acknowledging uncertainty is a feature, not a weakness.
7. **2,000 words is the ceiling.** If you need more, the product scope is too broad for one spec. Split into a product overview (vision + scope + decomposition) and separate feature specs for each phase.