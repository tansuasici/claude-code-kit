# Debugging Protocol

## The 4-Step Loop

```text
Reproduce → Isolate → Fix → Verify
```

Never skip steps. Never guess-fix without reproducing first.

---

## Step 1: Reproduce

Before touching any code, confirm the bug exists and is consistent.

- Run the exact command/action that triggers the bug
- Note the exact error message, stack trace, or wrong behavior
- Confirm it's reproducible (not a one-time flake)

If you can't reproduce it, you can't fix it. Ask for more context.

---

## Step 2: Isolate

Find the smallest scope that contains the bug.

**Strategy: Binary search the codebase**

1. Identify the entry point (API route, CLI command, UI action)
2. Trace the execution path
3. Add targeted logging or read the code at each layer
4. Narrow down to the exact file, function, and line

**Common isolation techniques:**

| Technique | When to use |
|-----------|-------------|
| Read the stack trace | Error with traceback |
| Add console.log / print at boundaries | Silent wrong behavior |
| Comment out suspect code | Narrowing down cause |
| Check git blame / recent changes | "This used to work" |
| Test with minimal input | Complex input scenarios |

**Anti-patterns:**
- Changing random things to "see if it helps"
- Reading every file in the project
- Assuming the bug is where you first look

---

## Step 3: Fix

Apply the smallest correct change.

**Before writing the fix, state:**
1. What the root cause is (1 sentence)
2. Why the fix addresses it (1 sentence)
3. What side effects could occur (if any)

**Fix principles:**
- Fix the cause, not the symptom
- Don't add workarounds unless the real fix is blocked
- If a workaround is necessary, add a `// TODO` with context
- Keep the fix isolated — don't refactor while fixing

---

## Step 4: Verify

Confirm the fix works and nothing else broke.

1. Run the exact reproduction steps — bug should be gone
2. Run the test suite — no new failures
3. Think about edge cases the fix might affect
4. Check if similar bugs could exist in related code

---

## When You're Stuck

If you've spent more than 3 attempts without progress:

1. **STOP** — don't keep trying the same approach
2. Write down what you know and what you've tried
3. Consider:
   - Is the bug where you think it is?
   - Are your assumptions correct?
   - Is there a simpler reproduction?
4. Ask the user for more context or guidance

---

## Hypothesis Ledger

When the cause isn't obvious — when Step 2 (Isolate) hasn't converged after a couple of passes — switch from ad-hoc tries to a tracked ledger.

**One hypothesis per iteration.** The discipline that costs the most when skipped:

- If you change three things and the bug goes away, you don't know which one fixed it
- "It works now" without knowing why means the bug will return in a different shape
- Fixes accumulate as cargo-cult — the codebase carries debt from forgotten hypotheses

**Format** — write under a `## Debugging: <bug>` heading in `tasks/todo.md` (survives compaction and hand-off):

```text
Hypothesis #N: [single concrete claim about what's wrong]
Test:          [the smallest change that would prove or disprove it]
Result:        [pass / fail / inconclusive — observed behaviour, not opinion]
Decision:      [keep / revert / supersede with hypothesis #N+1]
```

**Rules:**

- **One hypothesis at a time.** If you must change two files to test a theory, it's two hypotheses — split them.
- **Inconclusive is not pass.** If you can't tell whether the change helped, the test was wrong, not the hypothesis. Design a sharper test.
- **Revert means revert.** A "kept just in case" change becomes another variable in hypothesis #N+1.
- **Verify before closing.** A passed hypothesis closes the bug only after Step 4 (Verify) confirms the original reproduction is clean. A clean theory without verification is still a guess.

**When the ledger gets long (5+ hypotheses without resolution):** STOP. The bug is in a layer you haven't considered. Re-read the original report, question your isolation, and ask the user for more context. Adding a sixth hypothesis to the same layer is sunk-cost behaviour.

Inspired by the iteration discipline in [Browserbase's AutoBrowse skill](https://skills.sh/browserbase/skills/autobrowse) — same principle: test one thing at a time, log the result, keep what passes.

---

## Error Reading Checklist

When you see an error, extract these in order:

1. **Error type** — what kind of error? (TypeError, 404, timeout, etc.)
2. **Error message** — what does it say?
3. **Location** — file:line from the stack trace
4. **Trigger** — what action caused it?
5. **Context** — what state was the system in?

---

## Common Bug Categories

| Category | Typical Root Cause | Where to Look |
|----------|-------------------|---------------|
| TypeError / null | Missing validation, wrong data shape | Function inputs, API responses |
| Race condition | Async ordering, missing await | Promises, event handlers, DB queries |
| Wrong output | Logic error, off-by-one, wrong variable | Core business logic |
| Performance | N+1 queries, missing index, large payload | DB queries, API calls, loops |
| Auth/permission | Wrong role check, missing middleware | Auth middleware, route guards |
| Build/compile | Type mismatch, missing import, config | tsconfig, build config, imports |
