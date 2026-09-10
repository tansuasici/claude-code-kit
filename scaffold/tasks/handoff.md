# Session Handoff

Use this template when ending a session or before context compaction. Generate this document so the next session can resume with minimal context.

Run `/compact` or manually create this before closing a long session.

---

## Template

```markdown
# Handoff — [Date]

## Goal
[1-2 sentences: what are we trying to accomplish?]

## Current Status
[Where did we leave off? What's done, what's in progress?]

## Key Decisions Made
[Important choices and why — so we don't re-debate them]
- Decision: [what] — Reason: [why]

## Files Changed
[List of files modified in this session]
- `path/to/file` — [what changed]

## What Works
[Things that are confirmed working]

## What's Broken / Blocked
[Known issues, failing tests, blockers]

## Next Steps
[Ordered list of what to do next]
1. [First priority]
2. [Second priority]
3. [Third priority]

## Context the Next Session Needs
[Anything non-obvious: env setup, branch name, running services, gotchas]
```

---

## Handoff vs Contracts

| | Handoff | Contract |
|---|---|---|
| **Purpose** | Transfer context between sessions | Define completion criteria for a task |
| **When** | Session is ending mid-work | Task is starting |
| **Contains** | Status, decisions, next steps | Tests, verification, acceptance criteria |
| **File** | `tasks/handoff-[date].md` | `tasks/{task-name}_CONTRACT.md` |

**Use both together:** Write a contract at task start (what must be true when done). Write a handoff when a session ends before the contract is fulfilled (where you left off).

See `agent_docs/contracts.md` for the contract template.

---

## Instructions for CLAUDE.md

Add this to your CLAUDE.md to enable handoff behavior:

```markdown
## Session Handoff
Before ending a long session or when context is running low:
1. Generate a handoff document using the template in `tasks/handoff.md`
2. Save it to `tasks/handoff-[date].md`
3. The next session should read the latest handoff file during Session Boot
```
