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

```
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

```
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

```
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

```
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

## Writing Tests for Bug Fixes

When fixing a bug:

1. **Write a failing test first** that reproduces the bug
2. Verify the test fails for the right reason
3. Fix the bug
4. Verify the test passes
5. The test stays forever — it prevents regression

---

## Red Flags in Tests

| Smell | Problem |
|-------|---------|
| Test is longer than the code it tests | Over-testing or testing implementation |
| Test breaks when refactoring (but behavior unchanged) | Testing implementation, not behavior |
| Test passes when the code is clearly broken | Not asserting the right thing |
| Test requires complex setup (50+ lines of arrange) | Code under test has too many dependencies |
| Test uses `sleep()` or arbitrary delays | Race condition in test, use proper async |
| Test only runs in specific order | Shared mutable state between tests |
