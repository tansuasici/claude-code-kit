# Workflow & Planning

## Task Lifecycle

```
Receive Task → Understand → Plan → Confirm → Implement → Verify → Done
```

Every task follows this flow. Never skip steps.

---

## When to Write a Plan

Write a plan to `tasks/todo.md` when:
- Task touches 3+ files
- Architectural decision is needed
- New dependency or tool is introduced
- Workflow or build system changes
- You're unsure about the approach

For small, isolated changes (typo fix, single-function edit): just do it.

---

## Plan Template

Copy this into `tasks/todo.md`:

```markdown
## Task: [Short title]

**Goal**: [1 sentence — what does "done" look like?]

**Context**: [Why is this needed? Link to issue/discussion if relevant]

### Approach
1. [Step 1]
2. [Step 2]
3. [Step 3]

### Files to Touch
- `path/to/file.ts` — [what changes]
- `path/to/file.ts` — [what changes]

### Open Questions
- [Anything unclear that needs confirmation?]

### Risks
- [What could go wrong?]

### Not Now
- [Things noticed but out of scope]
```

---

## Mid-Task Recovery

If something goes sideways:

1. **STOP** — don't push through
2. Re-read the original goal
3. Check if scope has drifted
4. Update the plan in `tasks/todo.md`
5. Get confirmation before continuing

The most common failure mode is scope creep disguised as "while I'm here."

---

## PR / Commit Workflow

### Commit Messages

```
<type>: <short description>

<optional body — why, not what>
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`

Good:
```
feat: add rate limiting to /api/upload

Prevents abuse from unauthenticated clients.
Limit: 10 req/min per IP.
```

Bad:
```
update stuff
fix things
WIP
```

### PR Checklist

Before marking a task done:
- [ ] All changes match the original plan
- [ ] No unrelated changes snuck in
- [ ] Typecheck passes
- [ ] Lint passes
- [ ] Tests pass
- [ ] Smoke tested (manually verified real behavior)
- [ ] `tasks/todo.md` updated (task marked done or removed)

---

## Scope Control

### What "scope discipline" means in practice

| Situation | Do | Don't |
|-----------|------|-------|
| See a typo in an unrelated file | Log it in Not Now | Fix it now |
| Function could be cleaner | Log it in Not Now | Refactor it |
| Test is flaky but unrelated | Log it in Not Now | Debug it |
| Dependency could be updated | Log it in Not Now | Update it |
| Better pattern exists for old code | Log it in Not Now | Rewrite it |

### The "Not Now" List

In `tasks/todo.md`, keep a `## Not Now` section:

```markdown
## Not Now
- [ ] `src/utils/format.ts` has a potential timezone bug
- [ ] `package.json` — lodash could be replaced with native methods
- [ ] Auth middleware doesn't handle token refresh edge case
```

These get addressed in dedicated cleanup sessions, not mid-feature.
