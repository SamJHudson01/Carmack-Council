# UX Quality Reference — Carmack × Friedman

Philosophy: John Carmack. Specifics: Vitaly Friedman (Smashing Magazine, Smart Interface Design Patterns, Design Patterns for AI Interfaces).
Stack context: Next.js App Router / React / TypeScript / tRPC / Prisma / Neon (serverless Postgres) / Clerk (auth) / CSS Modules + BEM. Mantine component library. Linear-inspired dark theme. Inter + JetBrains Mono fonts. B2B SaaS — data-dense analytical product.

Every finding must describe the **concrete UX consequence** — not just "this could be better."
When Carmack and Friedman independently converge on a principle, it earns its place here.

**Scope boundary:** This doc covers UX patterns, information architecture, and interaction design. It does NOT cover: accessibility/a11y (separate domain — WCAG compliance is assumed, not audited here), visual design aesthetics, brand, color theory, security, performance, or backend concerns. Where accessibility intersects UX patterns (touch targets, keyboard alternatives), it's noted but not deeply audited.

---

## Principle 1: Structure complexity — don't destroy user value by simplifying it away

*Carmack: "The best code is no code. The second best is simple code." But Carmack never advocates removing necessary complexity — he advocates structuring it so its behavior is obvious.*
*Friedman: "Don't destroy user value by oversimplification." And: "'Efficient' is not always simple and 'simple' is not always efficient." His overarching thesis across 15+ years: "Complex UIs don't have to be complicated."*

Both converge on the same distinction: unnecessary complexity must be eliminated, but necessary complexity must be structured, not hidden. In a data-dense B2B product, users rely on access to specific details and raw data. Stripping that away to make the interface "clean" actively harms the people who need the tool to do their work. The job is to make complex information navigable, not to pretend it's simple.

### What to check

**Oversimplified views that hide actionable data**
- Are analytical outputs (scores, evidence, metadata) hidden behind clicks when users need them to make decisions? If the user's primary task requires comparing items across multiple dimensions, those dimensions should be visible — not buried in detail drawers.
- Does the interface assume users want a summary when they actually need specifics? Friedman: "Life is complex, and the tools we design must match the complexities of the real world."
- Severity: **P1** if the user cannot complete their core task (comparing, deciding, acting) without navigating away from the primary view. **P2** if secondary details require excessive clicks to access.

**No density controls**
- For data-heavy views (hypothesis lists, experiment results, pipeline output), does the interface offer density modes? Friedman teaches three levels: low (large text, extra spacing, progressive disclosure), medium (regular size, more data cards, shortcuts), high (small text, heavy data, customization, filters). A single density forces expert users into an interface designed for beginners — or vice versa.
- Severity: **P3** for missing density controls in early product stages. **P2** once expert users are onboarded and working daily.

**Feature parity destroyed on mobile**
- Friedman's position: mobile versions of data-dense interfaces should be fundamentally different experiences, not shrunken desktop layouts. "What users expect is that features they heavily rely on for their work exist in all environments — but these features don't have to work or look exactly the same." A table that simply scrolls horizontally on mobile is a failure — consider cards, tabs + accordions, or stacked columns.
- Severity: **P2** for data tables that are unusable on mobile. **P3** if mobile is not a primary use case for the product's current stage.

---

## Principle 2: Design all five screen states — blank, loading, partial, error, ideal

*Carmack: "If a mistake is possible, it will eventually happen."*
*Friedman credits Scott Hurff's UI Stack: "Every screen you interact with has multiple personalities: blank state, loading state, partial state, error state and ideal state." His practice: "I often start exploring errors and recovery flows early because they often leave users frustrated and disappointed."*

Both converge on designing for failure as a first-class concern, not an afterthought. Carmack designs code to handle every error path. Friedman designs interfaces to handle every screen state. A component that only looks right with ideal data is incomplete — it will encounter empty data, slow loading, partial failure, and full failure in production. Each state needs deliberate design.

### What to check

**Missing blank/empty states**
- What does the user see before they have data? A blank page with no guidance is abandonment risk. Friedman: "Design sets of filters, templates and empty states." "Blank slates + segmentation in tandem seem to be working best." Empty states should contain: what this view will show, why it's empty, and what action creates the first data.
- Severity: **P1** for primary views (dashboard, results list) with no empty state. **P2** for secondary views.

**Full-page loading takeover**
- Friedman: "We need to avoid an entire page takeover, but rather lazy load content panes or use inline loading." For slow operations (analysis pipelines, LLM processing), the loading state must communicate progress without locking the user out. Skeleton screens are preferred over spinners for layout-predictable content. For operations that take 30+ seconds, show progress stages — not a single indeterminate spinner.
- Severity: **P1** for operations over 10 seconds with no progress indication. **P2** for full-page spinners that prevent any other interaction.

**No partial state handling**
- What happens when some data loads but some fails? If one API call in a dashboard fails, does the entire view break or does the failing section show an error while the rest remains functional? Friedman: "When the page is sparsely populated, our job is to prevent people from getting discouraged and giving up on our product."
- Severity: **P1** if a single failing component crashes the entire view. **P2** for missing individual error boundaries on independent data sections.

**Generic error messages**
- Friedman: "Avoid generic error messages: they are often main blockers." An error message must answer: what went wrong, is it the user's fault or the system's, and what can they do about it. "Something went wrong" with no action path is a UX dead end.
- Severity: **P2** for generic error messages on critical user paths. **P3** for secondary flows.

---

## Principle 3: Never freeze the interface on a single input

*Carmack: "State is the enemy. Mutable shared state is the root of most bugs." Applied to UI: state transitions that lock the interface create cascading user frustration.*
*Friedman: "Every time we freeze the UI on a single input, we actively slow down our customers in expressing their intent." His strongest filter-design principle.*

Both converge on keeping systems responsive. Carmack minimizes blocking state in code. Friedman minimizes blocking state in interfaces. When a user adjusts a filter, selects an option, or changes a configuration, the interface must remain interactive while the result updates. Locking the UI forces users into a serial workflow — one input, wait, one input, wait — when their intent is to express a compound preference quickly.

### What to check

**Filters that lock during update**
- When users apply a filter, does the filter panel remain interactive while results update? Friedman's pattern: "On every filter input, matching results could be updated asynchronously, while the filters always remain accessible and at the same place." The anti-pattern: filters that gray out or become unclickable while results load. Coolblue.nl gets this right — results gray out, filters stay interactive.
- Severity: **P1** if users must wait for each filter to resolve before applying the next. **P2** if filters remain accessible but the entire page layout shifts on update.

**Auto-scroll on input**
- Does the page jump or scroll the user to a different position after they make a selection? Friedman documents Dell's configurator anti-pattern: "even if you'd like to specify just 6–10 features this way, you'll need to embark on a quite stubborn scrolling fight against the auto-scroll." Users lose their place and must re-orient after every interaction.
- Severity: **P2** for any interaction that moves the user's scroll position without their request.

**No optimistic UI for known-safe actions**
- For actions where the outcome is predictable (toggling a setting, reordering a list, marking an item), does the UI update immediately or wait for the server round-trip? Friedman endorses "optimistic actions where we assume access by default and hence reduce the perceived speed." Carmack's corollary: if the action will succeed in 99.9% of cases, design for success and handle the rare failure as a rollback.
- Severity: **P3** — polish, but compounds across frequent interactions.

---

## Principle 4: Progressive disclosure needs visible triggers and hard limits

*Carmack: "The structure of the code should make the intended behavior obvious." Applied to interfaces: hidden information should be obviously hidden — users should know it exists before they reveal it.*
*Friedman: "The accordion is probably the most established workhorse in responsive design." But with constraints: visible triggers (44×44px minimum), chevron icons, entire bars clickable, and maximum three nesting levels.*

Both demand that structure communicates intent. Code should make its behavior obvious from its structure. Interfaces should make their information hierarchy obvious from their layout. Progressive disclosure fails when users don't know there's more to see, or when the nesting becomes so deep they lose orientation.

### What to check

**Hidden content with no visible trigger**
- Is important information hidden behind interactions with no visual indicator that it exists? Every progressive disclosure point needs a visible affordance — an expand icon, a "show more" link with a count, or a clearly labeled section header. Friedman: "If you encounter a problem of any kind — too many navigation options, too much content, too detailed a view — a good starting point would be to explore how you could utilize the good ol' accordion."
- Severity: **P1** if users miss critical information because nothing indicates it exists. **P2** for supplementary information with weak or absent disclosure triggers.

**Nesting deeper than three levels**
- Friedman's hard limit: "Adding nested accordions to reveal more than three sublevels of navigation at once usually could be a warning sign that something isn't quite right and that perhaps the navigation could be simplified." Each nesting level needs distinct typographic contrast. Beyond three levels, expert users manage but infrequent users get lost.
- Severity: **P2** for nesting beyond three levels without distinct visual differentiation per level. **P3** for deep nesting that only expert users encounter.

**Modals used for non-blocking content**
- Friedman's default: "By default, use a non-blocking dialog ('non-modal dialogs')." Modals should be reserved for deliberate friction — confirming destructive actions, verifying complex input. They should never be used for: error messages, feature announcements, onboarding tutorials, or informational content. Every modal must support: close button, ESC key, click-outside-to-close, and back-button-to-close.
- Severity: **P2** for modals used for non-blocking content. **P1** for modals with no escape route (missing ESC or click-outside support).

**Dual-function triggers**
- Friedman warns against overloading category titles that serve as both links and accordion triggers: "It seems to be a good idea to avoid overloading category titles with multiple functions." A navigation item that both navigates AND expands a submenu on the same click/tap forces users to guess which action will fire.
- Severity: **P2** for interactive elements with ambiguous dual functions.

---

## Principle 5: Disabled controls are a dead end — keep actions accessible

*Carmack: "Assertions catch assumption violations before they become exploitable." Runtime assertions tell the developer exactly what's wrong. Disabled buttons tell the user nothing.*
*Friedman: Disabled buttons are "a disastrous design pattern." He documents two failure modes: users who "sit and wait patiently" assuming the system is loading, and users who hit "a wall" and resort to guessing which input combination will unlock the button.*

Both converge on the same principle: when something is wrong, say what's wrong. Carmack's assertions fail loudly with specific messages. Friedman's accessible buttons fail loudly with specific validation errors. The alternative — disabling the control and leaving the user to guess — violates both philosophies. It's the UI equivalent of swallowing an exception silently.

### What to check

**Disabled submit/action buttons — only flag when genuinely confusing**
- Friedman's position (keep buttons always enabled, validate on click) is opinionated and not mainstream. **Do not flag disabled buttons as findings** when the required input is visually obvious from context — e.g., a single required selector directly above the submit button, an empty text field that clearly needs content. Disabled states are a reasonable UX pattern when the missing input is self-evident.
- **Do flag** disabled buttons when: the form has many fields and it's unclear which one is blocking, the disabled state has no tooltip or hint, or the button appears disabled due to a system issue rather than missing input.
- The one clear exception everyone agrees on: preventing double submissions on destructive/financial actions — where the button disables after the first click with a loading indicator. This is always correct.
- Severity: **P2** for disabled buttons on complex forms where the blocker isn't obvious. Not a finding for simple, contextually clear cases.

**Inline validation that blocks submission**
- Overly aggressive inline validation that fires before the user finishes typing creates friction. The "Reward Early, Punish Late" pattern is sound: validate immediately when correcting an error, wait when editing a valid field.
- Severity: **P2** for overly aggressive validation that fires mid-keystroke. Not a finding for standard on-blur or on-submit validation.

**No validation override path**
- Friedman's most distinctive form recommendation: always provide a way to override inline validation. In a B2B context: if the system flags a configuration value as unusual but the user knows their use case, there should be a "proceed anyway" path.
- Severity: **P3** — a maturity feature, but prevents edge-case abandonment.

---

## Principle 6: Dashboards must create understanding and drive action

*Carmack: "If you can't measure it, you can't improve it." Applied to dashboards: a dashboard that displays data without enabling action is decoration.*
*Friedman: "Dashboards shouldn't just display data gathered from multiple sources, but rather create an understanding of that data." And: "Dashboard value is measured by useful actions it prompts."*

Both converge on instrumentality — things exist to serve a purpose. Carmack measures code quality by whether it enables improvement. Friedman measures dashboard quality by whether it enables decisions. A dashboard full of charts that don't connect to actions is the UX equivalent of logging without alerting — data collected, nothing done.

### What to check

**Metrics without context or action**
- Does every metric on the dashboard connect to an action the user can take? A number alone ("87 items generated") is trivia. A number with context and action ("12 items ready for review — Review & Push") drives workflow. Friedman: "Always communicate one message per chart."
- Severity: **P2** for dashboard metrics with no clear action path. **P1** if the primary dashboard view shows data that doesn't connect to any workflow.

**No data drill-down**
- Can users move from summary to detail? Friedman teaches "data drill-downs" and "data explorers" as standard dashboard building blocks. A summary card showing "3 experiments completed" should link to the detail view. Every aggregated number should be explorable.
- Severity: **P2** for summary metrics that can't be expanded into their underlying data.

**Chart type mismatches**
- Friedman: "Avoid pie charts and donut charts when users compare." "We don't need to show all data, just the right amount of data." For comparison data (A/B test results, hypothesis rankings), bar charts and tables outperform circular charts. He recommends the FT Visual Vocabulary and From Data to Viz chart chooser for selection.
- Severity: **P3** for suboptimal chart type choices. **P2** if the chart type actively misleads (pie charts for comparison data with many categories).

**Missing data freshness indicators**
- When was this data last updated? Is this real-time, hourly, or from yesterday's batch? Users making decisions based on stale data need to know it's stale. Friedman lists data freshness indicators as a standard dashboard feature.
- Severity: **P2** for dashboards with time-sensitive data and no visible last-updated timestamp.

---

## Principle 7: Respect user intelligence — design for expertise levels

*Carmack: "Understand before opining." He never writes code that assumes its user is stupid — his tools expose power and expect competence.*
*Friedman: Design for three expertise levels — low (progressive disclosure, large text, extra spacing), medium (regular density, shortcuts), high (small text, heavy data, customization, filters). "In complex environments, users often need to rely on access to specific details or raw data."*

Both respect the user. Carmack exposes complexity to competent developers rather than hiding it behind abstractions. Friedman exposes complexity to expert users rather than forcing them through beginner flows. The key insight is that the same interface serves different users — and the same user at different stages of familiarity. Designing only for beginners patronizes experts. Designing only for experts abandons newcomers.

### What to check

**Single-expertise-level design**
- Does the interface serve only one expertise level? A dashboard locked into high-density mode alienates new users. A dashboard locked into low-density mode wastes expert users' screen real estate. Friedman: design for transition between levels — users should be able to increase density and feature exposure as they grow familiar.
- Severity: **P3** at early product stage. **P2** once the product serves both new onboarding customers and daily-use power users.

**Onboarding that blocks the product**
- Friedman: "Anything that keeps users away from using the product is an unnecessary distraction. That's why tutorials and walkthroughs are often dismissed almost instinctively." Never block UI with full-page onboarding modals. Never use multi-step tutorials with 5+ steps. Instead: ask what goals users are trying to achieve, use blank slates + segmentation, show features contextually when users slow down or make mistakes. The goal: "shorten the time to relevance as much as possible."
- Severity: **P1** for blocking onboarding modals that prevent product access. **P2** for multi-step tutorials that are dismissable but delay time-to-value.

**No keyboard shortcuts for frequent actions**
- Friedman treats keyboard shortcuts as a first-class enterprise pattern, listed alongside visual indicators and customizable widgets in his B2B/expert interface curriculum. For actions users perform repeatedly (navigating between items, triggering workflows, switching views), keyboard shortcuts reduce friction for power users without affecting novice flows.
- Severity: **P3** — an expertise-level enhancement, not a defect.

---

## Principle 8: AI-second, not AI-first — structure beats conversation

*Carmack: "Don't build on assumptions you can't verify." Chat-first AI assumes users can articulate precisely what they want in natural language — an unverifiable assumption.*
*Friedman: "Chatbots are rarely a great experience paradigm — mostly because the burden of articulating intent efficiently lies on the user." And: "Conversational AI is a very slow way of helping users express and articulate their intent. Usability tests show that users often get lost in editing, reviewing, typing, and re-typing. It's painfully slow, often taking 30-60 seconds for input."*

Both converge on the same critique: don't assume the user can express their intent through an unconstrained interface. Carmack's code never accepts unconstrained input without validation. Friedman's interfaces never force users to formulate queries from scratch when structured controls would be faster. Chat has a role — but as a secondary refinement layer, not the primary interaction model. Friedman: "AI emphasizes the work, the plan, the tasks — the outcome, instead of the chat input."

### What to check

**Chat as primary interface for structured tasks**
- Is chat the main way users interact with AI features when structured UI would be faster? Friedman's framework: use pre-prompts, query builders, scoping/filtering, templates and presets, and contextual prompts acting on highlighted output (the Grammarly model). Chat should be available for exploration and edge cases — not for the core workflow.
- Severity: **P2** if the primary workflow requires users to type prompts for tasks that could be buttons, selectors, or structured inputs. **P3** if chat is available as an alternative alongside structured controls.

**The blank prompt problem**
- Friedman: "To many, an empty text box is remarkably scary. It suggests to 'Ask me anything', but then users don't really know what to ask, and what format, and at which level of detail." Every AI input surface needs: suggested prompts or pre-prompts, scope indicators (what can this AI do?), and example queries. A bare text field with a placeholder like "Ask anything..." is a UX failure.
- Severity: **P2** for AI input surfaces with no guidance. **P1** if this is the first thing a new user encounters.

**AI output as wall of text**
- Friedman: "AI output doesn't have to be merely plain text or a list of bullet points. It must be helpful to drive people to insights, faster." AI-generated content should be structured with: forced ranking (suggesting best options to avoid choice paralysis), collapsible reasoning traces, data visualizations where appropriate, and actionable elements (buttons, links to next steps) embedded in the output.
- Severity: **P2** for AI output that is pure unstructured text when the content has internal structure (lists, comparisons, recommendations with evidence).

**No refinement controls**
- Friedman identifies refinement as "usually the most painful part of the experience." Users should be able to tweak AI output with controls — not just by re-prompting. Contextual prompts acting on highlighted output sections, temperature/precision knobs, style presets, and bookmark/save for useful sections. "We can use good old-fashioned UI controls like knobs, sliders, buttons."
- Severity: **P3** for missing refinement controls. **P2** if users resort to repeated full re-prompts because no partial refinement exists.

**Agentic AI without guardrails**
- Friedman: "Building guardrails, permissions and approval flows is so critical. This is our new job: keeping the AI on a leash, so it is always aligned with human values." For AI actions that affect external systems (pushing to third-party services, modifying configurations), the user must approve before execution. The approval flow should preview what will happen — not just ask "Are you sure?"
- Severity: **P1** for AI actions that modify external state without user approval. **P2** for approval flows that don't preview the action's consequences.

---

## Principle 9: Trust compounds slowly and is destroyed by single failures

*Carmack: "If a mistake is possible, it will eventually happen." His entire error-handling philosophy: design for the failure case, because it will arrive.*
*Friedman: "AI is fragile, and often mistakes aren't an exception, but rather a matter of time. And every time a user discovers a mistake, it's a small betrayal of trust. Mistakes are expensive as each betrayal chips away from the carefully orchestrated relationship with the user."*

Both converge on inevitability of failure — and the asymmetry between building and destroying trust. Carmack designs systems that fail gracefully because he assumes they will fail. Friedman designs trust mechanisms because he knows AI will produce errors. In a product that generates AI-powered recommendations, one confidently wrong suggestion can undermine all future suggestions. The interface must build trust proactively and degrade gracefully when errors occur.

### What to check

**No reasoning visibility**
- Can users see why the system produced a specific recommendation? Friedman teaches "reasoning traces" as a core trust-building pattern — making the AI's reasoning process visible. For each hypothesis or recommendation, the user should be able to see what evidence led to it. Black-box recommendations ("Test this because our AI says so") erode trust. Transparent recommendations ("Test this because we observed X on your pricing page, which matches pattern Y") build it.
- Severity: **P1** for AI-generated recommendations with no visible evidence or reasoning. **P2** for recommendations where evidence exists in the system but isn't surfaced to the user.

**Inconsistent data across views**
- Friedman on comparison tables: "When attributes are inconsistent, feature comparison becomes irrelevant." And critically: "Once they've had this experience on the website, they will perceive the feature comparison on the website to be 'broken' in general and ignore it altogether in future sessions." A score that shows as 87 in the list view and 85 in the detail view doesn't just confuse — it permanently damages trust in all scores.
- Severity: **P1** for data inconsistencies between views that display the same underlying data. This is not a rounding error — it's a trust-destruction event.

**No confidence indicators**
- Friedman teaches "consensus meters" as a pattern for showing agreement/disagreement levels across sources. For AI-generated analysis, some outputs are higher-confidence than others. If the system treats all recommendations as equally certain, users can't calibrate their trust. Showing confidence levels (even simple high/medium/low) helps users weigh recommendations appropriately.
- Severity: **P3** for missing confidence indicators. **P2** if the product positions itself on analytical rigor.

**AI-generated content indistinguishable from curated content**
- Friedman explicitly teaches "how to signal and label AI-generated content, and make it work with human-written, curated content." If the interface mixes AI-generated analysis with human-curated frameworks or static content, users need to know which is which. Not because AI content is inherently less trustworthy — but because the user's evaluation strategy differs.
- Severity: **P3** — a transparency enhancement that builds trust over time.

---

## Principle 10: Know your gaps — what this doc is weaker on

*Carmack: epistemic humility — you can't fix what you don't know is broken.*
*Friedman: openly shares his workshop curricula and admits when topics are emerging (AI patterns) vs. mature (form design).*

### Areas this doc is weaker on (supplement from other sources)

- **Accessibility/a11y**: Friedman covers accessibility within his patterns (touch targets, keyboard alternatives, colorblind-safe palettes) but his work is not a comprehensive accessibility audit framework. For WCAG 2.2 compliance auditing, supplement with dedicated a11y expertise. This doc does not audit for screen reader compatibility, focus management, ARIA attributes, or contrast ratios.
- **Data visualization depth**: Friedman teaches chart selection and honest charts but is not a visualization specialist. For complex statistical visualizations (experiment results, confidence intervals, statistical significance displays), supplement with Tufte's principles and domain-specific data viz guidance.
- **Animation and micro-interactions**: Friedman curates rather than authors animation guidance. His work covers state transitions conceptually but doesn't provide detailed animation specifications (timing, easing, choreography).
- **Design system architecture**: This doc audits UX patterns, not component library architecture. How Mantine components are composed, themed, or extended is outside scope.
- **Loading states for very slow operations**: Friedman's published writing on loading patterns for operations taking 60–90+ seconds is limited. His general principles (avoid page takeover, use skeleton screens, show progress) apply, but specific patterns for multi-minute AI pipeline processing are not well-covered in his work. Supplement with domain-specific research on progress communication for long-running tasks.
- **Internationalization and localization**: Friedman notes that localization frequently breaks layouts (test with long and short titles) but does not provide comprehensive i18n patterns.

---

## Quick Reference: Severity Guide

| Severity | Pattern | Examples |
|----------|---------|----------|
| **P1 — Fix Now** | User cannot complete core task, is actively misled, or trust is destroyed | Critical data hidden behind clicks, no empty state on primary views, disabled buttons with no explanation, full-page loading lockout, AI actions without approval, data inconsistencies between views, no reasoning behind AI recommendations, blocking onboarding modals |
| **P2 — Fix Soon** | User experience is degraded, friction is unnecessary, or workflows are inefficient | Filters that lock during update, generic error messages, modals for non-blocking content, chat-first for structured tasks, no data drill-down, dashboard metrics without action paths, no data freshness indicators, wall-of-text AI output, blank prompt with no guidance |
| **P3 — Consider** | Polish, consistency, and maturity enhancements | Missing density controls, no keyboard shortcuts, no validation override, no confidence indicators, AI content not labeled, suboptimal chart types, no refinement controls |

### The Overriding Filter

Before writing any finding, apply the Friedman-Carmack synthesis:

1. **Can the user complete their task from this view?** If critical information is hidden or the interface blocks action, flag it. (Both: structure should make intended behavior obvious.)
2. **Does the interface freeze on input?** If any single interaction locks the UI, flag it. (Both: minimize blocking state.)
3. **Are all five screen states designed?** If blank, loading, partial, or error states are missing, flag it. (Both: failure will happen — design for it.)
4. **Is complexity structured or stripped?** If important data was removed to simplify, flag it. (Both: eliminate unnecessary complexity, structure necessary complexity.)
5. **Does the user know why?** If AI recommendations lack evidence, controls are disabled without explanation, or data appears without context, flag it. (Both: the system must communicate what it's doing and why.)
6. **Is the interface honest about uncertainty?** If AI output is presented with false confidence, or data freshness/quality is obscured, flag it. (Both: epistemic honesty is non-negotiable.)

