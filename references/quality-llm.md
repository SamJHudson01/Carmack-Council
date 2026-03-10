# LLM Pipeline Quality Reference — Carmack × Willison

Philosophy: John Carmack. Production LLM expertise: Simon Willison (Datasette, LLM CLI, 143+ posts on prompt injection, 8,000+ logged LLM interactions).
Stack context: Next.js App Router / React / TypeScript / tRPC / Prisma / Neon (serverless Postgres) / Clerk / CSS Modules + BEM. LLM calls via OpenRouter. Prompt templates as TypeScript functions. Chained multi-step pipelines processing untrusted content.

**PROJECT POLICY — NO PREMATURE OPTIMISATION ON LLM CALLS:** This project does NOT cap token output (`max_tokens`, `maxOutputTokens`), does NOT impose prompt length budgets, does NOT set artificial instruction-following degradation thresholds, and does NOT limit LLM costs via token caps. We pay for quality. If a prompt is too long, the fix is better prompt content — not an arbitrary ceiling. Do NOT recommend token limits, cost budgets, prompt length gates, or output truncation. This policy is non-negotiable.

Every finding must describe the **concrete failure mode** — not just "this is bad practice."
Security patterns are in security.md (Hunt). Async/error handling is in quality-backend.md (Collina). Prisma/Neon depth is in quality-postgres.md (Leach). This doc covers: structured output reliability, prompt architecture, chain integrity, context hygiene, indirect prompt injection, model portability, cost control, eval coverage, and observability of LLM calls.

---

## Principle 1: Structured output works until it doesn't — validate after generation

*Carmack: "If a mistake is possible, it will eventually happen."*
*Willison: "As with anything LLM, 100% reliability is never guaranteed." He documented that OpenAI's pre-strict JSON modes "usually did [return valid JSON], but there was always a chance that something could go wrong." On catastrophic failures: strict mode means "failures are rarer but more catastrophic. If the model gets too confused, it can get stuck in loops where it just prints technically valid output forever without ever closing the object."*

Both converge on the same principle: the system's contract must be enforced by the system, not by hope. Schema enforcement during generation reduces failures; it does not eliminate them. Post-generation validation is the tripwire that catches what the schema missed.

### What to check

**Missing parse validation**
- Is the JSON output from each LLM call parsed inside a try/catch with meaningful error handling? A bare `JSON.parse()` with no recovery path means a single malformed response crashes the caller.
- After parsing, is the result validated against the expected schema (Zod, TypeScript type guard, or equivalent)? Parsing succeeds on `{"garbage": true}` — that doesn't mean the model returned the expected structure. Parse success is not schema compliance.
- Severity: **P1** for LLM calls with no parse validation. **P2** for parse-only without schema validation.

**Silent provider structured output failures**
- Willison documented that OpenRouter's `response_format` option "only works for some models, and if you try to use it on others it is silently ignored." If the application relies on `response_format` for JSON enforcement, is there validation that JSON actually arrived? A silent fallback to unstructured text produces confusing errors far from the root cause.
- This applies to any provider abstraction layer. The further the code is from the raw model API, the more likely that schema enforcement is assumed but not verified.
- Severity: **P1** — silent failures that surface as confusing downstream errors.

**No max_tokens guard against runaway generation**
- When strict schema mode gets confused, models can "get stuck in loops" generating valid-but-useless tokens until hitting the token limit.
- **PROJECT OVERRIDE: This project does NOT set `max_tokens`, `maxOutputTokens`, or any artificial token limits on LLM calls.** Truncation is premature optimisation. Models use their native output ceiling. If output is too long, fix the prompt — don't cap the output. Do NOT flag missing token limits as a finding.
- Severity: **Not a finding in this project.** The project explicitly pays for quality over token savings.

**Schema complexity inviting failure**
- Willison cited Paul Gauthier's finding that LLMs are "slightly less reliable at producing working code if you request that code be returned as part of a JSON response." Complex nested schemas with long string fields are higher-risk than simple flat schemas. Are output schemas as simple as the task requires, or over-specified?
- For LLM calls that intentionally return unstructured text (lists, prose, analysis): is this a conscious design choice? If so, is the format validation (regex, line counting, structural checks) sufficient, or could a malformed response pass validation while being semantically empty?
- Severity: **P3** for unnecessarily complex schemas. **P2** for unstructured output with no quality gate beyond format checking.

---

## Principle 2: Separate instructions from data — structural separation for output quality

*Carmack: "The structure of the code should make the intended behavior obvious."*
*Willison: "LLMs are unable to reliably distinguish the importance of instructions based on where they came from. Everything eventually gets glued together into a sequence of tokens."*

**Lane boundary: Prompt injection defense (escaping, injection guards, delimiter breakout) is Hunt's domain (security.md). Willison reviews structural separation only when it affects output quality** — i.e., when missing delimiters cause the model to confuse instructions with data content, degrading the quality of the pipeline's output. Do not flag missing escaping, missing injection guards, or delimiter breakout vectors. Those are security findings, not LLM pipeline quality findings.

### What to check

**Untrusted content interleaved with instructions (output quality concern)**
- Is untrusted content placed after all instructions, or interleaved with them? Instruction ordering matters — content injected between instructions is more likely to cause the model to lose track of its task, producing lower-quality output.
- Are data sections clearly delimited (XML tags, explicit markers) so the model can distinguish instruction from content? Missing delimiters degrade output quality by confusing the model about what is task instruction vs reference material.
- Severity: **P2** if untrusted content is interleaved with instructions in a way that measurably degrades output quality. **P3** for missing delimiters that haven't caused observable quality issues.

**Chain propagation of quality-degrading content**
- In chained pipelines, the output of a step that processed untrusted content becomes input to the next step. If large blocks of irrelevant content survive as intermediate output, they degrade downstream step quality through context distraction. For steps that process untrusted content and produce structured output: is the output validated against its expected schema before being passed downstream? Classification into fixed categories is verifiable. Free-text analysis is not.
- Severity: **P2** for steps that pass unvalidated intermediate output to downstream steps.

---

## Principle 3: Context is not free — curate what each step sees

*Carmack: "The single most effective strategy for defect reduction is code reduction." (Applied to context: the most effective strategy for output quality is context reduction.)*
*Willison endorsed Drew Breunig's taxonomy of context failure modes as essential knowledge. On chains specifically: "chaining multiple tools together involves passing their responses through the context, absorbing more valuable tokens and introducing chances for the LLM to make additional mistakes." And: "context rot — where as context grows and especially if it grows with lots of distractions and dead ends, the output quality falls off rapidly."*

Both converge on minimalism. Carmack says less code means fewer bugs. Willison says less context means better output. In chained pipelines, accumulated context from prior steps is the primary vector for quality degradation.

### What to check

**Context accumulation across chain steps**
- Does each step receive only what it needs, or does context snowball as outputs accumulate? If later steps receive the full raw input content + all prior step outputs + injected knowledge, that's context distraction risk. The model may over-focus on accumulated context and neglect its actual task.
- Willison's "context distraction" concept: "When a context grows so long that the model over-focuses on the context, neglecting what it learned during training." The fix is not just truncation — it's curation. Each step's input should be deliberately assembled.
- Severity: **P2** for steps receiving substantially more context than they need. **P3** for uncurated accumulation that hasn't yet caused observable problems.

**Context poisoning from prior steps**
- Willison's "context poisoning" concept: "When a hallucination or other error makes it into the context, where it is repeatedly referenced." An incorrect output from an early pipeline step becomes ground truth for every subsequent step. One bad classification poisons the entire chain.
- Is there any mechanism to detect or recover from upstream errors? Confidence thresholds, sanity checks, or human review triggers for low-confidence outputs?
- Severity: **P1** for early-stage errors that propagate unchecked through all downstream steps.

**Context clash from injected knowledge**
- Willison's "context clash" concept: "When you accrue new information and tools in your context that conflicts with other information in the prompt." If a prompt includes both generic domain knowledge and specific evidence from prior steps, the model must reconcile potentially conflicting signals. Is the injected knowledge relevant to the specific task at hand, or generic boilerplate?
- Large static knowledge blocks (reference frameworks, example libraries, pattern databases) injected into every prompt regardless of relevance are high-risk for context distraction and clash. Is injected knowledge filtered by the task's actual needs?
- Severity: **P3** for generic knowledge injection. **P2** if large knowledge blocks are injected unfiltered.

---

## Principle 4: Log every LLM call — observability is not optional

*Carmack: "If you can't measure it, you can't improve it."*
*Willison built logging into LLM from day one as a non-negotiable default — full prompt, response, model, token usage, duration, conversation threading. His personal database holds 8,000+ entries. He endorsed Hamel Husain's principle: "A reasonable heuristic is to keep reading logs until you feel like you aren't learning anything new."*

Both converge on instrumentation as the foundation for everything else — debugging, eval, cost tracking, and quality improvement. In chained pipelines, the ability to trace a bad output back to the specific step that went wrong is the difference between fixing a bug and guessing.

### What to check

**Missing or incomplete LLM call logging**
- Is every LLM call logged with: model identifier, token usage (input + output), latency, and a run ID that links all steps in a pipeline execution? Willison logs all of these by default in his `llm` tool.
- The critical debugging question: "This output is bad — which step produced the bad output?" If the logging can't answer this, it's insufficient.
- **Prompt and response content logging is a conscious tradeoff.** Willison's `llm` tool logs full prompt/response text for personal use, but production SaaS pipelines process user-submitted content (scraped pages, uploaded documents, business context). Logging this content to external telemetry (Axiom, Datadog) creates a privacy and data-handling surface that may outweigh the debugging benefit. If the codebase convention explicitly prohibits logging request/response bodies (e.g., "Never log request/response bodies — they contain user-submitted data"), respect it. The convention is valid. Do not flag missing prompt/response content logging as a finding when a no-content-logging convention is documented. Structural metadata (model, tokens, duration, step label, finish reason) is sufficient for production observability. Prompt replay debugging can be achieved through deterministic prompt reconstruction from logged input parameters rather than storing raw prompt text.
- Severity: **P1** for no logging of LLM calls at all. **P2** for partial logging missing structural metadata (model, tokens, duration, step label). **Not a finding** when prompt/response content logging is omitted per a documented convention.

**No per-step cost tracking**
- Willison tracks token usage per call and maintains pricing tools (llm-prices.com). Without per-step token tracking, cost hotspots are invisible. In chained pipelines, one step that includes large static context may cost 5-10x more than adjacent steps. Is that known or assumed?
- Severity: **P2** for no token usage tracking per step.

**Static context duplication in logs**
- Willison's LLM tool de-duplicates fragments by SHA256 hash to prevent redundant storage. If logging stores the full prompt for every call, and every prompt includes the same injected knowledge or reference material, the log storage grows linearly with redundant data. Are static prompt components stored separately or duplicated per log entry?
- Severity: **P3** — operational efficiency, not correctness.

**No replay capability for debugging**
- Can a specific pipeline step be re-run with the exact same inputs? This requires logging the complete input context, not just the final assembled prompt. Willison's approach — log everything to a queryable database — enables replay naturally.
- For HTTP-level debugging, Willison recommends intercepting raw API calls. Is there a mechanism to inspect the actual request/response to the LLM provider, not just the application-level abstraction?
- Severity: **P3** at small scale. **P2** when pipeline complexity makes manual debugging impractical.

---

## Principle 5: Build evals or accept that you're guessing

*Carmack: "If it isn't tested, it's broken."*
*Willison: "It's become abundantly clear that writing good automated evals for LLM-powered systems is the skill that's most needed to build useful applications." On the OpenAI sycophancy incident: "The biggest miss here appears to be that they let their automated evals and A/B tests overrule those vibe checks!" His conclusion: both automated evals AND human vibe checks are necessary — neither alone is sufficient.*

Both agree that untested code is broken code. Willison extends this to LLM systems: untested prompts are broken prompts — you just don't know how yet. The non-deterministic nature of LLMs makes this harder than code testing, but not optional.

### What to check

**No eval suite for pipeline steps**
- Does any LLM-powered step have golden test cases — known inputs with expected outputs that are checked after prompt changes? Without evals, every prompt edit is a coin flip. Willison: evals are "the LLM equivalent of unit tests."
- Classification steps: are there test cases with known correct labels that validate accuracy? Willison endorsed from Husain: "unlike traditional unit tests, you don't necessarily need a 100% pass rate. Your pass rate is a product decision."
- Analysis/generation steps: is there a mechanism to check that outputs are grounded in the actual input content (not hallucinated)? Willison: "The moment you run LLM generated code, any hallucinated methods will be instantly obvious. Compare this to hallucinations in regular prose, where you need a critical eye."
- Scoring/ranking steps: are there consistency tests (if A's evidence is stronger than B's, A should score higher)?
- Severity: **P1** for zero evals across the pipeline. **P2** for partial coverage.

**No regression detection on prompt changes**
- When a prompt template is modified, is there any mechanism to detect quality regression? Husain (endorsed by Willison): "we've spent 60-80% of our development time on error analysis and evaluation." Without measurement, prompt changes are guesswork.
- Severity: **P2** for no regression detection mechanism.

**No defined acceptable failure rates**
- Willison endorsed the principle that eval pass rates are product decisions. What's the acceptable error rate for each pipeline step? What's tolerable for classification? For analysis? For scoring? If these aren't defined, there's no way to know if the system is performing well enough.
- Severity: **P3** — a maturity question, not a bug. But it blocks meaningful improvement.

**Over-reliance on automated evals without human review**
- Willison's key lesson from the OpenAI sycophancy incident: automated evals said the model was fine, expert testers said it felt wrong, OpenAI shipped it anyway and users revolted. "Some expert testers had indicated that the model behavior 'felt' slightly off." Is there human review of a sample of outputs, not just automated checking?
- Severity: **P3** in early development. **P2** in production with customers.

---

## Principle 6: Design for model portability — the provider will change

*Carmack: "Don't build on assumptions you can't verify."*
*Willison: "Any strategy that ties you to models from exclusively one provider is short-sighted. The best available model for a task can change every few months." He documented that the same open-weight model performs differently across hosting providers, with benchmark scores ranging from 93.3% to 56.7% depending on the host. On tool calling: "particularly vulnerable to these differences — models have been trained on specific tool-calling conventions, and if a provider doesn't get these exactly right the results can be unpredictable but difficult to diagnose."*

Both converge on avoiding unverifiable assumptions. Code that assumes one provider's behavior persists across providers, or that a model's behavior today matches its behavior after a provider-side update, is building on sand.

### What to check

**Prompts coupled to provider-specific behavior**
- Do prompt templates rely on behaviors specific to one model family (particular JSON formatting expectations, instruction-following quirks, multimodal handling conventions)? If the application needs to switch providers — either by choice or because a fallback activates — how much breaks?
- For multimodal features (video, image analysis): these are inherently coupled to providers with native multimodal support. Is this coupling acknowledged and isolated, so text-only pipeline steps can switch models independently?
- Severity: **P3** for implicit coupling in text-only steps. **P2** if coupling would prevent using a planned fallback chain.

**No provider-level output validation**
- If a fallback chain activates and a different provider serves the request, is there validation that the response quality is comparable? Willison documented that OpenRouter's structured output may be silently ignored for some models. A fallback that silently degrades output quality is worse than a visible failure.
- Severity: **P2** for no quality validation when the serving provider changes.

**No abstraction layer for model calls**
- Is there a single point of control for model configuration (model ID, temperature, max_tokens, response_format) per pipeline step? Or is configuration scattered across prompt template files and call sites? Centralised configuration makes model switching a config change rather than a code change.
- Willison built his entire `llm` tool around the principle that the model should be interchangeable: "I figured out quite a few of the details of this while offline on a camping trip... which forced the issue on figuring out how to work with LLMs that I could host on my own computer."
- Severity: **P3** — architectural hygiene, not a bug.

---

## Principle 7: Treat the chain as a system — validate at every boundary

*Carmack: "Assertions catch assumption violations before they become exploitable."*
*Willison endorsed Anthropic's guidance to "find the simplest solution possible, and only increase complexity when needed." On chains: "The autonomous nature of agents means higher costs, and the potential for compounding errors." He endorsed Breunig's "context poisoning" concept: "When a hallucination or other error makes it into the context, where it is repeatedly referenced."*

A multi-step chain is not N independent calls — it's a system where each step's assumptions depend on the previous step's correctness. Carmack's assertion philosophy applies: every boundary between steps is a place where assumptions can be verified before errors compound.

### What to check

**Missing inter-step validation**
- At each handoff between pipeline steps, is the output of step N validated before being consumed by step N+1? Key checks by step type:
  - **Classification steps**: output validated against the fixed set of valid categories. This is the cheapest, most reliable validation — Willison specifically identified it as the exception where quarantined LLM output can be safely passed forward.
  - **Analysis/observation steps**: output checked for minimum quality (sufficient detail, grounded in input content, expected format). Format checks catch structural failures but not semantic ones.
  - **Generation steps**: output validated against expected schema before downstream consumption (merge, scoring, storage).
  - **Scoring steps**: output checked for consistency (scores within valid range, referenced IDs exist in input).
- **Severity calibration by pipeline action profile:** For pipelines that drive automated actions (tool calls, code execution, data mutations), missing validation on untrusted content is **P1**. For advisory-only pipelines where a human reviews all output before acting, structural format validation (schema checks, line counts, length limits) is sufficient — missing *semantic* grounding validation is **P3**, not P1. The human review loop serves as the final validation gate. **P2** for missing validation between internal steps regardless of action profile (this affects output quality, not safety).

**Pipeline complexity not justified**
- Willison's starting principle: "find the simplest solution possible." For every chain decomposition, the question is: does splitting this into separate calls improve quality enough to justify the added complexity, latency, cost, and error surface? Could adjacent steps be combined without quality loss? Could any step be eliminated?
- This is not necessarily a finding — decomposition may be justified by token limits, specialisation benefits, or quality improvements. But the justification should be documented and testable.
- Severity: **P3** — a design question, not a defect.

**No confidence propagation**
- If any step produces a confidence score, is it consumed by downstream steps? A low-confidence output from an early step that flows through the chain with the same weight as a high-confidence output is context poisoning waiting to happen. Low confidence should trigger either re-execution, human review, or adjusted handling downstream.
- Severity: **P2** if confidence scores exist but are ignored downstream.

---

## Principle 8: Account for non-determinism — the same input will produce different output

*Carmack: "If you can't reproduce a bug, you can't fix it."*
*Willison: "Evals are the LLM equivalent of unit tests. Unfortunately LLMs are non-deterministic, so traditional unit tests don't really work." He cited research showing "the primary reason nearly all LLM inference endpoints are nondeterministic is that the load (and thus batch-size) nondeterministically varies." On test stability, he praised VS Code's approach: a "SQLite-based caching mechanism to cache the results of prompts from the LLM, which allows the test suite to be run deterministically."*

In chained pipelines, non-determinism compounds. Step 1 produces slightly different output on different runs. Step 2 receives different context. By the final step, the same input produces materially different results. This isn't a bug — it's the nature of the technology. The system must be designed around it.

### What to check

**Temperature not explicitly set**
- Is temperature explicitly configured for each LLM call, or left to provider defaults? Provider defaults vary across models and can change without notice. OpenRouter may apply different defaults than a direct API. For tasks where consistency matters (classification, scoring), temperature should be as low as possible. For tasks where variety may be desirable (generation, brainstorming), higher temperature may be appropriate.
- Severity: **P2** if temperature is not explicitly set on any LLM call.

**No caching for test stability**
- Can the test suite run deterministically? Willison endorsed caching LLM responses for tests — VS Code's approach of recording responses in SQLite. If tests make live LLM calls, they're non-deterministic, slow, and expensive. Mocked or cached responses enable reliable CI without masking real behavior.
- Severity: **P2** if pipeline tests require live LLM calls. **P3** if there are no pipeline-level tests at all (covered by Principle 5).

**No idempotency policy**
- If the same input is processed twice, should the results be identical? Different? Within a tolerance? If a classification step returns different labels on consecutive runs for the same input, the entire downstream output diverges. Is this expected, tolerated, or a defect? The answer is a product decision — but it should be a conscious one, not an accident.
- Severity: **P3** — a product decision, not a technical defect.

---

## Principle 9: Multimodal inputs require multimodal validation

*Carmack: "Every input is a potential source of errors."*
*Willison on vision models: "The usual LLM caveats apply. It can miss things and it can hallucinate incorrect details. Half of the work in making the most of this class of technology is figuring out how to work around these limitations." He documented GPT-4 Vision hallucinating entirely when given oversized images — "every detail on the page is wrong, clearly hallucinated. What went wrong here? It was the size of the image."*

Multimodal inputs (images, video, audio) introduce failure modes that text-only pipelines don't have: resolution-dependent hallucination, frame sampling artifacts, temporal confusion, and dramatically higher token costs. These inputs require their own validation.

### What to check

**Image/video resolution not validated**
- Willison documented that oversized images cause hallucination in vision models. Are visual inputs validated for resolution before being sent to the model? Are videos validated for length and frame rate? Unnecessarily high resolution wastes tokens without improving quality — and may actively degrade it.
- Gemini processes video at 66-258 tokens per frame depending on the model version. A 5-minute recording at 30fps is 9,000+ frames. Is the token cost estimated before the call is made?
- Severity: **P2** for no resolution/size validation on visual inputs.

**Video token cost not bounded**
- Video is orders of magnitude more expensive than text per semantic unit. Is there a maximum video length or frame count? Is the frame rate controlled to reduce token usage?
- **PROJECT OVERRIDE: This project does not impose artificial token budgets or cost caps on LLM calls.** We pay for quality. Do NOT recommend token budgets, cost caps, prompt length limits, or instruction-following degradation thresholds based on prompt size. If a prompt is too long, that's a prompt quality problem — fix the content, don't impose arbitrary ceilings.
- Severity: **Not a finding in this project.**

**No cross-validation between modalities**
- When a prompt includes both visual input (screenshot, video) and text input (scraped content, metadata), does the prompt establish which is ground truth? Willison's Gemini work consistently positions visual input as primary. If the visual and text inputs contradict each other, the model must resolve the conflict. Is the hierarchy explicit?
- Are outputs from multimodal steps validated for grounding in the visual input, not just the text? Hallucinated observations about visual content are harder to catch than hallucinated text analysis.
- Severity: **P3** — quality assurance, addressed more fully under Principle 5.

---

## Principle 10: Know your gaps — what this doc is weaker on

*Carmack: epistemic humility — you can't fix what you don't know is broken.*
*Willison: openly admits his eval practice is "still evolving" and calls evals and testing "the single hardest problem in AI engineering."*

### Areas this doc is weaker on (supplement from other sources)

- **Retry and circuit-breaker patterns for LLM APIs**: Willison has not written substantively about retry strategies, exponential backoff, or circuit breakers for LLM calls. For provider-level resilience patterns, supplement with Collina's async error handling principles (quality-backend.md).
- **Streaming and partial response handling**: Not a Willison focus area. If any LLM call uses streaming responses, the error handling model differs from batch calls and requires its own validation.
- **Fine-tuning and model customisation**: Willison covers general-purpose models. Fine-tuned models introduce different quality concerns (training data quality, overfitting, distribution shift).
- **Enterprise-scale cost management**: Willison's perspective is individual/small-team. For production cost monitoring at scale (budgets, alerts, anomaly detection on spend), supplement with standard observability practices.
- **Formal prompt injection mitigations**: Willison has documented the problem exhaustively but acknowledges solutions are immature. Google DeepMind's CaMeL is the most promising architecture, but Willison notes: "I still haven't seen a convincing implementation." For now, the best defense is limiting blast radius and cutting legs of the trifecta, not preventing injection outright.

---

## Quick Reference: Severity Guide

| Severity | Pattern | Examples |
|----------|---------|----------|
| **P1 — Fix Now** | Pipeline produces wrong results, silent failures, compounding errors | No parse validation on LLM output, upstream errors propagating unchecked, provider silently ignoring structured output enforcement |
| **P2 — Fix Soon** | Quality degradation, debugging difficulty, fragility | LLM call logging missing structural metadata, no token tracking, temperature not set, context accumulation across steps, no provider validation on fallback, no regression detection |
| **P3 — Consider** | Maturity gaps, architectural hygiene, conscious tradeoffs | No defined failure rates, generic context injection, no model abstraction layer, no idempotency policy, schema complexity, log storage efficiency |

### The Overriding Filter

**BEFORE ANYTHING ELSE:** This project has a no-premature-optimisation policy on LLM calls. Do NOT recommend: `max_tokens`/`maxOutputTokens` limits, prompt length budgets/gates/thresholds, token cost caps, instruction-following degradation thresholds based on prompt size, or output truncation. If you are about to write a finding about token limits, prompt length, or cost budgets — stop. It is not a finding in this project.

Before writing any finding, apply the Willison-Carmack synthesis:

1. **Is the LLM output validated before being used?** If not, flag it. (Both: if a mistake is possible, it will eventually happen.)
2. **Does structural separation affect output quality?** If instructions and data are interleaved in a way that confuses the model and degrades output, flag it. **Injection defense (escaping, guards, delimiter breakout) is Hunt's lane — do not flag.**
3. **Does each step see only what it needs?** If context snowballs, flag it. (Both: minimise what can go wrong.)
4. **Is there a way to know when quality degrades?** If no logging or evals, flag it. (Both: if you can't measure it, you can't improve it.)
5. **Can the pipeline survive a model or provider change?** If tightly coupled, flag it. (Willison: the best model changes every few months.)
6. **Are errors compounding across the chain?** If one step's mistake propagates unchecked to all downstream steps, flag it. (Both: assertions at every boundary.)