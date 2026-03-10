# Template: Small Change Spec

Use this template for bug fixes, config changes, copy updates, and simple additions to existing features. One clear thing to do. Target: ~200 words. If the spec grows past 300 words, it's probably a feature — escalate.

---

## Output Format

```markdown
# Spec: [short descriptive title]

**Type:** Bug fix | Config change | Copy update | Simple addition
**Date:** [YYYY-MM-DD]

## Problem

[2–3 sentences. What's broken or missing. Be specific — "the save button doesn't work" is vague. "Clicking Save on the profile page returns a 500 error when the bio field contains emoji" is a spec.]

## Current behaviour

[1–2 sentences. What happens now. Include error messages, status codes, or observable symptoms if relevant.]

## Expected behaviour

[1–2 sentences. What should happen after the fix.]

## Acceptance Criteria

Given [precondition]
When [single trigger action]
Then [expected outcome]

Given [precondition — error/edge case]
When [trigger that should fail gracefully]
Then [expected error handling]

## Boundaries

- 🚫 Never: [most relevant constraint — e.g., "Do not modify the database schema", "Do not change the public API contract"]

## Affected area

[Which file(s) or module(s) this touches. Be specific enough to scope the change.]

---

*After implementing, compare results against each acceptance criterion above and list any unmet requirements.*
```

---

## Rules for Small Change Specs

1. **No user stories.** The problem statement IS the story. Adding "As a user, I want the bug to be fixed" is noise.
2. **Exactly 2–4 acceptance criteria.** One for the fix, one for the error/edge case, optionally one or two for regression protection.
3. **One boundary maximum.** The single most important constraint. Don't dress up a bug fix with a full boundary system.
4. **Name the affected area.** The implementing agent needs to know where to look. File paths, module names, route names — whatever narrows the search.
5. **Current vs Expected is mandatory.** This pair eliminates ambiguity faster than any other technique. "It does X, it should do Y" is the clearest possible bug spec.