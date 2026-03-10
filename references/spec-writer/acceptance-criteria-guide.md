# Acceptance Criteria Guide

Every acceptance criterion must be independently testable — a developer or agent can write a test that passes or fails on exactly this criterion. If it can't be tested, it's not an acceptance criterion — it's a wish.

---

## The Gherkin Format

```
Given [precondition — the state of the world before the action]
When [single trigger — exactly ONE action or event]
Then [observable outcome — what the user sees, what the system does]
```

This maps directly to the **Arrange-Act-Assert** test pattern. Given = arrange, When = act, Then = assert. Every AC you write can become a test with no interpretation required.

### The single-trigger rule

**The When clause must contain exactly one trigger.** This is the most commonly violated Gherkin rule. Mixing multiple actions in When makes it impossible to know which action caused the outcome.

```
# BAD — two triggers, which one are we testing?
Given a logged-in user on the settings page
When the user changes their email and clicks Save
Then the email is updated

# GOOD — one trigger per scenario
Given a logged-in user on the settings page who has entered a new email
When the user confirms the change
Then the email is updated and a confirmation is sent to the new address

# GOOD — separate scenario for the input step if it has its own behaviour
Given a logged-in user on the settings page
When the user enters an email that's already registered
Then they see a validation error before they can submit
```

### Declarative, not imperative

Describe **behaviour**, not **UI interactions**. The test should survive a redesign. If you'd need to rewrite the AC when the implementation changes, it's too specific.

```
# BAD — imperative, describes clicks
Given I am on the login page
When I type "user@test.com" in the email field and click the Submit button
Then I see the dashboard

# GOOD — declarative, describes behaviour
Given a registered user with valid credentials
When the user logs in
Then they see their dashboard with their most recent activity
```

---

## The Negative AC Mandate

Every story must have at least one acceptance criterion that covers a failure mode. This is non-negotiable. The most common spec failure is testing only the happy path — then the agent builds something that works perfectly until anyone does anything unexpected.

### Categories of negative ACs (pick at least one per story):

**Invalid input**
```
Given a user submitting the registration form
When they enter an email without an @ symbol
Then they see a validation error and the form is not submitted
```

**Permission boundary**
```
Given a user who is not the workspace owner
When they attempt to delete the workspace
Then the action is denied and they see an explanation of required permissions
```

**Empty/null state**
```
Given a new user with no projects
When they open the dashboard
Then they see an empty state with a clear call-to-action to create their first project
```

**Error condition**
```
Given the external payment API is unavailable
When a user attempts to complete a purchase
Then they see a clear error message and their cart is preserved for retry
```

**Boundary value**
```
Given a user creating a project name
When they enter exactly 256 characters (the maximum)
Then the name is accepted and saved correctly
```

**Concurrency / race condition**
```
Given two users editing the same document simultaneously
When both save at the same moment
Then both changes are preserved and neither user loses work
```

---

## Edge Case Identification Checklist

When writing ACs, systematically consider each category below. You don't need to write ACs for all of them — just the ones that are **likely and impactful** for the specific feature.

| Category | What to consider |
|----------|-----------------|
| **Boundary values** | Min, max, zero, negative, one-off-boundary, empty string, max length |
| **Empty/null states** | First-time user, no data yet, deleted data, cleared data |
| **Error conditions** | Network failure, timeout, external service down, rate limit hit |
| **Permission boundaries** | Wrong role, expired session, revoked access mid-flow |
| **Concurrency** | Two users doing the same thing, duplicate submissions, stale data |
| **Time-related** | Timezone differences, DST transitions, leap years, midnight edge, expired TTL |
| **Resource limits** | File too large, too many items, memory pressure, pagination edge |
| **Data format** | Unicode, emoji, RTL text, special characters, SQL injection attempts, XSS payloads |
| **State transitions** | What happens mid-flow? Can the user go back? What if they close the browser? |

### Prioritisation: impact × likelihood

Not every edge case deserves an AC. Use this mental model:

- **High impact + high likelihood** → Mandatory AC (e.g., invalid email on registration)
- **High impact + low likelihood** → AC if cheap to specify (e.g., payment API timeout)
- **Low impact + high likelihood** → AC if it affects UX (e.g., empty search results)
- **Low impact + low likelihood** → Skip (e.g., user pastes 10MB of text into a name field). Marmelab's "imaginary corner cases" live here. Don't write ACs for things that will never happen in practice.

---

## Common AC Mistakes

### 1. Too vague — not testable

```
# BAD
Then the page loads quickly

# GOOD
Then the page is interactive within 2 seconds on a 4G connection
```

The test: can you write an automated check for this? "Quickly" can't be asserted. "Within 2 seconds" can.

### 2. Too implementation-specific

```
# BAD
Then the Redis cache stores the session with a 30-minute TTL

# GOOD
Then the user's session remains active for 30 minutes of inactivity
```

The first one describes mechanism. The second describes behaviour. If you swap Redis for Memcached, the second AC still holds. The first one needs rewriting.

### 3. Ambiguous language

These words are banned from acceptance criteria. Every one has caused real spec failures:

| Banned word | Why | Replace with |
|-------------|-----|-------------|
| **User-friendly** | Means nothing. Every designer and every developer has a different definition. | Specific UX criterion: "completes in under 3 clicks" |
| **Intuitive** | If you have to specify it, it's not intuitive. | Task completion metric: "without documentation" |
| **Efficient** | Compared to what? | Quantified: "under 200ms p95" or "3x faster than current flow" |
| **Responsive** | Means either speed or screen adaptation — ambiguous. | "Renders correctly from 320px to 1920px" or "responds within 100ms" |
| **Secure** | Meaningless without specifics. | Concrete: "requires authenticated session" or "encrypts at rest" |
| **Seamless** | Marketing language, not engineering language. | Specific: "no page reloads during the flow" |
| **Appropriate** | Appropriate to whom? | Specify the exact behaviour. |
| **Robust** | Everything should be robust — saying it adds no information. | "Recovers from [specific failure] within [specific time]" |

### 4. Multiple When triggers

Already covered above. One trigger per AC. If you need to test a sequence, the earlier steps become Given clauses.

### 5. Missing the negative case

Already covered above. At least one negative AC per story.

### 6. Solution masquerading as requirement

```
# BAD — this is telling the agent HOW to build it
Given a user viewing the product list
When they scroll to the bottom
Then a React InfiniteScroll component loads the next 20 items via the /api/products endpoint

# GOOD — this is describing WHAT should happen
Given a user viewing a product list with more items than fit on screen
When they reach the end of the visible items
Then more items load automatically without a full page reload
```

---

## AC Count Guidelines

| Spec tier | ACs per story | Total ACs |
|-----------|--------------|-----------|
| Small change | 2–4 total (no stories) | 2–4 |
| Feature | 3–7 per story | 10–25 total |
| Product | 3–5 per story (keep lean — feature specs will expand) | 15–40 total |

If you're writing more than 7 ACs for a single story, the story is too broad. Split it.