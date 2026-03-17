# CLAUDE.md — Node.js API Project

## Session Boot
At the start of every session:
1. Read `CODEBASE_MAP.md`
2. Read `CLAUDE.project.md` if it exists
3. Read `tasks/lessons.md` if it exists
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

### Node.js / Express
- Use async/await — never raw callbacks
- All route handlers must have error handling (use error middleware)
- Validate request input at the boundary (zod, joi, or similar)
- Never trust `req.body`, `req.params`, or `req.query` without validation
- Use environment variables for all config — never hardcode secrets
- Keep controllers thin: validate input -> call service -> return response

### Database
- All queries go through the service layer, never directly in routes
- Use transactions for multi-step operations
- Parameterized queries only — never string interpolation for SQL
- Migrations must be reversible

### API Design
- RESTful conventions: `GET /users`, `POST /users`, `GET /users/:id`
- Consistent error response format: `{ error: { code, message } }`
- Use proper HTTP status codes (don't return 200 for everything)
- Version the API if it has external consumers (`/api/v1/`)

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
- New dependencies
- Database schema / migration changes
- API contract changes (new endpoints, changed response shapes)
- Auth / permission middleware
- Docker or deployment config changes

---

## Verification (Mandatory Order)
1. `npx tsc --noEmit` (typecheck)
2. `npm run lint` (ESLint)
3. `npm test` (unit + integration tests)
4. Smoke test: `curl` the endpoint, verify response

---

## Self-Improvement Loop
- After ANY correction from the user: update `tasks/lessons.md`
- Format: Issue > Root Cause > Rule
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
- Skills guide → `agent_docs/skills.md`
- Task contracts (completion criteria) → `agent_docs/contracts.md`
- Prompting & bias awareness → `agent_docs/prompting.md`

---

## Project Overlay
If `CLAUDE.project.md` exists, read it after this file. Project-specific rules override kit defaults.
If `agent_docs/project/` contains docs, load them when relevant to the current task.
Project hooks in `.claude/hooks/project/` are configured separately in settings and are never modified by kit upgrades.
