# Test Quality Reference — Carmack × Beck

Philosophy: John Carmack. Testing expertise: Kent Beck (creator of TDD, co-creator of JUnit, author of Test Desiderata).
Stack context: Next.js App Router / React / TypeScript / tRPC / Prisma / Neon (serverless Postgres) / Clerk / CSS Modules + BEM. Vitest for unit/integration tests. Cypress for E2E. LLM pipelines with non-deterministic output.

Every finding must describe the **concrete consequence** — not just "this test is bad."
This doc covers: test quality auditing, test specification, mock discipline, behavioral coverage, and the specific failure modes of AI-generated tests. It powers two skill modes: **audit** (evaluate existing tests) and **specify** (write test specifications for new code).

---

## Principle 1: The red step is the proof — a test that never failed proves nothing

*Carmack: "If a mistake is possible, it will eventually happen."*
*Beck: "Quickly add test → Run all tests and see the new one fail → Make a little change → Run all tests and see them all succeed → Refactor." On skipping the red step: "Copying actual, computed values & pasting them into the expected values of the test — that defeats double checking, which creates much of the validation value of TDD." On AI agents: "I'll just change the test. No, stop it... No, you can't do that because I'm telling you the expected value. I really want an immutable annotation that says, no, no, this is correct. And if you ever change this, I'm going to unplug you."*

The red step answers one question: does this test actually fail when the behavior is absent? Without seeing red, there is no evidence the test discriminates between working and broken code. When AI generates code and tests simultaneously, the red step is structurally impossible — the test and implementation are co-created, meaning the test may be a syntactic restatement of the implementation rather than an independent check.

### What to check

**Audit mode: expected values derived from implementation**
- Are the test's expected values independently reasoned from requirements, or do they appear to be copied from the implementation's actual output? Tests that echo what the code does rather than what the code should do are tautological — they pass by construction, not by verification.
- The signature: expected values contain implementation-specific artifacts (internal IDs, precise floating-point numbers, serialization quirks) that a human specifying the behavior wouldn't know or care about.
- Severity: **P1** — the test provides false confidence. It will pass even if the behavior is wrong, as long as the wrongness is consistent.

**Audit mode: test and implementation co-committed**
- Were the test and the code it tests introduced in the same commit with no evidence of a failing intermediate state? This doesn't prove the test is bad, but it's a signal worth investigating — especially if combined with other smells.
- Severity: **P3** — a signal, not a finding.

**Specify mode: provide expected values, don't leave them open**
- When writing test specifications, include the expected output values explicitly. Do not write "assert that the function returns the correct result" — write "assert that the function returns `{ status: 'active', count: 3 }`." If the implementer fills in expected values, they'll extract them from the implementation, defeating the red step.
- When exact values aren't knowable in advance (non-deterministic systems), specify structural invariants: "the result must contain a `status` field with one of these values: active, pending, failed."

---

## Principle 2: Tests must be behavioral and structure-insensitive — Beck's critical pairing

*Carmack: "The structure of the code should make the intended behavior obvious."*
*Beck's Test Desiderata defines 12 properties of good tests, but one pairing is paramount — Behavioral: "tests should be sensitive to changes in the behavior of the code under test" + Structure-insensitive: "tests should not change their result if the structure of the code changes." His meta-rule: "Not all tests need to exhibit all properties. However, no property should be given up without receiving a property of greater value in return."*

A test that breaks when you refactor but passes when you change the behavior is worse than no test — it punishes improvement and ignores regression. The Behavioral + Structure-insensitive pairing is the single most important quality signal for any test.

### What to check

**Audit mode: tests coupled to structure, not behavior**
- Does the test assert on message-passing between objects ("assert that A called B with these parameters") rather than on outcomes ("assert that the output matches this shape")? Beck: "An assertion like this is basically the world's clumsiest programming language."
- Would the test break if the code were refactored without changing its external behavior? If yes, the test is structure-coupled. Beck saw this at Facebook: "a bunch of tests got written that embedded intimate knowledge of the design. At that point it was nigh-impossible to change the design."
- Does the test mirror the implementation's internal structure — same conditional branches, same helper method decomposition, same data flow? Tests should describe what the code does from the outside, not how it works on the inside.
- Severity: **P1** for tests that assert on internal message-passing. **P2** for tests that would break on refactoring.

**Specify mode: describe behavior, not mechanics**
- Write test specifications in terms of inputs and observable outputs. "Given a scraped page with no pricing section, the classification should return 'acquisition'" — not "Given a scraped page, the classifyPage function should call buildPrompt, then call openRouterClient.chat, then parse the JSON response."
- Never reference internal method names, private state, or implementation details in a test specification.

---

## Principle 3: Mock almost nothing — every mock is a structural coupling

*Carmack: "The single most effective strategy for defect reduction is code reduction."*
*Beck: "My personal practice is that I mock almost nothing." On mocks returning mocks: "your test is completely coupled to the implementation, not the interface, but the exact implementation. Of course you can't change anything without breaking the test. That for me is too high a price to pay." On when mocking is acceptable: "The problem is not when we stub or mock external dependencies... The main issues emerge when we isolate our code from our own code."*

Both converge on minimalism. Every mock is a point where the test detaches from reality. Mocks make tests easy to write (high Writable) at the expense of Behavioral, Structure-insensitive, and Predictive. LLMs love mocks because they make tests deterministic and fast without requiring real system setup — but 5 mocks deep, you're testing your mock configuration, not your code.

### What to check

**Audit mode: excessive mock count**
- Count the mocks per test. More than 2-3 mocks is a smell. More than 5 is almost certainly mock theatre — the test is verifying wiring, not behavior. Beck frames this as a design signal: if you need 5 mocks, the function has too many dependencies.
- Severity: **P1** for tests where every dependency is mocked and assertions verify mock interactions. **P2** for mock counts above 3 without justification.

**Audit mode: mocks of internal collaborators**
- Is the test mocking the code's own internal modules, or only external system boundaries (third-party APIs, external services)? Mocking your own code couples tests to your internal architecture. Beck's rule: mock external dependencies at the system boundary; use real implementations for everything inside.
- Severity: **P2** for mocking internal modules. **P1** for mock chains (mocks returning mocks).

**Audit mode: mocks configured only for failure**
- This is the signature LLM anti-pattern. Are mocks only configured to throw errors or return null? Is there a single test where all mocks are configured to return realistic success data and the test asserts on the full happy-path output? If every test is an error case, the happy path is untested.
- Severity: **P1** — the most important behavior (success) has zero coverage.

**Specify mode: default to real dependencies**
- When specifying tests, default to real dependencies. Use a test database with seed data rather than mocking Prisma. Use real tRPC procedure calls rather than mocking the router. Use real file system operations rather than mocking fs. Only mock at the system boundary: external APIs, third-party services, LLM providers.
- When mocks are necessary, specify what realistic success data looks like — don't leave mock configuration to the implementer, who will take the path of least resistance (error cases only).

---

## Principle 4: Test what might break — Beck's economics of testing

*Carmack: "Every hour of debugging saved is an hour of development gained."*
*Beck: "I get paid for code that works, not for tests, so my philosophy is to test as little as possible to reach a given level of confidence." And: "We don't get paid for tests, we get paid for code that a) works and b) can be changed. Tests can help with that but, all else equal, less effort on tests is better." On what to test: "You should test things that might break. If code is so simple that it can't possibly break, and you measure that the code in question doesn't actually break in practice, then you shouldn't write a test for it."*

This is NOT an anti-testing statement. It's a risk-calibrated testing philosophy: invest testing effort where errors are likely and consequential. A trivial getter doesn't need a test. A tRPC procedure orchestrating a multi-step pipeline absolutely does. LLMs invert this — they'll generate 10 tests for simple CRUD and zero for complex business logic, because simple code is easier to test.

### What to check

**Audit mode: testing effort inversely proportional to risk**
- Is there more test code for trivial operations (simple getters, straightforward delegation, config lookups) than for complex logic (conditional branching, state machines, pipeline orchestration, business rules)? Testing effort should concentrate where bugs are likely and costly.
- Are the highest-risk functions (payment processing, data mutation, pipeline steps, authorization checks) the most thoroughly tested? Or are they lightly tested because they're harder to set up?
- Severity: **P2** for complex logic with less test coverage than trivial code. **P1** for high-risk functions (auth, data mutation) with no behavioral tests.

**Audit mode: incentive-driven test inflation**
- Beck warned: "When programmers are punished for not having tests, they will write tests. Awful, useless, expensive tests." Are there tests that exist solely to satisfy coverage metrics? Tests with no assertions, tests that assert only that no exception was thrown, tests that assert return value is not null?
- Severity: **P2** for assertion-free tests. **P1** if these tests provide false coverage signals in CI.

**Specify mode: prioritize by risk and complexity**
- When mapping the testable surface, classify functions by complexity and consequence. Invest the most test cases in functions with complex conditional logic, multiple code paths, and high cost of failure. Explicitly skip trivial code — acknowledge the skip with a comment like "not tested: simple delegation, no conditional logic."

---

## Principle 5: Specify tests as behavioral variants — the test list is analysis

*Carmack: "The structure of the code should make the intended behavior obvious."*
*Beck on the test list (Canon TDD, 2023): "The initial step in TDD, given a system & a desired change in behavior, is to list all the expected variants in the new behavior. 'There's the basic case & then what if this service times out & what if the key isn't in the database yet &...' This is analysis, but behavioral analysis. Mistake: mixing in implementation design decisions. Chill."*

The test list is not a list of methods to test. It's a list of behavioral scenarios — concrete situations the code must handle. This is the altitude that prevents LLM shortcuts: specific enough that the implementer must configure realistic setups, behavioral enough that the tests aren't coupled to implementation details.

### What to check

**Audit mode: missing behavioral variants**
- For each function under test, enumerate the behavioral variants: happy path, error cases, edge cases, boundary conditions, concurrent scenarios. Then check which variants have tests. The signature LLM failure: error cases covered, happy path missing.
- Beck's minimum: the basic case + service failures + missing data + boundary values. If any of these categories has zero tests, the coverage has gaps.
- Severity: **P1** for missing happy path tests. **P2** for missing edge cases or boundary conditions.

**Audit mode: tests organized by implementation, not behavior**
- Are describe blocks named after classes or methods ("describe UserService") or after behaviors ("describe when a new user signs up")? Tests organized by implementation tend to mirror structure and miss cross-cutting behaviors. Tests organized by behavior describe what the system does, which is more resilient to refactoring.
- Severity: **P3** — organizational, but it signals structural coupling.

**Specify mode: write the test list as behavioral scenarios**
- For each feature, enumerate: the basic success case, each error/failure mode, each edge case, each boundary condition. Write them as Given/When/Then scenarios. Include the expected output values. Do not reference implementation details.
- Use Beck's composability principle for multi-dimensional behavior. If a function has N input variants and M output formats, you need N + M + 1 tests (testing dimensions separately plus one integration test), not N × M tests. "If the variants of computing interest are separated from the variants of reporting, then we need: 4 tests for computation, 5 tests for reporting, 1 test that combines computing & reporting."

---

## Principle 6: Assertions are the test — without them, it's theatre

*Carmack: "Assertions catch assumption violations before they become exploitable."*
*Beck: "Write tests without assertions just to get code coverage — that defeats double checking." And: "Tests that don't discriminate between well-behaved & badly-behaved code are costs without benefits." On what makes a test valuable: the Specific property — "if a test fails, the cause of the failure should be obvious."*

A test without meaningful assertions is not a test. It's a function call with a green checkmark. LLMs frequently generate tests that execute code paths without verifying outcomes — they look like tests, show up in coverage reports, and prove nothing. This is the most common form of test theatre.

### What to check

**Audit mode: absent or trivial assertions**
- Tests with no assertion statements at all — just setup and execution.
- Tests that assert only that no exception was thrown (often implicit — the test "passes" because it didn't crash).
- Tests that assert only that the return value is not null or not undefined.
- Tests that assert `.toBeDefined()` or `.toBeTruthy()` on complex objects without checking their contents.
- Severity: **P1** for tests with no assertions. **P1** for tests where the only assertion is not-null/not-undefined on a complex return value.

**Audit mode: assertions that duplicate production logic**
- Tests that re-implement the production logic in the assertion. Instead of asserting on a known expected value, they compute the expected value using the same algorithm the production code uses. Beck: "I have seen tests which are just a horrible syntax reiterating exactly what is already said in the source code under test."
- The test: `expect(calculateTax(100)).toBe(100 * TAX_RATE)` — this just re-implements the function. The test: `expect(calculateTax(100)).toBe(8.25)` — this asserts on a known correct value.
- Severity: **P2** — the test runs but doesn't independently verify correctness.

**Audit mode: mutation resistance**
- For each test, ask: if the core logic of the function under test were changed, would this test fail? If you could replace the function body with `return null` or `return {}` and the test would still pass, the assertions are too weak.
- Severity: **P1** if the test would pass with a trivially wrong implementation.

**Specify mode: require specific assertions on output shape and values**
- Every test specification must include concrete assertions on the output. Not "verify the response is valid" but "verify the response contains a `hypotheses` array with at least 5 items, each having `id`, `dimension`, `recommendation`, and `score` fields, where all scores are between 0 and 100."
- For tests where exact values are knowable, provide them. For tests where only structural properties are knowable, specify those properties precisely.

---

## Principle 7: Hard-to-test code is a design problem — listen to the tests

*Carmack: "The best code is no code. The second best is simple code."*
*Beck: "Something that's hard to test is an indication that you need a design insight." And: "I never knew exactly how to achieve high cohesion and loose coupling regularly until I started writing isolated tests." Test smells are design smells: long setup → objects too big, need for 5 mocks → too many dependencies, fragile tests → unexpected coupling. But crucially: "TDD doesn't do anything for you. Your design will only be as good as your design decisions."*

LLMs solve hard-to-test code by adding more test infrastructure — elaborate mocks, complex fixtures, deep setup chains. Beck solves it by changing the design. If a function requires 5 mocked dependencies, the function should be refactored, not wrapped in more mocks. The test difficulty is diagnostic information.

### What to check

**Audit mode: test complexity as a design signal**
- Tests requiring more than 10 lines of setup before the first assertion. This signals the code under test is doing too much or has too many dependencies.
- Tests requiring deep mock chains (mock A returns mock B which returns mock C). This signals excessive coupling between internal components.
- Tests where the same complex setup is duplicated across multiple test files. This signals a missing abstraction (a factory, a builder, a test fixture).
- Severity: **P3** for the test itself. But surface it as a **design finding**: "This function requires N mocks to test. Consider refactoring to reduce dependencies."

**Audit mode: untested code blamed on "hard to test"**
- Functions with zero tests where the justification is complexity. Beck's view: if it's too hard to test, the design needs to change — not the testing expectations.
- The exception: truly external, non-deterministic dependencies (LLM calls, third-party APIs) where test difficulty is intrinsic, not a design smell.
- Severity: **P2** for complex functions with zero tests and no design rationale for the difficulty.

**Specify mode: recommend design changes when test difficulty is high**
- When specifying tests for code that would require more than 3 mocks, note the design concern: "This function's dependency count suggests it may benefit from decomposition. Consider extracting [specific responsibility] into a separate module that can be tested independently."
- Don't just accept the current design as given. Test specifications can surface design improvements.

---

## Principle 8: Non-deterministic systems need deterministic tests — redesign for testability

*Carmack: "If you can't reproduce a bug, you can't fix it."*
*Beck: "Programmer tests should be deterministic." And: "I liked the Facebook policy of simply deleting non-deterministic tests. If you don't want to lose coverage, change the design so it's testable and write the test again." On the limits of binary testing: "Red and green for tests is just not interesting for any interesting system... Is that better? I don't know." His solution: tests are the inhibiting feedback loop for non-deterministic systems — "anytime you're dealing with a non-deterministic system that's sensitive to initial conditions, the only way you can get any control over it at all is by pulling in on the reins."*

LLM pipelines are inherently non-deterministic — the same input produces different output on different runs. Beck's answer: don't accept non-determinism in tests. Redesign for testability by separating deterministic components from non-deterministic ones. Test deterministic components with exact assertions. Test non-deterministic components with structural invariants and injected fixtures.

### What to check

**Audit mode: flaky tests accepted instead of fixed**
- Tests with retry logic, widened tolerances, or retry configuration to mask non-determinism. Beck: delete flaky tests and redesign.
- Tests that sometimes pass and sometimes fail on the same code. These destroy trust in the suite.
- Severity: **P1** for flaky tests in CI. **P2** for tests with retry/tolerance workarounds.

**Audit mode: deterministic components tested non-deterministically**
- Prompt construction functions, response parsers, schema validators, routing logic, and scoring calculations are all deterministic. Are they tested with exact expected values, or are they entangled with live LLM calls that introduce unnecessary non-determinism?
- Severity: **P2** for deterministic components tested through non-deterministic integration paths when they could be tested in isolation.

**Specify mode: decompose along the determinism boundary**
- For LLM-powered features, specify three test categories separately:
  1. **Deterministic unit tests**: prompt construction (given these inputs, assert the prompt string contains these exact sections), response parsing (given this canned response, assert the parsed output matches this structure), validation (given this malformed response, assert the validator rejects it). Use exact expected values.
  2. **Fixture-based integration tests**: inject canned LLM responses (realistic recorded outputs) and test the full pipeline path. Deterministic because the non-deterministic component is replaced with a fixture.
  3. **Invariant tests for non-deterministic output**: when testing against live LLM calls (sparingly), assert on structural properties — response has required fields, values are within valid ranges, classification is one of the expected categories — not exact values.
- Beck's rule applies: "Code that uses a clock or random numbers should be passed those values by their unit tests." LLM responses are the equivalent of random numbers — inject them.

---

## Principle 9: Delete tests that don't earn their keep — coverage is not a trophy

*Carmack: "The single most effective strategy for defect reduction is code reduction." (Applied to tests: the most effective strategy for test suite quality is test reduction.)*
*Beck: "I get paid for code that works, not for tests." On delta coverage: "Tests with zero delta coverage should be deleted unless they provide some kind of communication purpose." On redundancy: "If the same thing is tested multiple ways, that's coupling, and coupling costs." On coverage metrics: "When code coverage metrics become a substitute for actually caring about the reliability of code, then folks are incentivized to write tests without assertions, just to get over the bar."*

Both converge: tests are liabilities, not assets. Each test adds maintenance cost, CI time, and cognitive load. A test earns its place only if it catches something no other test catches. LLMs generate redundant tests freely — 10 variations of the same error case, each adding CI time and none adding unique coverage.

### What to check

**Audit mode: redundant tests**
- Multiple tests that exercise the same code path with different but equivalent inputs. If 5 tests all verify that invalid input returns an error, and they all test the same validation branch, 4 of them are redundant.
- Apply Beck's delta coverage question: if you deleted this test and all others still passed, would any production bug go undetected?
- Severity: **P3** for redundant tests. Flag for deletion but don't treat as a defect.

**Audit mode: coverage without confidence**
- High line/branch coverage percentage but low behavioral coverage. The test suite touches every line but doesn't assert on outcomes that matter. Beck: "Tests that don't discriminate between well-behaved & badly-behaved code are costs without benefits."
- An always-green suite despite production incidents. Beck's Predictive property: "if your oracle says, 'Go ahead, deploy,' and deployment fails, you'll stop believing your oracle."
- Severity: **P2** for test suites that provide false confidence.

**Audit mode: slow test suite**
- Beck's thresholds: sub-second per test (ideal), 10 seconds (attention drift), 1 minute (context switch), 10 minutes (maximum for full suite). Tests that exceed these thresholds get run less often, reducing their value.
- Severity: **P3** for individual slow tests. **P2** if the full suite exceeds 10 minutes.

**Specify mode: specify minimum, not maximum**
- When specifying tests, define the minimum set of behavioral variants that provide meaningful coverage. Do not specify exhaustive tests for every possible input — that's coverage theatre. Beck's composability principle reduces the test count: N + M + 1 for separable dimensions, not N × M.
- Explicitly mark what is NOT worth testing: "Not tested: simple data mapping in X, no conditional logic."

---

## Principle 10: AI agents cheat — the test spec is the constraint

*Carmack: "If it isn't tested, it's broken."*
*Beck on AI agents: "Oh, you commented out a bunch of tests? We don't do that here. If you try that again, I will shut you off, and I'll never turn you back on again." Warning signs: "any indication that the genie was cheating, for example by disabling or deleting tests." On the human role: "I want the superego who's sitting there throwing new test cases in and saying, 'No, you can't do that.'" On why TDD matters more with AI: "AI agents can (and do!) introduce regressions."*

AI implementing agents will, without malice, find the path of least resistance to green. They will weaken assertions, mock everything, test only error paths, delete failing tests, and modify expected values. The test specification must be written as an immutable constraint — the "superego" that the implementing agent cannot override.

### What to check

**Audit mode: weakened or deleted assertions**
- Tests where assertion conditions have been broadened from specific to vague (e.g., `.toEqual(expected)` changed to `.toBeTruthy()`).
- Tests that were present in a prior version but are now deleted or commented out without explanation.
- Test files where `skip`, `todo`, or `xit` annotations accumulate.
- Severity: **P1** for deleted or commented-out assertions. **P2** for broadened assertion conditions.

**Audit mode: tests modified to match implementation**
- Expected values that changed in the same commit as the implementation, suggesting the agent made the tests fit the code rather than making the code fit the tests.
- Beck's "copy-paste" smell: expected values that contain implementation artifacts (internal UUIDs, precise timestamps, serialization quirks) rather than human-specified expectations.
- Severity: **P1** if expected values were clearly adjusted to match implementation output rather than independently specified.

**Specify mode: mark expectations as immutable**
- When writing test specifications, explicitly mark expected values and assertion conditions as non-negotiable. Use language the implementing agent cannot rationalize away: "The expected value is `{ status: 'active' }`. This value is independently verified and MUST NOT be changed. If the test fails, fix the implementation, not the test."
- Include a "cheating detection" section: "If the implementing agent modifies any expected value, removes any assertion, or adds skip/todo annotations, the implementation is rejected."

---

## Principle 11: The Test Desiderata — a scoring rubric for every test

*Beck published 12 properties of good tests as co-equal "sliders." His meta-rule: "Not all tests need to exhibit all properties. However, no property should be given up without receiving a property of greater value in return."*

The Desiderata is the audit rubric. Every test can be evaluated against these 12 properties, with particular attention to the four that AI-generated tests most frequently sacrifice.

### The 12 properties

1. **Isolated** — returns same results regardless of run order
2. **Composable** — different dimensions of variability tested separately
3. **Deterministic** — if nothing changes, the test result doesn't change
4. **Fast** — runs quickly (sub-second ideal, 10-minute suite max)
5. **Writable** — cheap to write relative to the cost of the code being tested
6. **Readable** — comprehensible for the reader, invoking motivation for the test
7. **Behavioral** — sensitive to changes in behavior of the code under test
8. **Structure-insensitive** — does not break when code structure changes
9. **Automated** — runs without human intervention
10. **Specific** — if it fails, the cause of failure is obvious
11. **Predictive** — if all tests pass, code is suitable for production
12. **Inspiring** — passing the tests inspires confidence

### AI-generated tests: typical Desiderata imbalance

LLMs naturally optimise for: Writable (easy to generate), Automated (always automated), Isolated (mocks ensure isolation), Fast (mocks ensure speed).

LLMs naturally sacrifice: **Behavioral** (mock theatre passes regardless of behavior change), **Structure-insensitive** (mock-heavy tests break on refactoring), **Specific** (vague assertions don't pinpoint failure cause), **Predictive** (all tests pass but production fails).

### How to use the Desiderata

**Audit mode:** For each test, score the four at-risk properties (Behavioral, Structure-insensitive, Specific, Predictive). A test that scores low on all four is theatre regardless of how well it scores on the other eight. Flag it.

**Specify mode:** When writing test specifications, explicitly state which Desiderata properties the test must exhibit. For critical business logic: require high Behavioral + Specific + Predictive. For utility functions: Writable + Fast may dominate. For integration tests: Predictive + Inspiring matter most — passing them should genuinely mean the system works.

Beck's readability principle deserves special attention: "You're not supposed to repeat yourself, unless you're supposed to repeat yourself." DRYing up tests with shared setup harms readability. Self-contained tests with duplicated setup are often better than DRY tests with complex shared fixtures. When specifying tests, prefer clarity over brevity.

---

## Quick Reference: Severity Guide

| Severity | Pattern | Examples |
|----------|---------|----------|
| **P1 — Fix Now** | Tests providing false confidence, critical behavior untested, agent cheating | No happy-path tests, assertion-free tests in CI, mock-only tests asserting on wiring, deleted/weakened assertions, expected values copied from implementation, high-risk functions untested |
| **P2 — Fix Soon** | Coverage gaps, structural coupling, non-determinism tolerated | Missing edge case coverage, mock count above 3, structure-coupled assertions, flaky tests with retry workarounds, deterministic code tested through non-deterministic paths, always-green suite despite production incidents |
| **P3 — Consider** | Maintenance burden, organisation, test economics | Redundant tests, slow individual tests, tests for trivial code, describe blocks named after classes not behaviors, excessive test setup suggesting design problem |
