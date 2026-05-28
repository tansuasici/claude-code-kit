# CLAUDE.md — Django Project

## Session Boot (Tiered)
At the start of every session, load context in tiers — not everything at once.

> _Partially enforced via_ `.claude/hooks/session-start.sh` _— it auto-injects pointers to Tier 1 files, the top rules, the active task, and the current branch. You still need to_ Read _the files themselves._

**Tier 1 — Always (project awareness):**
1. Read `CODEBASE_MAP.md`
2. Read `CLAUDE.project.md` if it exists

**Tier 2 — If continuing work (active task context):**
3. Read the latest `tasks/handoff-*.md` — only if one exists (indicates interrupted session)
4. Read `tasks/todo.md` — only if active tasks exist

**Tier 3 — On demand (load when relevant):**
5. `tasks/lessons/_index.md` — read the `## Top Rules` section (first 15 lines). Read individual lesson files only when a decision could repeat a past mistake.
6. `tasks/decisions.md` — read only when facing architectural choices or protected changes.

Restate the current task in 1-2 sentences before doing anything. Never start coding before Tier 1 is loaded.

---

## After Compaction
Context compaction can happen mid-session. When you detect a compaction (conversation summary, loss of earlier details):
1. Re-read `tasks/todo.md` — restore awareness of the current task plan
2. Re-read the specific files you were actively editing
3. Re-read any contract file (`tasks/*_CONTRACT.md`) if one was active
4. Re-read `tasks/lessons/_index.md` → `## Top Rules` section only
5. Re-read `.hook-state/session-journal.md` if it exists — pre-compaction findings journaled with `/note` (lives only inside the current session; folded into the handoff at session end)
6. Do NOT continue coding until you've re-established context

This is the single most important rule for long sessions.

---

## Tech-Specific Rules

### Django
- Fat models, thin views, skinny templates. Business logic lives in models or a `services.py`, not in views.
- **Every model change is a migration.** Run `makemigrations`, review the generated migration, and never hand-edit applied migrations. Migrations are a protected change (see below).
- ORM discipline: avoid N+1 queries — reach for `select_related` (FK) / `prefetch_related` (M2M/reverse). Don't pull whole tables into Python; filter in the DB.
- Settings via environment, never hardcoded secrets. Keep `DEBUG = False` assumptions for prod code paths; split settings per environment if the project does.
- Use the ORM and `QuerySet` methods over raw SQL; if raw SQL is unavoidable, parameterize it (never string-format user input).
- Forms / DRF serializers do validation — don't trust request data in views. Use Django's auth + permissions; never roll your own password handling.
- Prefer class-based views / DRF viewsets consistent with the project; match the existing app structure.

### Style
- Follow the project's formatter/linter (`black` + `ruff`/`flake8`, `isort`). Match it exactly.
- Tests: `pytest` + `pytest-django` or `manage.py test` — match what's there. Use factories (`factory_boy`) if present; otherwise fixtures.
- Type hints where the project uses them; run `mypy` if configured.

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
- New dependencies (`pip install` / `requirements*.txt` / `pyproject.toml`)
- **Model changes / migrations** (`makemigrations`, editing `models.py`)
- `settings.py` changes (esp. `INSTALLED_APPS`, `MIDDLEWARE`, `DATABASES`, `AUTH_*`)
- Auth / permission logic
- URL contract changes (public routes, DRF API shape)
- Celery / task-queue topology changes
- Deployment / WSGI/ASGI config changes

---

## Verification (Mandatory Order)
1. `python manage.py check` (system checks)
2. `ruff check .` (or `flake8`) and `black --check .`
3. `mypy .` (if the project uses it)
4. `python manage.py makemigrations --check --dry-run` (no un-generated migrations)
5. `pytest` (or `python manage.py test`)
6. Smoke test: run `python manage.py runserver`, hit the view/endpoint, verify real behavior
7. Optional before merge: `/review-pipeline` for multi-lens audit over the PR diff

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
