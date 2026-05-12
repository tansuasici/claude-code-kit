# CLAUDE.md — Python FastAPI Project

## Session Boot
At the start of every session:
1. Read `CODEBASE_MAP.md`
2. Read `CLAUDE.project.md` if it exists
3. Read `tasks/lessons/_index.md` if it exists (Top Rules + index of lesson files)
4. Read `tasks/decisions.md` if it exists
5. Read the latest `tasks/handoff-*.md` if one exists
6. Restate the current task in 1-2 sentences before doing anything

Never start coding before this.

---

## After Compaction
Context compaction can happen mid-session. When you detect a compaction (conversation summary, loss of earlier details):
1. Re-read `tasks/todo.md` — restore awareness of the current task plan
2. Re-read the specific files you were actively editing
3. Re-read any contract file (`tasks/*_CONTRACT.md`) if one was active
4. Do NOT continue coding until you've re-established context

This is the single most important rule for long sessions.

---

## Tech-Specific Rules

### Python / FastAPI
- Use type hints everywhere — FastAPI depends on them
- Use async `def` for route handlers when doing I/O (DB, HTTP calls)
- Use Pydantic models for all request/response schemas
- Keep route handlers thin: validate (Pydantic) -> call service -> return response
- Use dependency injection (`Depends()`) for shared logic (auth, DB sessions)
- Never use `*` imports

### Database
- Use SQLAlchemy async sessions via dependency injection
- All queries go through the repository/service layer
- Use Alembic for migrations — never raw SQL for schema changes
- Always use parameterized queries

### API Design
- FastAPI auto-generates OpenAPI docs — keep schemas clean and well-documented
- Use proper HTTP status codes and `HTTPException`
- Group endpoints with `APIRouter` — one router per domain
- Use `response_model` on every route for documentation and validation

---

## Plan First
For any task touching 3+ files, architectural decisions, new dependencies, or workflow changes:
- Write a plan to `tasks/todo.md` using the template in `agent_docs/workflow.md`
- Do not implement until the plan is confirmed

---

## Scope Discipline
- Touch ONLY files directly required by the task
- Never refactor opportunistically
- Log unrelated issues under `tasks/todo.md > ## Not Now`
- State every assumption explicitly before acting on it

---

## Protected Changes (Approval Required)
Stop and request approval before:
- New dependencies (`pip install` / `pyproject.toml` changes)
- Database schema / Alembic migrations
- API contract changes (new endpoints, changed response models)
- Auth / permission logic
- Docker or deployment config changes

---

## Verification (Mandatory Order)
1. `mypy .` (typecheck)
2. `ruff check .` (lint)
3. `pytest` (tests)
4. Smoke test: `curl` the endpoint or check `/docs`
5. Optional before merge: `/review-pipeline` for multi-lens audit over the PR diff

---

## Self-Improvement Loop
- After ANY correction from the user: add a lesson under `tasks/lessons/` using `tasks/lessons/_TEMPLATE.md` (file name: `<YYYY-MM-DD>-<slug>.md`)
- Format: frontmatter + Issue > Root Cause > Rule (see `tasks/lessons/_TEMPLATE.md`)
- Promote critical rules to `tasks/lessons/_index.md` → `## Top Rules` (set `top_rule: true`)
- Review `tasks/lessons/_index.md` at every session start

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
- Skills guide → `agent_docs/skills.md`
- Task contracts (completion criteria) → `agent_docs/contracts.md`
- Prompting & bias awareness → `agent_docs/prompting.md`

---

## Project Overlay
If `CLAUDE.project.md` exists, read it after this file. Project-specific rules override kit defaults.
If `agent_docs/project/` contains docs, load them when relevant to the current task.
Project hooks in `.claude/hooks/project/` are configured separately in settings and are never modified by kit upgrades.
