---
name: debug
description: Systematic root-cause debugging with evidence-before-fix enforcement and regression-test generation. Use when chasing a bug, failing test, error, crash, or unexpected behavior — before attempting a fix.
user-invocable: true
---

# Debug

## Core Rule

Form a single hypothesis at a time. Validate with a falsifiable test before fixing. Never patch a symptom you haven't reproduced.

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
4. **Check the language pattern lookup** — if the error matches a category in `references/error-patterns.md`, use it to seed hypotheses (do not blindly accept; verify against the actual code)
5. **Form 2-3 hypotheses** — rank by likelihood

```markdown
### Hypotheses
1. [Most likely] — DB query returns null when user has no orders → NPE on line 45
2. [Possible] — Race condition between auth check and data fetch
3. [Less likely] — Timezone mismatch in date comparison
```

If fixes were already attempted before this skill was invoked, count them first. Two or more failed attempts against the same symptom means you inherit a suspect premise, not a blank slate — apply the stop rule in Phase 5 now, before forming hypotheses that repeat it.

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

**Stop rule — two fixes, one premise.** Before starting a third fix, count the failed ones. When two fixes have already failed *the same reproduction*, the fixes are not the problem: the premise they share is. Both were derived from one belief about where the bug lives, and that belief is the thing that has been falsified twice.

Do not start a third fix. Instead:

1. **Write the shared premise as one sentence.** Not the two fixes — the single assumption both relied on. If you cannot write it in one sentence, you have not found it yet; look at what both fixes took for granted about which component holds the state.
2. **Design a check that falsifies the premise itself**, not the next fix. Phase 1's reproduction tests the bug; this tests the belief. A premise that cannot be checked is not yet a hypothesis — narrow it until it can be.
3. **Run that check and record the result** under `## Investigation` in the report, as its own entry, before proposing anything.
4. **Only then** return to Phase 2 and form hypotheses from the new evidence. If the premise survived the check, the bug is somewhere neither fix looked.

A third fix built on a twice-falsified premise is a guess wearing a fix's clothing, and it costs more than the stop does.

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

When forming hypotheses in Phase 2, consult `references/error-patterns.md` for language-specific lookup tables of frequently-misdiagnosed errors and their common root causes.

Loaded on-demand — only when the error message matches a category in the table. For unfamiliar errors, fall back to first-principles investigation rather than guessing from the table.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I know what the bug is, I'll just fix it" | Reproduce first. Assumption-based fixes are wrong ~30% of the time and create new bugs. |
| "The failing test is probably wrong" | Read the test. If it's wrong, fix it. If it's right, fix your code. Never skip. |
| "It works locally, CI must be flaky" | Environments differ. Reproduce in CI conditions before dismissing. |
| "I'll add logging later" | Intermittent bugs without logging become permanent mysteries. Add instrumentation now. |
| "The stack trace points to X, so X is broken" | Stack traces show where the error surfaces, not where it originates. Trace upstream. |
| "That fix was close — one more attempt and it's done" | Two fixes failing the same reproduction falsifies the premise under both, not the fixes. Check the premise before attempt three (Phase 5 stop rule). |

## Notes

- The #1 rule: **no fix without confirmed root cause** — guessing leads to patches that mask bugs
- Evidence-before-fix is non-negotiable — if you can't explain why the fix works, you don't understand the bug
- Intermittent bugs need more logging, not more guessing — add instrumentation first
- If the bug is in a dependency, document the workaround and file an upstream issue
- Each debug session should improve the codebase's debuggability (better error messages, logging, assertions)
- `loop-detect.sh` is the syntactic counterpart to the Phase 5 stop rule — it counts how often one file appears in the last 10 edits (warns at 4, blocks at 6). The stop rule is the semantic one: no hook can judge whether two fixes share a premise, so this one is yours to apply
- The stop rule is the kit's reading of the "attack the premise" heuristic in [unclebob/ub-mode](https://github.com/unclebob/ub-mode); the procedure here is the kit's own
