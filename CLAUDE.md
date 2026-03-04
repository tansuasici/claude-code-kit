# CLAUDE.md

## Session Boot
At the start of every session:
1. Read `CODEBASE_MAP.md`
2. Read `tasks/lessons.md` if it exists
3. Restate the current task in 1–2 sentences before doing anything

Never start coding before this.

---

## Plan First
For any task touching 3+ files, architectural decisions, new dependencies, or workflow changes:
- Write a plan to `tasks/todo.md` using the template in `agent_docs/workflow.md`
- Do not implement until the plan is confirmed

If something goes sideways mid-task: STOP, re-read the original goal, re-plan.

---

## Scope Discipline
- Touch ONLY files directly required by the task
- Never refactor opportunistically
- Log unrelated issues under `tasks/todo.md → ## Not Now`
- State every assumption explicitly before acting on it
- If 2+ valid approaches exist with real tradeoffs: present them, don't decide silently

---

## Protected Changes (Approval Required)
Stop and request approval before:
- New dependencies
- Database schema changes
- API contract changes
- Auth / permission logic
- Build system or core architecture changes

Provide at least 2 approaches with tradeoffs. Do not proceed without confirmation.

---

## Verification (Mandatory Order)
Every task must pass before marking complete:
1. Typecheck
2. Lint
3. Tests
4. Smoke test (verify real behavior — call endpoint, open page, run CLI)

Ask yourself: *"Would a staff engineer approve this?"*

---

## Self-Improvement Loop
- After ANY correction from the user: update `tasks/lessons.md`
- Format: Issue → Root Cause → Rule (see `agent_docs/workflow.md`)
- Review `tasks/lessons.md` at every session start

---

## Core Principles
- **Simplicity First**: smallest effective change, minimal impact
- **No Laziness**: find root causes, no temporary patches
- **Deterministic**: Plan → Implement → Verify → Review, every time

---

## Agent Docs
Read only what's relevant to the current task:
- Full workflow & plan template → `agent_docs/workflow.md`
- Debugging protocol → `agent_docs/debugging.md`
- Subagent strategy → `agent_docs/subagents.md`
- Code conventions → `agent_docs/conventions.md`
- Testing guide → `agent_docs/testing.md`
- Hooks guide → `agent_docs/hooks.md`
