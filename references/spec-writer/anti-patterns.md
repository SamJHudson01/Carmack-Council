# Spec Anti-Patterns

Every anti-pattern here has caused real project failures. Use this as a checklist during Phase 4 self-review, or when the user's initial description triggers red flags. Each anti-pattern includes what it looks like, why it fails, and how to fix it.

---

## Anti-Pattern 1: The Vague Quality Attribute

**What it looks like:**
"The system should be fast, secure, and user-friendly."

**Why it fails:**
These words mean nothing without numbers. "Fast" to a real-time trading platform means sub-millisecond. "Fast" to a content management system means under 3 seconds. An AI agent given "make it fast" will optimise whatever it feels like, or more likely, ignore the instruction entirely. Research on LLM instruction-following confirms: vague instructions get vague compliance.

**Fix:** Replace every quality attribute with a measurable criterion.

| Vague | Specific |
|-------|---------|
| Fast | Page interactive within 2s on 4G; API responses under 200ms p95 |
| Secure | All mutations require authenticated session; input validated at API boundary |
| Scalable | Handles 1,000 concurrent users with no degradation |
| User-friendly | New user completes core task within 3 minutes without documentation |
| Reliable | 99.9% uptime; automatic retry on transient failures |
| Robust | Recovers from database connection loss within 30 seconds |

---

## Anti-Pattern 2: The Implementation Leak

**What it looks like:**
"Use a Redis cache with 5-minute TTL for session storage."
"Implement a React useEffect hook to fetch the data on mount."
"Create a PostgreSQL materialized view for the dashboard query."

**Why it fails:**
This turns the spec into design, creating two problems. First, the developer or agent must now review both the spec AND the implementation for correctness — double the work. Second, if the spec prescribes the wrong implementation, it actively prevents the builder from choosing a better approach. Marmelab's core critique of SDD: specs that contain code create "double code review."

**Fix:** Describe the behaviour, not the mechanism.
- ❌ "Use Redis with 5-minute TTL" → ✅ "Session data available within 50ms; sessions expire after 30 minutes of inactivity"
- ❌ "useEffect on mount" → ✅ "Data loads when the user opens the page, with a loading indicator until ready"
- ❌ "PostgreSQL materialized view" → ✅ "Dashboard loads within 1 second even with 100k records"

**Exception:** Technology names are appropriate when they're genuine constraints, not design choices. "Must integrate with Stripe's PaymentIntent API" is a constraint. "Must use React" is a constraint if the codebase is React. "Use a useEffect" is a design choice.

---

## Anti-Pattern 3: The Sledgehammer Spec

**What it looks like:**
A 200-word bug fix described with 4 user stories, 16 acceptance criteria, a full boundary system, success metrics, and a decomposition plan. Amazon Kiro's most-cited failure mode.

**Why it fails:**
Over-specifying trivial changes wastes time, confuses the agent (more instructions = lower compliance per instruction), and teaches the team to ignore specs. If every change requires a ceremony, people skip the ceremony.

**Fix:** Match the spec tier to the complexity. A bug fix needs: problem, current behaviour, expected behaviour, 2–3 ACs, one boundary. That's it. The Spec Writer skill's Phase 0 exists to prevent this.

---

## Anti-Pattern 4: The Stale Spec

**What it looks like:**
A spec written three weeks ago that references an API endpoint that's been renamed, a database column that's been split into two, and a feature that was descoped. But it's still in the repo as `SPEC.md`, and the agent just picked it up as context.

**Why it fails:**
AI agents using outdated specs build against outdated requirements with full confidence. They don't question the spec — that's the whole point of specs. A stale spec is worse than no spec, because no spec at least forces the agent to ask questions.

**Fix:**
- Date every spec. The date is the first signal of staleness.
- Use a Status field: Draft / Confirmed / In Progress / Done. A "Done" spec is archived context, not active instruction.
- If specs live alongside code, update them when the code changes. If that's too much overhead, move the spec to an `archive/` folder when implementation begins and let the code + tests become the source of truth.
- Never hard-code volatile details (API versions, endpoint paths, external service URLs). Reference them: "See current API docs at [link]."

---

## Anti-Pattern 5: The Missing Negative Case

**What it looks like:**
Five acceptance criteria, all describing the happy path. Login works. Search returns results. Payment succeeds. Save persists data. Export generates a file.

**Why it fails:**
The agent builds something that works perfectly — as long as nothing goes wrong. First invalid input, first network timeout, first permission error: the system fails in an unspecified way. The agent didn't handle these cases because the spec didn't mention them. 50–56% of software defects originate in requirements (IBM Research). Most of those are omissions, not errors.

**Fix:** Every story gets at least one negative AC. Categories: invalid input, permission denied, empty state, external service failure, boundary values. See the Acceptance Criteria Guide for the full checklist.

---

## Anti-Pattern 6: The Solution Masquerading as Problem

**What it looks like:**
"We need a dashboard with three charts showing revenue, users, and conversion rate, with date filters and CSV export."

**Why it fails:**
This describes a solution, not a problem. The spec writer generates exactly this — but the real problem might be "leadership needs to know whether the Q4 campaign is working." A dashboard might be the answer, or it might be a weekly email summary, or an alert when metrics cross a threshold.

**Fix:** Push back. "What decision does this help someone make?" "What question does this answer?" "What happens today without this?" Get to the problem first, then write a spec for a solution to that problem. The spec might end up being a dashboard — but it might not.

---

## Anti-Pattern 7: Scope Creep via "And Also"

**What it looks like:**
User describes Feature A. During spec writing, they mention "and also, it should handle B." Then "oh, and we'll need C for this to really work." By the end, the spec covers three features in one document.

**Why it fails:**
Multi-feature specs violate the "shortest document" principle. The agent tries to build everything at once, context overflows, and the result is a mess of partially-implemented features. The "curse of instructions" research confirms: more instructions = less compliance per instruction.

**Fix:** When the user says "and also," stop and ask: "Is that part of this feature, or a separate one? If separate, I'll note it as a future consideration and we can spec it next." One spec, one feature. Product-tier specs can define multiple features, but each gets its own story group and decomposition phase.

---

## Anti-Pattern 8: The SODS (Software Over-specification Death Spiral)

**What it looks like:**
PM writes spec → engineer gets things wrong → both agree "requirements need more detail" → PM writes exhaustive spec → takes longer, goes stale faster, engineer feels micromanaged → things still go wrong → cycle repeats with even more detail → paralysis.

**Why it fails:**
More detail doesn't fix ambiguity — it compounds it. A 5,000-word spec with 50 acceptance criteria is harder to comply with than a 500-word spec with 10 ACs, because the reader (human or agent) can't hold all 50 in working memory simultaneously. The solution to "the spec wasn't clear enough" is almost never "make the spec longer." It's "make the spec more specific on the things that actually matter."

**Fix:** When tempted to add detail, ask: "Is this information necessary for someone to build the right thing? Or is it defensive documentation against a past mistake?" Cut the defensive parts. Address past mistakes in conventions docs or steering files, not in feature specs.

---

## Anti-Pattern 9: The Context-Blind Spec

**What it looks like:**
A spec that ignores the existing codebase. It describes auth handling when the project already has an auth system. It specifies error response formats when the project has a standard. It defines API patterns that conflict with existing conventions.

**Why it fails:**
The agent builds something that works in isolation but conflicts with everything around it. Then someone has to refactor the new code to match existing patterns — or worse, the new code introduces a second pattern that coexists with the first, creating permanent inconsistency.

**Fix:** Phase 1 (Gather Context) exists specifically to prevent this. Before writing a spec, understand what's already there. The spec should reference existing patterns: "Follow the existing error handling pattern in `lib/errors.ts`." If no codebase exists yet, this anti-pattern doesn't apply.

---

## Red Flags in User Descriptions

When the user describes what they want, watch for these indicators of anti-patterns:

| User says | Red flag | Clarifying question |
|-----------|----------|-------------------|
| "Make it user-friendly" | Vague quality attribute (#1) | "What specific task should a user complete easily? In how long?" |
| "Use [specific technology]" | Implementation leak (#2) | "Is that a project constraint, or a preference? The spec should describe behaviour." |
| "I need a full spec for this bug fix" | Sledgehammer (#3) | "This sounds small. Want a focused bug spec instead of a full feature spec?" |
| "Here's the spec from last month" | Stale spec risk (#4) | "Has anything changed since this was written? Let me verify against the current codebase." |
| "It should just work" | Missing negative cases (#5) | "What should happen when it doesn't work? Network failure? Invalid input?" |
| "I need a [solution]" without problem | Solution as problem (#6) | "What problem does this solve? What decision does it help make?" |
| "And also it should..." (3+ times) | Scope creep (#7) | "That sounds like a separate feature. Want me to note it for a follow-up spec?" |
| "We need to be more detailed" | SODS risk (#8) | "What specifically was unclear last time? Let's sharpen those parts rather than expanding everything." |