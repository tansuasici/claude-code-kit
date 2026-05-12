# CLAUDE.md

## Session Boot (Tiered)
At the start of every session, load context in tiers — not everything at once.

**Tier 1 — Always (project awareness):**
1. Read `CODEBASE_MAP.md`
2. Read `CLAUDE.project.md` if it exists

**Tier 2 — If continuing work (active task context):**
3. Read the latest `tasks/handoff-*.md` — only if one exists (indicates interrupted session)
4. Read `tasks/todo.md` — only if active tasks exist

**Tier 3 — On demand (load when relevant):**
5. `tasks/lessons/_index.md` — read the `## Top Rules` section (first 15 lines). Read individual lesson files in `tasks/lessons/` only when making decisions that could repeat past mistakes.
6. `tasks/decisions.md` — read only when facing architectural choices or protected changes.

Restate the current task in 1–2 sentences before doing anything. Never start coding before Tier 1 is loaded.

---

## After Compaction
Context compaction can happen mid-session. When you detect a compaction (conversation summary, loss of earlier details):
1. Re-read `tasks/todo.md` — restore awareness of the current task plan
2. Re-read the specific files you were actively editing
3. Re-read any contract file (`tasks/*_CONTRACT.md`) if one was active
4. Re-read `tasks/lessons/_index.md` → `## Top Rules` section only
5. Do NOT continue coding until you've re-established context

This is the single most important rule for long sessions.

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
After approval, record the decision in `tasks/decisions.md` using the ADR template.

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
- After ANY correction from the user: add a lesson under `tasks/lessons/` using `tasks/lessons/_TEMPLATE.md` (file name: `<YYYY-MM-DD>-<slug>.md`)
- Format: frontmatter + Issue → Root Cause → Rule (see `tasks/lessons/_TEMPLATE.md`)
- Promote critical, recurring rules to `tasks/lessons/_index.md` → `## Top Rules` (set `top_rule: true` in the lesson's frontmatter)
- Review `tasks/lessons/_index.md` at every session start

---

## Core Principles
- **Simplicity First**: smallest effective change, minimal impact
- **No Laziness**: find root causes, no temporary patches
- **Deterministic**: Plan → Implement → Verify → Review, every time

---

## Design System
If `DESIGN.md` exists, read it before any UI work. Treat it as the design source of truth — compare implementation against it during design reviews and UI generation.

---

## Knowledge Wiki
If `WIKI.md` exists, read it before knowledge work. Follow its ingest, query, and lint workflows when working with the wiki vault. Never modify files in `raw-sources/` — they are immutable. Always update `wiki/index.md` and append to `wiki/log.md` after any wiki operation.

---

## HTML Artifacts
If `ARTIFACTS.md` exists, read it before producing any spec, plan, report, PR writeup, design prototype, or custom editor. Default to HTML output (not markdown) for those use cases — store under `artifacts/`, mirror tokens from `artifacts/design-system.html`, and append a row to `artifacts/index.html` after creating any artifact. Markdown stays for `tasks/` and other hand-edited files.

---

## Product Context
If `agent_docs/project/mission.md` exists, read it for product context before feature work.
If `agent_docs/project/tech-stack.md` exists, read it before technology choices.
If `agent_docs/project/roadmap.md` exists, read it before scoping or prioritization discussions.

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
- Architecture language (vocabulary for `/deepening-review` and `/interface-design`) → `agent_docs/architecture-language.md`

---

## Project Overlay
If `CLAUDE.project.md` exists, read it after this file. Project-specific rules override kit defaults.
If `agent_docs/project/` contains docs, load them when relevant to the current task.
Project hooks in `.claude/hooks/project/` are configured separately in settings and are never modified by kit upgrades.
