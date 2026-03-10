# UI Quality Reference — Carmack × Saarinen

Philosophy: John Carmack. Specifics: Karri Saarinen (Linear, Airbnb DLS) + Steve Schoger (Refactoring UI) as supplementary.
Stack context: Next.js App Router / React / TypeScript / tRPC / Prisma / Neon (serverless Postgres) / Clerk (auth) / CSS Modules + BEM / Custom components (no component library). Dark theme. Inter + JetBrains Mono fonts. B2B SaaS — data-dense analytical product.

Every finding must describe the **concrete visual consequence** — not just "this doesn't follow the system."
When Carmack and Saarinen independently converge on a principle, it earns its place here.

**Scope boundary:** This doc covers visual design quality: hierarchy, typography, color, spacing, elevation, motion, and component consistency. It does NOT cover: UX patterns and information architecture (separate domain — quality-ux.md), accessibility/a11y (WCAG compliance assumed, not audited here), brand, marketing pages, or backend concerns. Where UX intersects visual design (density, progressive disclosure triggers), it's noted but not deeply audited.

---

## Principle 1: Reduce noise to reveal hierarchy — the tool should disappear behind the work

*Carmack: "The best code is no code. The second best is simple code." Every unnecessary element is a potential source of confusion.*
*Saarinen: "Just from a visual standpoint, these tools had a lot of noise, and it was hard to understand the important things." He wrote a Chrome extension at Airbnb to "reduce some of the information overload of JIRA, and tone down and improve some of the visuals for better hierarchy. While I only wrote the extension mainly for myself, 100 people ended up using it."*

Both converge on elimination as the path to clarity. Carmack eliminates unnecessary code because every line is a liability. Saarinen eliminates visual noise because every decorative element competes with content. In a data-dense product, the interface chrome (sidebars, headers, controls, borders) must recede so the user's actual work — the data, the recommendations, the results — dominates. Saarinen calls this the "inverted L-shape" problem: the global chrome controls the content, but must never overpower it.

### What to check

**Chrome competing with content**
- Does the sidebar, header, or navigation visually overpower the main content area? Saarinen's 2024 redesign specifically "reduced the visual weight of this chrome to give content more prominence." Interface chrome should use muted colors, lighter font weights, and smaller type — the content area gets the visual priority.
- Are borders, dividers, or background colors creating visual noise between elements that could be separated by spacing alone? Schoger: "Use fewer borders" — three alternatives are box shadows, different background colors, and extra spacing.
- Severity: **P2** for chrome that visually competes with content. **P1** if interface noise makes it difficult to identify the primary data on a view.

**Decorative elements in the application UI**
- Saarinen: "For me, work is serious. If I'm building a house, I don't want my tools to be fun. I want them to be good. I want them to be professional." Linear uses zero decorative illustrations inside the application. Gradients, playful icons, rounded-bubbly elements, and ornamental graphics belong on marketing pages, not in the tool. The aesthetic should communicate competence, not friendliness.
- Severity: **P3** for decorative elements that don't interfere with function. **P2** if decoration takes space away from data or competes with actionable elements.

**Alignment inconsistencies**
- Saarinen's team spent dedicated time "aligning labels, icons, and buttons, both vertically and horizontally in the sidebar and tabs." The result: "not something you'll immediately see but rather something that you'll feel after a few minutes of using the app." Misaligned elements across a view create subliminal noise that accumulates into a feeling of sloppiness. Check: are icons vertically centered with their labels? Do columns align across sections? Are action buttons at consistent positions?
- Severity: **P3** for minor alignment drift. **P2** for visible misalignment between primary UI elements (navigation items, list rows, section headers).

---

## Principle 2: Typography is the primary hierarchy tool — not size alone

*Carmack: "The structure of the code should make the intended behavior obvious." Type structure should make the information hierarchy obvious.*
*Saarinen: "90% of UI is text." "Type that's too decorated or playful can distract or cause people to miss important information, therefore failing its intended purpose." His Linear type system uses two groups (Body and Title) with four sizes each (Large, Regular, Small, Mini) plus "+" weight variations.*

Both treat structure as the primary communication mechanism. Carmack's code structure reveals intent. Saarinen's type structure reveals hierarchy. The key insight from Schoger: "A common mistake when styling UI text is relying too much on font size to control your hierarchy." The three levers are size, weight, and color/contrast — used in combination, not multiplication.

### What to check

**Size as the only hierarchy lever**
- Is the difference between primary and secondary text expressed only through font size? Schoger's rule: primary text should be differentiated by weight or color as well as size. In a dark theme, the primary lever for de-emphasizing secondary text should be reduced opacity or a lower-contrast color — not just smaller size. Check: does metadata (timestamps, assignees, secondary labels) use lighter/lower-contrast color in addition to smaller size?
- Severity: **P2** for hierarchy relying solely on size differences. **P3** if the hierarchy is readable but could be clearer.

**Too many type styles**
- Saarinen's Linear system has approximately 8 type styles (Body/Title × Large/Regular/Small/Mini plus weight variations). A data-dense product needs enough variation for hierarchy but not so many that the system feels arbitrary. If a view uses more than 5-6 distinct type treatments, the hierarchy becomes noise. Check: can every text element on a view be categorized into one of a small set of named styles?
- Severity: **P3** for excessive type variation. **P2** if inconsistent type treatment across similar elements (e.g., timestamps rendered differently in different views).

**Monospace type not used for data/technical content**
- Saarinen uses SF Mono for code and technical content in Linear. In a product that displays scores, IDs, technical metrics, and code-adjacent content, monospace type serves two purposes: it signals "this is data, not prose" and it enables visual alignment of numbers in columns. JetBrains Mono should be used for: scores, numerical data in tables, IDs, technical identifiers, and any code snippets.
- Severity: **P3** — a polish decision, but one that significantly improves scanability of numerical data.

**Label dominance over data**
- Schoger: "Labels are a last resort. When format makes content self-evident, omit the label entirely. When labels are needed, de-emphasize them — smaller, lower contrast, lighter weight. The data should always dominate visually." Check: are labels styled more prominently than the values they describe? A label like "Score:" in bold followed by "87" in regular weight inverts the hierarchy — the data is what matters.
- Severity: **P2** for labels that visually dominate their values in data-dense views. **P3** for labels that could be eliminated because the format is self-evident.

---

## Principle 3: Dark theme is a system, not an inversion — use opacity and elevation, not specific colors

*Carmack: "Don't build on assumptions you can't verify." Hand-picking hex values assumes perceptual correctness that human intuition can't reliably provide.*
*Saarinen: "Karri mostly worked with opacities of black and white during his explorations, which really helped him get results quickly and helped me understand the relationship he had in mind between the elements and their respective elevation and hierarchy." Linear uses LCH color space and generates its entire theme from three inputs: base color, accent color, and contrast.*

Both converge on systematic generation over manual selection. Carmack trusts verified systems over intuition. Saarinen's opacity-based exploration defines relationships between surfaces before committing to specific colors. The key principle: in dark themes, elevation is expressed through lightness — closer surfaces are lighter, distant surfaces are darker. This is the opposite of light themes (where shadows provide depth) and must be deliberately designed.

### What to check

**Pure black backgrounds**
- Saarinen: Linear never uses pure black (#000000). The darkest backgrounds use near-black with subtle tinting (approximately #0F0F10). Pure black creates excessive contrast with text, causes eye strain in prolonged use, and makes the interface feel like a void rather than a surface. Check: are any backgrounds #000000 or very close to it?
- Schoger: "Avoid pure black — dark grey looks more natural. Saturate dark greys with a cool hue."
- Severity: **P2** for pure black backgrounds on primary surfaces.

**No elevation hierarchy between surfaces**
- Saarinen's system defines background → foreground → panels → dialogs → modals as progressively lighter surfaces. Each level differs by only a few lightness points (e.g., #0F0F10 base to #151516 elevated). Without this layering, overlapping surfaces blend together and spatial relationships become ambiguous. Check: do modals, dropdowns, and panels use a lighter background than the page surface behind them?
- Schoger: "Don't throw away the visual cues in the light version by naively inverting the color scheme. Close elements should still be lighter and distant elements should still be darker — even in a dark UI."
- Severity: **P1** for modals or dropdowns that are indistinguishable from the surface behind them. **P2** for missing intermediate elevation levels (e.g., cards on a page surface).

**Harsh borders in dark theme**
- In dark themes, opaque borders can be visually harsh and create a "wireframe" feel. Saarinen's Linear uses extremely subtle borders or none at all, relying on background differentiation and spacing. Where borders are used, semi-transparent white overlays (e.g., `rgba(255, 255, 255, 0.06)`) adapt naturally to any background surface rather than fighting it. Check: are borders using opaque colors that create hard lines between elements?
- Severity: **P3** for harsh borders on secondary elements. **P2** if borders dominate the visual field and create a cage-like feel.

**Accent color overuse**
- Saarinen uses Linear's accent color (#5E6AD2, purple/indigo) sparingly — selected states, active navigation, primary buttons, and brand moments. If the accent color appears on every interactive element, it stops functioning as a hierarchy signal and becomes noise. Check: is the accent color reserved for primary actions and active states, or spread across every link, button, and interactive element?
- Schoger: "Be conservative with how you use brand colors. You'd be surprised how little color you need."
- Severity: **P2** for accent color overuse that flattens hierarchy. **P3** for accent on elements where a neutral treatment would suffice.

**Semantic colors that strain against dark backgrounds**
- Saarinen's Linear desaturates status and priority colors enough to avoid eye strain against dark backgrounds while keeping them recognizable. Fully saturated reds, greens, and blues on dark backgrounds create visual "hot spots" that draw attention disproportionately. Check: are status/priority colors desaturated for the dark theme, or using the same full-saturation values that would work on white backgrounds?
- Severity: **P2** for fully saturated semantic colors on dark backgrounds. **P3** for minor saturation adjustments needed.

---

## Principle 4: Spacing creates meaning — use a systematic scale and let proximity do the grouping

*Carmack: "State is the enemy." Every spacing value that doesn't belong to a system is a piece of ad hoc state that makes the interface harder to maintain and reason about.*
*Saarinen: "The grid 8, and the 24 spacing, generally affected our type styles. I think spacing often goes with the typography." Linear uses a 4px base grid. At Airbnb, he established 8pt/4pt grids with 24pt as the primary spacing unit, with line-heights snapping to the grid.*

Both demand systematization. Carmack eliminates unnecessary state; Saarinen eliminates arbitrary spacing values. The practical consequence: every margin, padding, and gap in the interface should come from a defined scale, and the relationships between spacing values should communicate grouping. Tighter spacing means "these things are related." More spacing means "new group."

### What to check

**Arbitrary spacing values**
- Does the CSS use a consistent spacing scale, or are values arbitrary (13px here, 17px there, 22px somewhere else)? A 4px base grid means all spacing values should be multiples of 4: 4, 8, 12, 16, 20, 24, 32, 40, 48, 64. Check CSS modules for spacing values that don't fit the grid.
- Severity: **P3** for occasional off-grid values. **P2** for no discernible spacing system across components.

**Spacing not communicating grouping**
- Is the space between a section header and its content the same as the space between two unrelated sections? Schoger: "Increase spacing between groups and reduce spacing within groups to leverage Gestalt proximity." The space between items in a list should be smaller than the space between the list and the next section. Check: do related elements feel grouped and unrelated elements feel separated?
- Severity: **P2** for uniform spacing that makes grouping ambiguous. **P3** for minor proximity issues.

**Density without system**
- Saarinen achieves Linear's density through tight vertical padding on list items (approximately 8-12px) with generous horizontal spacing between metadata clusters. The result: high information density that's still scannable. If the interface is dense but elements feel cramped — touching each other or lacking breathing room within rows — the density is accidental rather than designed. Check: do list items have consistent, tight-but-not-cramped vertical padding?
- Severity: **P2** for cramped density that hurts scanability. **P3** for inconsistent density across similar components.

**Line-heights not grid-aligned**
- Saarinen: "We made sure that the line-heights would align with our grid, and our text size would work on those line-heights." When line-heights don't snap to the spacing grid, text blocks create fractional-pixel offsets that compound across the layout, causing subtle misalignment. Check: are line-height values multiples of 4px?
- Severity: **P3** — a refinement, but one that compounds across the entire interface.

---

## Principle 5: Color communicates — use a token system with semantic roles, not ad hoc hex values

*Carmack: "Use the type system to prove absence of flaw classes." A named color token system eliminates the class of bugs where the same conceptual color is specified differently in different places.*
*Saarinen: Linear's design tokens are organized into groups — Bg, Label, Control — each with variations: Base, Shade, Muted, Faint. "When designing, I write 'bg base' for default background, 'label base' for default text." The full theme is generated from three inputs: base color, accent color, and contrast.*

Both use naming and structure as guarantees. Carmack's type system prevents classes of errors at compile time. Saarinen's token system prevents classes of visual inconsistency at design time. A named token like `label-muted` used everywhere secondary text appears is a single source of truth — changing the token updates every instance. Ad hoc hex values scattered across CSS modules guarantee drift.

### What to check

**Raw hex/RGB values in CSS instead of tokens**
- Are color values specified as raw hex codes in CSS modules, or do they reference CSS custom properties (design tokens)? Every color in the interface should trace back to a named token. Check: grep CSS modules for hex values, rgb(), and hsl() that aren't token references.
- Severity: **P2** for widespread raw color values with no token system. **P3** for a token system that exists but has leaks (occasional raw values).

**No semantic color roles**
- Saarinen's system separates colors by role: Bg (backgrounds), Label (text/icons), Control (interactive elements). Within each role, variations (Base, Shade, Muted, Faint) express hierarchy. Check: does the token system distinguish between background colors, text colors, and interactive element colors? Or is the same token used for backgrounds and text?
- Severity: **P2** for no role-based color organization. **P3** if roles exist but aren't consistently applied.

**Inconsistent color for the same semantic meaning**
- Does the same concept (e.g., "secondary text," "surface background," "destructive action") use different colors in different components? This creates the subliminal inconsistency that Saarinen's alignment work addresses — the user won't consciously notice, but they'll feel that something is off. Check: compare the same semantic element across views (e.g., timestamps, status indicators, secondary labels).
- Severity: **P2** for visible inconsistency in semantic colors across views. **P3** for minor shade variations.

---

## Principle 6: Motion confirms action — never decorate, never delay

*Carmack: "Latency is always a bug." Every millisecond of unnecessary delay degrades the user's experience.*
*Saarinen: "Almost everyone said that they hate when these tools are slow. So that made us think like, what if we can build a tool that is never slow?" Linear's standard hover transition is 150ms. Saarinen personally reviews animation quality before shipping: "I go there to click it and see that the animations feel good."*

Both treat speed as non-negotiable. Carmack optimized rendering loops for the lowest possible latency. Saarinen built Linear's entire architecture (local-first, sync engine) to eliminate perceived latency. Animation exists to confirm that something happened (a state change, a navigation, an item appearing) — not to impress. Any animation that makes the user wait is a bug.

### What to check

**Animations that delay interaction**
- Can the user interact with the destination state before the animation completes? If a panel slides open over 300ms and the user can't click its contents until the animation finishes, the animation is blocking. Check: are transitions short enough (100-200ms for micro-interactions, 200-300ms max for view transitions) and non-blocking?
- Severity: **P1** for animations that block user input. **P2** for animations over 300ms on frequent interactions.

**Inconsistent animation timing**
- Saarinen's team tracked a bug where "one of the buttons darkened instantly when the mouse moved away, rather than fading out over 150 milliseconds as it should have." The standard hover fade-out is 150ms. Inconsistent timing across similar interactions creates a feeling of jankiness. Check: do all hover states, expand/collapse, and panel transitions use consistent durations?
- Severity: **P3** for minor timing inconsistencies. **P2** if inconsistency is visible on the same view (one button animates, adjacent button snaps).

**No animation on state changes**
- State changes without any visual transition can feel jarring — an element appearing or disappearing instantly leaves the user unsure what changed. Brief, subtle transitions (fade, slide) provide continuity. However: absence of animation is always better than bad animation. Check: do important state changes (item added/removed, panel open/close, view switch) have transitions? Do unimportant state changes (hover, focus) have subtle feedback?
- Severity: **P3** — a polish concern. Never add animation just to satisfy this check.

**Optimistic UI missing for safe actions**
- Saarinen: Linear's local-first architecture means "all the actions you take with the data, they happen locally on the client and then the changes get synced to the server." For actions where the outcome is predictable (toggling, reordering, status changes), the UI should update immediately. Waiting for a server round-trip on a safe action introduces unnecessary latency. Check: do safe actions update the UI optimistically, or does the user see a loading state?
- Severity: **P2** for safe actions that show loading spinners. **P3** for minor delays on infrequent actions.

---

## Principle 7: Shadows and elevation are a system — define levels, not individual values

*Carmack: "Assertions catch assumption violations." A defined elevation system asserts which elements sit above which — violations are immediately visible.*
*Saarinen: Linear's token system defines four shadow levels — shadowLow (buttons), shadowMedium/High (elevated boxes), Float (modals, large floating elements). The LCH color system calculates elevation through background lightness: background → foreground → panels → dialogs → modals.*

Both demand that systems replace ad hoc decisions. Carmack's assertions define invariants that the system enforces. Saarinen's elevation system defines which surfaces sit above which. In dark themes, elevation is expressed through both lighter backgrounds and shadow (though Schoger notes shadows are less effective on dark backgrounds — lighter surface colors carry more weight). Every component should know its elevation level.

### What to check

**No defined elevation levels**
- Does the CSS define a system of shadow/elevation levels, or are box-shadow values specified ad hoc per component? Saarinen's four levels (Low/Medium/High/Float) are sufficient for most interfaces. Check: are shadows consistent across components at the same elevation (e.g., all dropdowns use the same shadow)?
- Schoger: define 5 levels — extra small (rest), small (primary actions), medium (dropdowns), large (modals), extra large (dragged elements). Use two-part shadows: a larger diffuse shadow plus a smaller tight shadow.
- Severity: **P3** for no shadow system. **P2** if different components at the same elevation have different shadows.

**Dark theme elevation without background differentiation**
- In dark themes, shadows alone are insufficient for elevation. If a modal uses the same background color as the page surface, no amount of shadow will make it feel elevated. Check: do elevated elements (modals, dropdowns, popovers, drawers) use a lighter background than the surface behind them?
- Severity: **P1** for modals indistinguishable from the background. **P2** for dropdowns or popovers that don't clearly float above the surface.

---

## Principle 8: Component consistency is systematic, not decorative — build tokens, not one-offs

*Carmack: "The single most effective strategy for defect reduction is code reduction." Shared tokens and consistent components reduce the surface area for visual bugs.*
*Saarinen: "Been designing the last few weeks and realized how simple but effective the Linear design system is. There is no design system team, no councils, no meetings about what we should call it. We have a system which has colors, type, icons and components. It feels very simple and light but still useful. Like a good tool."*

Both value simplicity in systems. Carmack reduces code. Saarinen reduces design system overhead. For a solo developer without a design team, the system must be lightweight enough to maintain: color tokens, type styles, spacing scale, shadow levels, a few shared component patterns. Not a 200-page design system document. The system exists in the CSS custom properties and the shared component styles — not in documentation.

### What to check

**Component visual inconsistency**
- Do buttons, inputs, cards, and list items look consistent across views? Same border radius, same padding, same font treatment? Saarinen's team uses 6px border radius for interactive elements. If buttons on one page have 4px radius and buttons on another have 8px, the interface feels assembled from parts rather than designed as a whole. Check: compare the same component type across different views.
- Severity: **P2** for visible inconsistency in core components (buttons, inputs, cards). **P3** for minor inconsistency in secondary elements.

**No shared CSS custom properties**
- Is there a central file defining CSS custom properties for colors, spacing, typography, shadows, and border-radius? Or are values repeated across CSS modules? The system should be definable in a single variables file that every module imports. Check: does a global variables file exist and is it used consistently?
- Severity: **P2** for no central token file. **P3** if tokens exist but are partially adopted.

**One-off component styles**
- Does a component that appears multiple times in the codebase have multiple different style implementations? The same list item pattern should use the same CSS module or shared styles. Check: are there duplicate style patterns across modules that could be consolidated?
- Severity: **P3** — maintenance concern, not a user-facing issue unless it produces visible inconsistency.

---

## Principle 9: Quality is the accumulation of small corrections — track and fix visual debt

*Carmack: "If a mistake is possible, it will eventually happen." Quality is maintained by finding and fixing mistakes, not by preventing them.*
*Saarinen: "Quality doesn't happen on its own, you need to push for it." Linear tracks quality issues with a dedicated label. Over 1,000 small fixes in two years, each taking 30 minutes or less. "Since you train this muscle over time, you start noticing patterns and common pitfalls while building stuff, so fewer of these papercuts ship."*

Both treat quality as a practice, not a state. Carmack's debugging philosophy: bugs are inevitable, so build systems to find them. Saarinen's Quality Wednesdays: visual papercuts are inevitable, so build a habit of fixing them. For a solo developer, this means: notice when a spacing value is off, when a color doesn't match, when an animation stutters — and fix it in the moment rather than accumulating debt.

### What to check

**Visible layout shifts**
- Does any interaction cause content to jump or shift position? Saarinen's team fixed a bug where the "issue composer height changed when adding a line." Layout shifts break spatial memory — the user's eyes lose their place. Check: does adding content, expanding sections, or loading data cause surrounding elements to jump?
- Severity: **P1** for layout shifts on primary interactions. **P2** for shifts on secondary interactions.

**Inconsistent hover/focus states**
- Do all interactive elements have visible hover and focus states? Are they consistent? Saarinen's 150ms standard applies to all hover transitions. Check: hover over every interactive element on a view — do they all respond, and do they respond the same way?
- Severity: **P2** for interactive elements with no hover state. **P3** for inconsistent hover treatments.

**Pixel-level polish issues**
- Text truncation without ellipsis, scrollbars appearing unexpectedly, elements overflowing their containers, content touching container edges without padding. These are the "1,000 small fixes" that compound into quality. Each is individually P3 but collectively they define the difference between "rough" and "polished."
- Severity: **P3** individually. Note the count — 5+ pixel-level issues on a single view suggests systematic neglect.

---

## Principle 10: Know your gaps — what this doc is weaker on

*Carmack: epistemic humility — you can't fix what you don't know is broken.*
*Saarinen: his published body of work is narrower than other experts in this system — he's a practitioner who ships, not a prolific author. Many decisions are observable in Linear but never explicitly discussed.*

### Areas this doc is weaker on (supplement from other sources)

- **Accessibility**: Saarinen mentions the LCH contrast variable for high-contrast themes but has not published detailed accessibility guidance. For WCAG 2.2 compliance, supplement with dedicated a11y expertise. Dark theme contrast ratios need specific verification.
- **Responsive/mobile design**: This doc focuses on desktop-first data-dense interfaces. Saarinen's mobile work (Liquid Glass) is iOS-native, not web. For responsive web patterns in data-dense interfaces, supplement with Friedman's quality-ux.md.
- **Data visualization**: Saarinen has not discussed chart design or data visualization. For statistical displays (experiment results, confidence intervals), supplement with domain-specific guidance.
- **Iconography specifics**: Saarinen has not published detailed iconography principles. Linear's icons are consistent but the system isn't documented publicly. Decisions about icon weight, size, and grid must be made from first principles or adopted from an icon library.
- **Animation easing curves**: The 150ms duration is documented but specific easing functions are not. Community observation suggests ease-out for most transitions but this isn't confirmed.
- **Print/export styling**: Not covered. If the product produces downloadable reports or printable views, dark-theme-to-print conversion needs separate consideration.

---

## Quick Reference: Severity Guide

| Severity | Pattern | Examples |
|----------|---------|----------|
| **P1 — Fix Now** | User cannot parse the interface, spatial relationships are broken, or interaction is blocked | Modals indistinguishable from background, content invisible due to contrast failure, animations blocking input, layout shifts on primary interactions, noise making primary data unreadable |
| **P2 — Fix Soon** | Visual hierarchy is degraded, consistency is broken, or the interface feels rough | Chrome competing with content, no elevation system, raw hex values everywhere, inconsistent component styling, accent color overuse, harsh borders, pure black backgrounds, labels dominating data, spacing not communicating grouping |
| **P3 — Consider** | Polish, systematization, and refinement | Off-grid spacing, type style proliferation, minor alignment drift, missing hover states, pixel-level overflow, animation timing inconsistency, monospace not used for data |

### The Overriding Filter

Before writing any finding, apply the Saarinen-Carmack synthesis:

1. **Can the user immediately identify what's important on this view?** If hierarchy is flat or noisy, flag it. (Both: structure should make the important things obvious.)
2. **Is the color/spacing/typography systematic or ad hoc?** If values are arbitrary, flag it. (Both: systems eliminate classes of errors.)
3. **Does the dark theme feel like a surface or a void?** If elevation is missing, backgrounds are pure black, or elements float without spatial grounding, flag it. (Saarinen: opacity-based relationships define the space.)
4. **Does every pixel earn its place?** If an element is decorative, a border could be replaced by spacing, or chrome could be lighter, flag it. (Both: eliminate the unnecessary.)
5. **Is the quality consistent across views?** If one view is polished and another is rough, flag it. (Saarinen: quality is 1,000 small fixes, not one big redesign.)
6. **Would this feel fast?** If animations delay interaction, loading states are heavy, or transitions are janky, flag it. (Both: latency is always a bug.)
