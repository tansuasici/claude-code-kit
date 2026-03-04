# CLAUDE.md — Next.js Project

## Session Boot
At the start of every session:
1. Read `CODEBASE_MAP.md`
2. Read `tasks/lessons.md` if it exists
3. Restate the current task in 1-2 sentences before doing anything

Never start coding before this.

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
