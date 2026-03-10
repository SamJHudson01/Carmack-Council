# Boundary Examples — Three-Tier System

The three-tier boundary system (from Addy Osmani / GitHub's agent configuration research) tells the implementing agent what to do without asking, what to pause on, and what to never touch. Boundaries prevent the most common agent failure modes: silent scope creep, breaking changes to shared code, and skipping verification.

**The key design principle: boundaries should prevent *likely* mistakes, not obvious ones.** "Never delete the production database" is useless — no agent would do that. "Never modify the shared auth context without flagging it for review" is useful — an agent might reasonably think it needs to change auth to implement a feature.

---

## How to write good boundaries

### ✅ Always (agent does without asking)

These are quality gates and conventions. The agent should execute these automatically on every implementation task.

**Good Always items share three traits:**
1. They're mechanical — no judgment call required
2. They're verifiable — you can check whether they happened
3. They apply to every change, not just this feature

**Bad Always items** are vague ("always write clean code") or feature-specific ("always use the new Button component"). Feature-specific conventions belong in the spec body or the project's steering files, not in boundaries.

### ⚠️ Ask First (agent pauses for human approval)

These are decisions with blast radius — changes that affect other features, other developers, or the production environment.

**Good Ask First items share three traits:**
1. They're reversible but expensive to reverse
2. They affect code or systems beyond the current feature
3. A reasonable agent might attempt them without realising the risk

### 🚫 Never (hard stops, no exceptions)

These are guardrails for known failure modes. The agent must not do these even if they seem helpful.

**Good Never items share three traits:**
1. They're things an agent might plausibly attempt
2. The consequences of doing them are severe or irreversible
3. They're specific enough to be unambiguous

---

## Domain-Specific Examples

### Web Application (full-stack)

```
### ✅ Always
- Run the existing test suite after every set of changes
- Follow existing file naming conventions and directory structure
- Use the project's established error handling pattern
- Validate all user inputs at the API boundary
- Include type annotations for all function parameters and return values

### ⚠️ Ask first
- Database schema changes (migrations affect all environments)
- Adding new external dependencies
- Modifying shared middleware or interceptors
- Changing environment variable requirements
- Creating new API endpoints (affects API surface area)

### 🚫 Never
- Modify authentication or authorisation middleware
- Delete or skip existing tests to make new code pass
- Hard-code secrets, API keys, or credentials
- Modify files outside the feature's scope without explicit approval
- Bypass input validation for convenience
- Change the public API contract of existing endpoints
```

### API / Backend Service

```
### ✅ Always
- All new endpoints must have input validation via schema (Zod, Joi, JSON Schema, etc.)
- All mutations must check authentication and authorisation
- Log errors with enough context for debugging (request ID, user ID, operation)
- Return consistent error response format across all endpoints

### ⚠️ Ask first
- Adding new database tables or columns
- Changing existing API response shapes (breaking change risk)
- Adding background jobs or async processing
- Integrating with new external services
- Changing rate limiting configuration

### 🚫 Never
- Return stack traces or internal error details in production responses
- Store raw user passwords (hashing is a minimum, not a boundary — it's obvious)
- Execute raw SQL with string interpolation from user input
- Modify shared database connection or ORM configuration
- Bypass rate limiting for any endpoint
```

### Frontend / UI

```
### ✅ Always
- Components must render correctly at mobile (320px), tablet (768px), and desktop (1280px)
- All interactive elements must be keyboard-accessible
- Loading states must be shown for any operation that takes more than 200ms
- Form validation must show inline errors, not just alerts

### ⚠️ Ask first
- Adding new global state (store, context, or equivalent)
- Changing the routing structure
- Adding new third-party UI libraries
- Modifying shared layout or navigation components

### 🚫 Never
- Use inline styles for anything except dynamic values
- Disable or override the project's CSS methodology
- Store sensitive data in browser storage (localStorage, sessionStorage)
- Make API calls directly from UI components (use the established data layer)
- Remove or modify existing accessibility attributes
```

### Data Pipeline / ETL

```
### ✅ Always
- Every pipeline step must be idempotent (safe to re-run)
- Include row counts before and after every transformation step
- Log the source, timestamp, and record count for every data pull
- Validate schema of incoming data before processing

### ⚠️ Ask first
- Changing the schema of output tables
- Modifying data retention policies
- Adding new data sources or integrations
- Changing pipeline scheduling or frequency

### 🚫 Never
- Delete source data during transformation
- Run destructive operations without a dry-run mode
- Skip schema validation to "just get it working"
- Hard-code connection strings or credentials
```

### Mobile App

```
### ✅ Always
- Test on both iOS and Android before marking complete
- Respect the platform's accessibility guidelines (VoiceOver / TalkBack)
- Handle offline state gracefully — never show a blank screen
- Include loading and error states for all async operations

### ⚠️ Ask first
- Adding new app permissions (camera, location, notifications)
- Changing navigation structure
- Adding new background processes
- Modifying data sync / caching strategy

### 🚫 Never
- Store tokens or secrets in plain text on device
- Block the main thread with synchronous operations
- Bypass platform security controls (certificate pinning, etc.)
- Hard-code environment-specific values (use config)
```

---

## Customising Boundaries for Your Project

The examples above are starting points. When writing boundaries for a specific spec:

1. **Start with the project's steering files.** If the project has a `CLAUDE.md`, `constitution.md`, or conventions doc, its rules take precedence. Don't duplicate them in the spec — reference them.
2. **Add feature-specific boundaries.** What could go wrong with THIS specific feature? If you're building a payment flow, "Never store raw card numbers" is more useful than a generic "be secure."
3. **Keep the total count manageable.** 3–5 items per tier is the sweet spot. More than 7 in any tier means you're either over-constraining or the feature scope is too broad.
4. **Test each Never item with the "would an agent actually do this?" question.** If the answer is "no reasonable agent would try that," cut it. Boundaries are for preventing plausible mistakes, not hypothetical ones.