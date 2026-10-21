# Testing Guide

## What to Test

| Test | Don't Test |
|------|------------|
| Business logic and core algorithms | Framework internals |
| Edge cases and error handling | Getter/setter boilerplate |
| Integration points (API, DB, external) | Static types already caught by compiler |
| User-facing behavior | Implementation details |
| Regressions (bugs that were fixed) | Console.log output |

---

## Test Naming

Use descriptive names that read like documentation:

```text
Good:
  "returns empty array when no users match filter"
  "throws ValidationError when email is missing"
  "retries failed request up to 3 times"

Bad:
  "test1"
  "should work"
  "handles edge case"
```

Pattern: `<action> when <condition>` or `<expected result> given <input>`

---

## Test Structure

Every test follows Arrange-Act-Assert:

```text
// Arrange — set up test data and dependencies
// Act — call the function/endpoint
// Assert — verify the result
```

Keep each test focused on one behavior. If you need multiple asserts, they should all verify the same logical outcome.

---

## Mocking Strategy

### When to mock

| Mock | Don't Mock |
|------|------------|
| External APIs and services | The code you're testing |
| Database (in unit tests) | Pure utility functions |
| File system (in unit tests) | Data transformations |
| Time/date (when determinism needed) | Simple dependencies with no side effects |

### When to use real dependencies

- Integration tests should use real DB (test database)
- E2E tests should use real services where possible
- If mocking makes the test harder to understand, use real

### Mock principles

- Mock at the boundary, not deep inside
- Verify mock interactions only when the interaction IS the behavior
- Reset mocks between tests
- Prefer dependency injection over monkey-patching

---

## Test Organization

```text
tests/
  unit/              # Fast, isolated, no I/O
    user.test.ts
    cart.test.ts
  integration/       # Real DB, real filesystem
    api.test.ts
    auth.test.ts
  e2e/               # Full application, browser/HTTP
    checkout.test.ts
```

Or co-locate with source:

```text
src/
  user/
    user.service.ts
    user.service.test.ts
```

Pick one pattern per project. Don't mix.

---

## Coverage

- Aim for meaningful coverage, not 100%
- Cover happy path + main error paths + edge cases
- Uncovered code is fine if it's trivial (type definitions, re-exports)
- A test that only exists to hit a coverage number is worse than no test

---

## Test-First

The test comes before the code it tests. Three rules, in order:

1. No production code until a failing test asks for it
2. No more test than it takes to fail
3. No more production code than it takes to pass that test

This is a loop measured in minutes, not a phase. What it buys is a definition of
done you can run: **the task is finished when every test on the list is green,
not when the edits stop.**

### The test list

Before writing code, write the list of tests — one line each, named for the
behaviour they pin down. Keep it in the plan (`agent_docs/workflow.md` → the
`### Tests` block). Add to it whenever the work turns up a case you hadn't
thought of; cross off as each goes green. The list empty is the session over.

Each test should fail on the current tree, and you should watch it fail. A test
you never saw red is a test you have no reason to trust.

### Three ways to get to green

Pick the cheapest one that works, and take the next one when it doesn't:

- **Fake It** — return the constant the test expects. Then write a second test
  the constant can't satisfy (**Triangulate**) and let the real implementation
  fall out.
- **Obvious Implementation** — when you already know the four lines, write them.
  If the test goes red twice in a row, stop guessing and go back to Fake It.

**For an agent, Fake It is the trap, not the shortcut.** Faking it is only
legitimate with a red test on screen that the fake turns green and a second test
queued to break it. A function that returns the right constant with no failing
test behind it is not Fake It — it is a stub reported as an implementation, and
it is the single most common way a task looks done and isn't.

### A bug fix is the special case

Same loop, and the first test is the reproduction: write the test that fails
because of the bug, confirm it fails for *that* reason and not a typo, fix,
confirm green. The test then stays forever as the regression guard.

> _Supported via_ `.claude/hooks/test-first.sh` _— a source file edited with no
> test file behind it is flagged once, through context, never blocking. Under the
> strict profile (_`CCK_TEST_FIRST=strict`_)_ `.claude/hooks/test-first-gate.sh`
> _turns that into a block on Stop until the test exists. Both re-check the disk,
> so a test written by any means settles it;_ `SKIP_TEST_FIRST=1` _is the escape
> for a refactor, a spike, or tests the hook can't see._

---

## Red Flags in Tests

| Smell | Problem |
|-------|---------|
| Test is longer than the code it tests | Over-testing or testing implementation |
| Test breaks when refactoring (but behavior unchanged) | Testing implementation, not behavior |
| Test passes when the code is clearly broken | Not asserting the right thing |
| Function returns a constant and no test ever went red for it | Fake It without the red bar — a stub shipped as done |
| Test requires complex setup (50+ lines of arrange) | Code under test has too many dependencies |
| Test uses `sleep()` or arbitrary delays | Race condition in test, use proper async |
| Test only runs in specific order | Shared mutable state between tests |
