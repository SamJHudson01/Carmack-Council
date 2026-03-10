# Template: Feature Spec

Use this template for new capabilities with defined scope — the most common spec tier. Multiple moving parts, but bounded. Target: ~500–800 words. If it grows past 1,000 words, either the scope is too broad (split into multiple specs) or you're leaking implementation details (cut them).

---

## Output Format

```markdown
# Spec: [feature name]

**Date:** [YYYY-MM-DD]
**Status:** Draft | Confirmed | In Progress | Done

## Objective

[2–3 sentences. What we're building and why. Business context. User need. This is the "elevator pitch" — if someone reads only this paragraph, they should understand the purpose.]

## Context

[Brief technical context. What exists today that this feature interacts with. What the user currently does to work around not having this feature. Stack and relevant dependencies ONLY if they constrain the spec. Do not list the full stack — only what matters for this feature.]

## Scope

### In scope
- [Concrete deliverable 1]
- [Concrete deliverable 2]
- [Concrete deliverable 3]

### Out of scope
- [Thing that might seem related but is explicitly excluded]
- [Future enhancement that is NOT part of this spec]

### Non-goals
- [Thing this feature deliberately does NOT optimise for]

## Stories

### Story 1: [situation summary]

**When** [situation/trigger], **I want to** [action/capability], **so I can** [outcome/benefit].

**Acceptance Criteria:**

Given [precondition]
When [single trigger]
Then [expected outcome]

Given [precondition]
When [single trigger]
Then [expected outcome]

Given [error/edge condition]
When [trigger that should fail gracefully]
Then [expected error handling or fallback]

### Story 2: [situation summary]

**When** [situation/trigger], **I want to** [action/capability], **so I can** [outcome/benefit].

**Acceptance Criteria:**

Given [precondition]
When [single trigger]
Then [expected outcome]

Given [error/edge condition]
When [trigger that should fail gracefully]
Then [expected error handling or fallback]

[Add stories as needed — typically 2–5 for a feature]

## Boundaries

### ✅ Always
- [Action the implementing agent takes without asking — e.g., "Run the existing test suite after changes"]
- [Convention to follow — e.g., "Follow existing naming patterns in the codebase"]
- [Quality gate — e.g., "All new logic must have corresponding acceptance tests"]

### ⚠️ Ask first
- [Decision requiring human approval — e.g., "Database schema changes"]
- [Risky action — e.g., "Adding new external dependencies"]

### 🚫 Never
- [Hard stop — e.g., "Modify authentication middleware"]
- [Forbidden action — e.g., "Delete or skip existing tests"]
- [Safety rail — e.g., "Expose internal IDs in client-facing URLs"]

## Success Metrics

- [How do we know this worked? Quantified where possible.]
- [E.g., "Task completion time drops from ~3 minutes to under 30 seconds"]
- [E.g., "Zero 500 errors on the new endpoint in the first week"]

## Assumptions

- [Any assumption made during spec writing that hasn't been confirmed]
- [Mark each: (confirmed) or (unconfirmed)]

---

*After implementing, compare results against each acceptance criterion above and list any unmet requirements.*
```

---

## Rules for Feature Specs

1. **2–5 Job Stories.** Fewer than 2 means you're under-speccing. More than 5 means the feature is probably an epic — split it.
2. **3–7 ACs per story.** Fewer than 3 means you're missing edge cases. More than 7 means you're over-specifying or the story is too broad — split the story.
3. **At least one negative AC per story.** Non-negotiable. Error state, permission denial, invalid input, empty state — pick the most likely failure mode.
4. **Boundaries section must contain likely mistakes, not obvious ones.** "Never delete the production database" is useless — no agent would do that unprompted. "Never modify the shared authentication context" is useful — an agent might reasonably think it needs to.
5. **Success metrics must be measurable.** "Improved user experience" is not a metric. "Task completion rate above 90% in usability testing" is. If you can't measure it, it's not a success metric — it's a wish.
6. **The Objective must stand alone.** Someone reading only the Objective should understand what the feature does and why it matters. If it requires reading the full spec to make sense, rewrite it.
7. **Context is about constraints, not architecture.** Don't describe the full system architecture. Describe only the parts that constrain THIS feature. "The app uses JWT auth with 15-minute token expiry" is relevant context if the feature touches auth. The database schema is not relevant context unless the feature needs new tables.
8. **Scope boundaries are fences, not descriptions.** "In scope: user authentication" is too vague. "In scope: add email/password login to existing OAuth-only flow" is a fence.