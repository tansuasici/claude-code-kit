---
name: debug
description: Systematic root-cause debugging with evidence-before-fix enforcement and regression test generation
user-invocable: true
---

# Debug

## When to Use

Invoke with `/debug` when:

- A bug has been reported or observed and needs systematic investigation
- A test is failing and the cause isn't obvious
- Something "just stopped working" and you need to find out why
- Previous fix attempts haven't resolved the issue
- You want to ensure the fix includes a regression test

## Process

### Phase 1: Reproduce

Before investigating, establish a reliable reproduction:

1. **Get the symptoms** — exact error message, stack trace, unexpected behavior
2. **Get the trigger** — what action causes the bug? What input?
3. **Reproduce locally** — can you make it happen on demand?
4. **Identify consistency** — does it always happen, or is it intermittent?

If you cannot reproduce the bug, do NOT guess at fixes. Instead, add logging/instrumentation to gather more data.

### Phase 2: Hypothesize

Form hypotheses based on evidence, not intuition:

1. **Read the error** — what does the error message actually say?
2. **Read the stack trace** — where exactly does it fail?
3. **Check recent changes** — `git log --since='3 days ago'` — did something change?
4. **Form 2-3 hypotheses** — rank by likelihood

```markdown
### Hypotheses
1. [Most likely] — DB query returns null when user has no orders → NPE on line 45
2. [Possible] — Race condition between auth check and data fetch
3. [Less likely] — Timezone mismatch in date comparison
```

### Phase 3: Investigate

Test each hypothesis systematically:

1. **Start with the most likely hypothesis**
2. **Gather evidence** — read the relevant code, check logs, add temporary logging
3. **Narrow the scope** — binary search: which layer? which function? which line?
4. **Confirm or reject** — does the evidence support this hypothesis?
5. **Move to next hypothesis** if rejected

**Rules:**
- Do NOT fix anything yet — investigation only
- Do NOT change code to "see if this helps"
- Every investigation step must produce evidence
- If you're guessing, you don't understand the bug yet

### Phase 4: Root Cause

Document the confirmed root cause:

```markdown
### Root Cause
**What**: [one sentence description]
**Where**: [file:line]
**Why**: [why does this code behave this way?]
**When**: [under what conditions does this trigger?]
**Evidence**: [how we confirmed this is the cause]
```

The root cause must explain ALL observed symptoms. If it doesn't, keep investigating.

### Phase 5: Fix

Only after root cause is confirmed:

1. **Design the fix** — what's the minimal change that addresses the root cause?
2. **Check for related issues** — does this bug exist elsewhere? (same pattern in other files)
3. **Implement the fix** — one focused change
4. **Verify the fix** — reproduce the original bug → confirm it's gone
5. **Check for regressions** — run the full test suite

**Rules:**
- One fix per commit
- Fix the root cause, not the symptom
- Don't refactor surrounding code in the same commit
- If the fix is complex, explain why in the commit message

### Phase 6: Regression Test

Write a test that:

1. **Fails without the fix** — reproduces the exact bug scenario
2. **Passes with the fix** — confirms the fix works
3. **Tests the edge case** — not just the happy path
4. **Is named descriptively** — describes the bug scenario, not the fix

```text
test("returns empty array when user has no orders instead of throwing NPE")
```

## Output Format

```markdown
# Debug Report

## Bug
**Symptom**: [what the user sees]
**Trigger**: [what action causes it]
**Reproducible**: Yes/No/Intermittent

## Investigation
### Hypothesis 1: [description]
- Evidence: [what we checked]
- Result: Confirmed / Rejected

### Hypothesis 2: [description]
- Evidence: [what we checked]
- Result: Confirmed / Rejected

## Root Cause
**What**: [description]
**Where**: file:line
**Why**: [explanation]
**Evidence**: [how we confirmed]

## Fix
**Change**: [description of the fix]
**Files**: [modified files]
**Commit**: [commit hash]

## Regression Test
**Test**: [test name and location]
**Verifies**: [what the test checks]

## Related Issues
- [Other places this pattern exists, if any]
```

## Common Error Patterns

Use these language-specific patterns to accelerate hypothesis formation. Focus on errors that are frequently misdiagnosed or waste investigation time.

### Python

| Error | Common Root Cause |
|---|---|
| `ImportError` / `ModuleNotFoundError` | Venv not activated, missing `pip install`, missing `__init__.py` |
| `TypeError: X got an unexpected keyword argument` | Function signature changed, wrong overload |
| `AttributeError: 'NoneType'` | Upstream query returned None, missing null check |
| Django `OperationalError: no such table` | Missing migration — run `makemigrations` + `migrate` |
| `RecursionError: maximum recursion depth` | Circular import or unintended self-call |

### TypeScript / JavaScript

| Error | Common Root Cause |
|---|---|
| `TS2322: Type X is not assignable to type Y` | Missing generic param, null not in union, async return type |
| `Cannot find module` | tsconfig `paths` misconfigured, missing `package.json` exports field |
| Next.js hydration mismatch | Server/client component boundary issue, browser-only API in SSR |
| `TypeError: X is not a function` | Default vs named export mismatch, circular dependency |
| `Unhandled Promise Rejection` | Missing `await`, swallowed catch, fire-and-forget async |

### Go

| Error | Common Root Cause |
|---|---|
| `undefined: X` | Unexported (lowercase) identifier, missing import, wrong build tag |
| `cannot use X as type Y` | Interface not satisfied — check method signature and pointer receiver |
| `fatal error: concurrent map writes` | Shared map without mutex — use `sync.Map` or add locking |
| `context deadline exceeded` | Upstream timeout — check context propagation chain |

### Rust

| Error | Common Root Cause |
|---|---|
| `borrow of moved value` | Use `clone()`, pass reference, or restructure ownership |
| `lifetime does not live long enough` | Add explicit lifetime annotations or restructure to avoid references |
| `the trait X is not implemented for Y` | Missing `derive`, wrong generic bounds, need `impl` block |
| `cannot borrow as mutable more than once` | Split borrows or use `RefCell` / `Cell` for interior mutability |

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I know what the bug is, I'll just fix it" | Reproduce first. Assumption-based fixes are wrong ~30% of the time and create new bugs. |
| "The failing test is probably wrong" | Read the test. If it's wrong, fix it. If it's right, fix your code. Never skip. |
| "It works locally, CI must be flaky" | Environments differ. Reproduce in CI conditions before dismissing. |
| "I'll add logging later" | Intermittent bugs without logging become permanent mysteries. Add instrumentation now. |
| "The stack trace points to X, so X is broken" | Stack traces show where the error surfaces, not where it originates. Trace upstream. |

## Notes

- The #1 rule: **no fix without confirmed root cause** — guessing leads to patches that mask bugs
- Evidence-before-fix is non-negotiable — if you can't explain why the fix works, you don't understand the bug
- Intermittent bugs need more logging, not more guessing — add instrumentation first
- If the bug is in a dependency, document the workaround and file an upstream issue
- Each debug session should improve the codebase's debuggability (better error messages, logging, assertions)
