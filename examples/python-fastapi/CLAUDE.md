# CLAUDE.md — Python FastAPI Project

## Session Boot
At the start of every session:
1. Read `CODEBASE_MAP.md`
2. Read `tasks/lessons.md` if it exists
3. Restate the current task in 1-2 sentences before doing anything

Never start coding before this.

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

---

## Self-Improvement Loop
- After ANY correction from the user: update `tasks/lessons.md`
- Format: Issue > Root Cause > Rule
- Review `tasks/lessons.md` at every session start

---

## Agent Docs
- Full workflow & plan template: `agent_docs/workflow.md`
- Debugging protocol: `agent_docs/debugging.md`
- Subagent strategy: `agent_docs/subagents.md`
- Code conventions: `agent_docs/conventions.md`
- Testing guide: `agent_docs/testing.md`
