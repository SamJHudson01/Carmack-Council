# Refactoring Reference — Carmack × Fowler

Philosophy: John Carmack. Specifics: Martin Fowler.
Stack context: Next.js App Router / React / TypeScript / tRPC / Prisma / Neon / Clerk / CSS Modules + BEM.

Every refactoring finding must answer: **"Will this slow us down?"** — not "is this clean?"
Fowler: "The point of refactoring is not to create 'clean code', it is purely economic — we refactor to make it faster."

---

## The Central Question: Less Structure or Better Structure?

Carmack and Fowler both want code that minimises the gap between what the programmer thinks is happening and what actually happens. They disagree on how:

- **Fowler** closes the gap through naming, extraction, and small functions you can read like prose.
- **Carmack** closes the gap through sequential visibility, inlining, and keeping state mutations in plain sight.

**The synthesis:** extract **pure functions** freely — both philosophies approve. Keep **state-mutating code** visible and sequential — Carmack's objection is specifically to hiding mutation behind a name. Fowler would agree that extract-then-mutate-surprisingly is bad; he addresses it through different smells (Mutable Data, Global Data) rather than inlining.

When reviewing, ask: **is this extraction hiding state mutation, or isolating pure logic?** The first is dangerous. The second is universally beneficial.

---

## Principle 1: Refactoring is economic — if it won't slow you down, leave it alone

*Fowler: "The point of refactoring is not to create 'clean code', it is purely economic."*
*Carmack: "The function that is least likely to cause a problem is one that doesn't exist."*

### The Design Stamina Hypothesis

Good internal quality pays off in **weeks, not months**. The common "we don't have time to refactor" objection is inverted — you don't have time NOT to. But the corollary is equally important: refactoring code you won't change again is pure waste. Fowler: "It's pointless to refactor a system you will never change, because you'll never get a payback."

### Reviewer filter

Before flagging any structural issue, ask:
- **Is this code likely to change?** If it's stable and working, leave it alone regardless of how it looks.
- **Is the current structure actively making changes harder?** If someone could add the next feature without confusion, the structure is fine.
- **Would this refactoring pay off in weeks?** If only in months, it's probably not worth flagging.

If you can't answer "yes" to at least one of the first two, don't flag it. This filter kills 50% of low-value code review comments.

---

## Principle 2: Extract pure logic, keep mutations visible

*Carmack: "The real enemy addressed by inlining is unexpected dependency and mutation of state, which functional programming solves more directly and completely."*
*Fowler: Extract Function is "ninety-nine percent of the time" the right refactoring for long functions.*

### The pure function rule

- **Extracting pure functions** (no side effects, no external state): always safe, always beneficial. Fowler gets his named, testable, small functions. Carmack gets state-mutation-free code you can reason about.
- **Extracting impure functions** (database calls, API calls, state mutations): context-dependent. If the extraction hides what state is being modified and when, it's making the code harder to reason about. Keep impure operations visible in the calling flow.

### What to check

**Long functions that mix pure and impure code**
- Can the pure computation be extracted, leaving a clear sequence of side effects in the caller?
- Are there pure transformations buried inside database transactions or API calls?
- Severity: **P2** if the mixing makes the function hard to modify safely

**Functions that lie about their side effects**
- Function named `getUser` that also modifies state (Fowler: Mysterious Name meets Carmack: hidden mutation)
- Functions that appear pure but mutate through closures, global state, or reference parameters
- Severity: **P2** — these are bug factories

**Excessive extraction of trivial code**
- Single-use helper functions that add a name but no clarity — just indirection
- Carmack: "I specifically disagree with [not making functions larger than a page or two] — if a lot of operations are supposed to happen in a sequential fashion, their code should follow sequentially."
- If reading the extracted function requires jumping to its definition every time, the extraction failed
- Severity: **P3**

---

## Principle 3: State is the primary source of bugs — minimise and contain it

*Carmack: "A large fraction of the flaws in software development are due to programmers not fully understanding all the possible states their code may execute in."*
*Fowler added Mutable Data, Global Data, and Loops as NEW smells in his 2018 edition — reflecting the same insight.*

Both identify mutable state as the root cause. Carmack pushes toward elimination (functional programming). Fowler pushes toward containment (encapsulation). For a TypeScript/React stack, you have tools for both.

### What to check

**Mutable Data (Fowler: new smell, high priority)**
- Mutable variables with scope beyond a few lines — risk increases with scope
- Calculated/derived values stored as mutable state instead of computed on access (Fowler: "particularly pungent")
- In React: state that could be derived from other state or props
- Severity: **P2** when scope is wide, **P3** when scope is local

**Global Data (Fowler: new smell)**
- Module-level mutable variables, singletons with mutable state
- In Next.js: mutable state in module scope that persists across requests in serverless (this is a correctness bug, not just a smell)
- Severity: **P1** if it causes cross-request contamination in Next.js, **P2** otherwise

**State colocation failures**
- React state living higher in the component tree than necessary (prop drilling as a symptom)
- Server state duplicated in client state instead of using a cache (React Query/SWR pattern)
- Severity: **P3** unless causing re-render cascades or stale data bugs

---

## Principle 4: Names reveal design — bad names mask bad structure

*Fowler: "When you can't think of a good name for something, it's often a sign of a deeper design malaise. Puzzling over a tricky name has often led us to significant simplifications."*
*Carmack: values clarity of intent — through inline sequential code where operations speak for themselves.*

Fowler placed Mysterious Name **first** in his 2nd edition smell catalog to signal its importance. A name isn't cosmetic — it's a correctness signal. If you can't name it clearly, you probably don't understand what it does.

### What to check

**Names that lie or mislead**
- Functions whose names don't describe all their effects (especially side effects)
- Boolean variables where `true` and `false` aren't obvious from the name
- Generic names: `data`, `info`, `result`, `handler`, `process`, `manager` — almost always hiding unclear responsibility
- Severity: **P2** if the name actively misleads about behavior, **P3** if merely vague

**Comments as deodorant**
- Fowler: "When you feel the need to write a comment, first try to refactor the code so that any comment becomes superfluous."
- Comments explaining WHAT the code does → the code should be clearer
- Comments explaining WHY → these are valuable, keep them
- Severity: **P3** — but flag the underlying clarity issue, not the comment itself

**Inconsistent vocabulary**
- Same concept with different names across the codebase (user/account/member, create/add/insert)
- In Next.js: inconsistent naming between route handlers, server actions, and client functions for the same operation
- Severity: **P3** but compounds over time

---

## Principle 5: Smells that compound — the ones that actually slow you down

Not all smells are equal. These are the ones Fowler flags as highest-cost, filtered through the economic test.

### Feature Envy

*Fowler: "A classic case occurs when a function in one module spends more time communicating with functions or data inside another module than it does within its own module."*

Code in the wrong place. The fundamental rule: **put things together that change together.**
- In Next.js: a Server Action that mostly manipulates data belonging to a different domain module
- In React: a component that imports 5+ things from another feature's directory
- Severity: **P2** if it causes shotgun surgery, **P3** if isolated

### Shotgun Surgery

One change requires edits across many files. Fowler's counterintuitive fix: **inline first, then re-extract.** Pull the scattered logic together into one (temporarily large) place, then split along better boundaries. Don't be afraid of a large intermediate step.

- In this stack: changing a data model requires touching the Prisma schema, the tRPC router, the input Zod schema, the client call, and possibly the component — but tRPC's type inference should make most of these cascade automatically. If you're manually updating types in multiple places, the type bridge is broken.
- Severity: **P2** — this is where velocity dies

### Primitive Obsession

*Fowler: "We find many programmers are curiously reluctant to create their own fundamental types... such as money, coordinates, or ranges."*

- Strings where domain types belong: user IDs as `string` instead of branded types, dates as strings, money as `number`
- In TypeScript: this is cheap to fix with branded types or Zod schemas. The type system is right there.
- Severity: **P3** unless causing unit confusion bugs (**P2**)

### Data Clumps

*Fowler: "Consider deleting one of the data values. If you did this, would the others make any sense? If they don't, it's a sure sign that you have an object that's dying to be born."*

- Same 3+ parameters passed together to multiple functions
- In API routes: the same set of fields extracted from the request in multiple handlers
- Severity: **P3**

### Speculative Generality

*Fowler: "You get it when people say, 'Oh, I think we'll need the ability to do this kind of thing someday.'"*
*Carmack: code size is the best predictor of defects — unused generality is dead weight that breeds bugs.*

- Abstraction layers for one implementation
- Config systems with one configuration
- Generic type parameters that are always the same concrete type
- Fowler's YAGNI test: imagine the refactoring needed to add the feature later. If it's cheap, defer it.
- Severity: **P2** if adding significant complexity, **P3** if just unused parameters

---

## Principle 6: Architecture earns its boundaries

*Fowler: "Almost all the successful microservice stories have started with a monolith that got too big and was broken up."*
*Carmack: "The single most effective strategy for defect reduction is code reduction."*

Both argue against premature structural complexity. Fowler: "Don't even consider microservices unless you have a system that's too complex to manage as a monolith." Carmack: every abstraction boundary is more code, more state, more places for bugs.

### What to check

**Premature modularisation**
- Feature modules with one consumer and one implementation
- Abstraction layers (repositories, services, controllers) when the app has 10 tRPC procedures
- At 4k users with a Next.js/tRPC monolith: you probably don't need a "service layer" — your tRPC procedures ARE the service layer. Prisma queries in procedures is fine.
- Severity: **P3** unless the indirection is actively causing confusion (**P2**)

**Missing boundaries where they matter**
- Fowler's test: are different parts of the code changing for different reasons? If yes, they should be separated.
- Shared mutable state between features that should be independent
- In Next.js: route groups (`(auth)`, `(dashboard)`) that share internal implementation details
- Severity: **P2** if causing divergent change

**Published interfaces that shouldn't be**
- Fowler: "Don't publish interfaces inside a team." Internal module APIs treated as stable contracts when they should be freely changeable.
- In a monorepo: exporting everything from index files when only 2 functions are used externally
- Severity: **P3**

### The Strangler Fig principle

For legacy code or migrations: wrap and replace incrementally, never big-bang rewrite. Fowler: "All we are doing is writing tomorrow's legacy software today" — so design for replaceability. In Next.js terms: if migrating from Pages Router to App Router, do it route by route, not all at once.

---

## Principle 7: The enabling triad — tests, CI, and refactoring are inseparable

*Fowler: "Only if you have testing, continuous integration, and refactoring can you practice simple design effectively."*
*Carmack: "The most important thing I have done as a programmer in recent years is to aggressively pursue static code analysis."*

Both want machine-verified correctness — different tools, same goal. Fowler uses tests to verify behavior. Carmack uses static analysis to verify structure. Use both.

### What to check

**Missing tests on changed code**
- Fowler: "We assume that any non-trivial code without tests is broken."
- A refactoring PR without passing tests is restructuring, not refactoring — review it with different (higher) scrutiny
- New business logic without tests: the reviewer cannot verify correctness
- Severity: **P2** for changed code without test coverage, **P1** for critical paths

**Tests coupled to implementation**
- Tests that break when you refactor without changing behavior — these actively discourage refactoring
- Fowler (via Kent Beck): those who use heavy mocking "often find refactoring difficult"
- Tests asserting on internal function calls rather than observable outcomes
- Severity: **P2** — these erode the enabling triad

**TypeScript strictness as static analysis**
- Carmack's static analysis principle applied to the stack you have
- `strict: false`, liberal `any` usage, `@ts-ignore` comments — each one is a blind spot where the analyzer gives up
- Severity: **P2** for `strict: false`, **P3** for scattered `any`

**Test sufficiency (Fowler's two-part test)**
- "You rarely get bugs that escape into production" — are the same classes of bugs recurring?
- "You are rarely hesitant to change some code for fear it will cause production bugs" — is the team afraid to touch certain areas?
- If either answer is no, the test suite is insufficient regardless of coverage numbers.
- Coverage in the upper 80s-90s is expected. Fowler: "I would be suspicious of anything like 100% — it would smell of someone writing tests to make the coverage numbers happy."
- Severity: **P2** for fear-zones, **P3** for low coverage in stable code

---

## Principle 8: Refactoring is not restructuring — review them differently

*Fowler: "If somebody talks about a system being broken for a couple of days while they are refactoring, you can be pretty sure they are not refactoring."*

### The Two Hats rule

Fowler (via Kent Beck): when adding function, don't change existing code. When refactoring, don't add function. "You can only wear one hat at a time." A PR should ideally not blend refactoring with behavioral changes — the reviewer cannot verify correctness of either when they're interleaved.

### What to check in "refactoring" PRs

- Does the PR change observable behavior? If yes, it's not a refactoring — that's fine, but call it what it is.
- Is the system broken for more than a few minutes at each step? If yes, the steps are too large.
- Are the tests passing at each commit? Refactoring should never break the build.
- Severity: **P2** for PRs labeled "refactoring" that change behavior without test updates

### Against refactoring sprints

Fowler: "In almost all cases, I'm opposed to setting aside time for refactoring." If the team needs a dedicated refactoring sprint, the codebase has already degraded. The reviewer should notice this pattern at a meta-level and flag it as a process issue.

---

## Quick Reference: Severity Guide

| Severity | Pattern | Examples |
|----------|---------|----------|
| **P1 — Fix Now** | Structural issue causing correctness bugs | Cross-request state in Next.js module scope, critical paths without tests |
| **P2 — Fix Soon** | Structure actively slowing the team down | Shotgun surgery, hidden mutations, feature envy, speculative complexity, tests coupled to implementation, "refactoring" PRs that change behavior |
| **P3 — Consider** | Hygiene that compounds over time | Vague names, data clumps, minor duplication, premature abstraction, low-value extraction |

## The Overriding Filter

Before writing any finding, apply Fowler's economic test: **"Will this code slow us down?"** If the answer is "not really" or "not yet," either lower the severity or don't flag it. Carmack would add: **"Is this code hiding state that will surprise someone?"** If neither applies, move on. A focused review with 6 sharp findings beats a wall of 20 nitpicks.
