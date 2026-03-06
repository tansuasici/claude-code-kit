# Task Contracts

## What Is a Contract?

A task contract defines **exactly** what must be true before a task is considered complete. Agents know how to start tasks but often struggle to know when to stop. Contracts solve this by making "done" deterministic.

Without a contract, agents will:
- Implement stubs and call it done
- Skip verification steps
- Stop at first working attempt (not best attempt)

---

## When to Use Contracts

| Scenario | Use a Contract? |
|----------|----------------|
| Multi-step feature implementation | Yes |
| Bug fix with specific reproduction steps | Yes |
| Large refactor with many files | Yes |
| Simple typo fix | No |
| Single function edit with obvious scope | No |

**Rule of thumb:** If the task has more than one verification criterion, write a contract.

---

## Contract Template

Save as `tasks/{task-name}_CONTRACT.md`:

```markdown
# Contract: [Task Name]

## Goal
[1-2 sentences: what does "done" look like in plain language?]

## Completion Criteria

### Tests (must ALL pass)
- [ ] `[test name or file]` — [what it verifies]
- [ ] `[test name or file]` — [what it verifies]

### Verification (must ALL be confirmed)
- [ ] Typecheck passes (`npx tsc --noEmit` or equivalent)
- [ ] Lint passes (`npm run lint` or equivalent)
- [ ] Smoke test: [specific manual verification step]

### Behavioral Checks (if applicable)
- [ ] [Endpoint/page/CLI] returns expected result for [input]
- [ ] [Screenshot/visual] matches expected design
- [ ] [Performance] stays within [threshold]

## Out of Scope
- [Things explicitly NOT part of this contract]

## Termination Rule
Do NOT end the session until every checkbox above is checked.
If a criterion cannot be met, document WHY and ask the user.
```

---

## How Contracts Work with Hooks

### Advisory (default)
The agent reads the contract at task start and self-enforces. This works well with the compaction recovery rule — after compaction, the agent re-reads the contract.

### Enforced (via stop hook)
For critical tasks, modify the stop hook to check contract completion:

```bash
#!/usr/bin/env bash
set -euo pipefail

CONTRACT=$(find tasks/ -name "*_CONTRACT.md" -newer tasks/todo.md 2>/dev/null | head -1)

if [ -n "$CONTRACT" ]; then
  UNCHECKED=$(grep -c '^\- \[ \]' "$CONTRACT" 2>/dev/null || echo "0")
  if [ "$UNCHECKED" -gt 0 ]; then
    echo "BLOCKED: Contract has $UNCHECKED unchecked criteria in $CONTRACT"
    exit 2
  fi
fi

exit 0
```

This prevents the agent from terminating until all contract checkboxes are marked done.

---

## Contract Lifecycle

```text
Define Contract → Start Session → Implement → Verify Against Contract → All Checked? → Done
                                      ↑                                    ↓ (No)
                                      └────────────── Fix & Retry ─────────┘
```

1. **Before starting**: Write the contract with specific, testable criteria
2. **During work**: Check off criteria as they're verified
3. **Before stopping**: All criteria must be checked
4. **If blocked**: Document the blocker, ask the user

---

## Writing Good Criteria

### Do
- Make criteria binary (pass/fail, not subjective)
- Reference specific test files, commands, or endpoints
- Include the exact command to run for verification
- Keep criteria independent (one failure doesn't cascade)

### Don't
- Write vague criteria ("code should be clean")
- Include subjective quality judgments
- Make criteria that require human interpretation
- Bundle multiple checks into one criterion

---

## Example Contract

```markdown
# Contract: Add Rate Limiting to Upload API

## Goal
The /api/upload endpoint enforces per-IP rate limiting (10 req/min) and returns 429 with Retry-After header when exceeded.

## Completion Criteria

### Tests
- [ ] `tests/unit/rate-limiter.test.ts` — limits requests per window
- [ ] `tests/unit/rate-limiter.test.ts` — resets after window expires
- [ ] `tests/integration/upload.test.ts` — returns 429 on limit breach
- [ ] `tests/integration/upload.test.ts` — includes Retry-After header

### Verification
- [ ] `npx tsc --noEmit` passes
- [ ] `npm run lint` passes
- [ ] All tests pass: `npm test`
- [ ] Smoke test: `for i in $(seq 1 12); do curl -s -o /dev/null -w "%{http_code}" localhost:3000/api/upload; done` — last 2 return 429

### Behavioral Checks
- [ ] Rate limit state is per-IP, not global
- [ ] Existing upload functionality still works normally

## Out of Scope
- Rate limiting for other endpoints
- Redis-backed rate limiting (use in-memory for now)
- Admin bypass for rate limits

## Termination Rule
Do NOT end the session until every checkbox above is checked.
```
