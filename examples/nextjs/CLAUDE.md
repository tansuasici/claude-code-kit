# CLAUDE.md — Next.js Project

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

### Next.js
- Use App Router (`app/`) — never Pages Router unless migrating
- Server Components by default. Only add `"use client"` when you need interactivity, hooks, or browser APIs
- Use `next/image` for images, `next/link` for navigation
- Data fetching: Server Components with `fetch()` or server actions — no `useEffect` for data loading
- Environment variables: `NEXT_PUBLIC_` prefix for client-side, plain for server-side
- API routes go in `app/api/` as route handlers

### Styling
- Use the project's existing approach (Tailwind / CSS Modules / styled-components)
- Don't introduce a new styling system without approval
- Keep component styles co-located

### State Management
- Server state: React Server Components or React Query / SWR
- Client state: React Context or Zustand — match what's already in the project
- Don't use Redux unless it's already in the project

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
- New dependencies (`npm install`)
- `next.config.js` / `next.config.ts` changes
- Middleware changes (`middleware.ts`)
- Auth / permission logic
- Database schema or ORM changes
- API route contract changes
- Build or deployment config changes

---

## Verification (Mandatory Order)
1. `npx tsc --noEmit` (typecheck)
2. `npm run lint` (ESLint)
3. `npm test` (tests)
4. `npm run build` (production build — catches SSR issues)
5. Smoke test: open the page in browser, verify real behavior
6. Optional before merge: `/review-pipeline` for multi-lens audit over the PR diff

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
