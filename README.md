# Claude Code Kit

Drop-in starter templates that make Claude Code behave like a disciplined staff engineer instead of an eager intern.

## The Problem

Out of the box, Claude Code is powerful but undisciplined. It will:
- Start coding before understanding the codebase
- Make sweeping changes across files you didn't ask it to touch
- Skip verification steps and ship broken code
- Forget lessons from previous mistakes
- Install dependencies and change architecture without asking

## The Solution

This kit provides a `CLAUDE.md` instruction set and supporting templates that enforce a structured workflow:

**Plan > Confirm > Implement > Verify** — every single time.

## Quick Start

### One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/tansuasici/claude-code-kit/main/install.sh | bash
```

### With a stack-specific template

```bash
curl -fsSL https://raw.githubusercontent.com/tansuasici/claude-code-kit/main/install.sh | bash -s -- --template nextjs
```

Available templates: `nextjs`, `node-api`, `python-fastapi`

### Manual install

```bash
git clone --depth 1 https://github.com/tansuasici/claude-code-kit.git /tmp/cck
cp /tmp/cck/CLAUDE.md /tmp/cck/CODEBASE_MAP.md .
cp -r /tmp/cck/agent_docs /tmp/cck/tasks /tmp/cck/scripts .
rm -rf /tmp/cck
```

Then fill in `CODEBASE_MAP.md` with your project's details and start a Claude Code session.

## What's Inside

```
claude-code-kit/
  CLAUDE.md                        # Core agent instructions
  CODEBASE_MAP.md                  # Project mapping template
  agent_docs/
    workflow.md                     # Planning templates & task lifecycle
    debugging.md                    # 4-step debugging protocol
    testing.md                      # Test strategy & patterns
    conventions.md                  # Naming, structure, git hygiene
    subagents.md                    # When & how to use subagents
  tasks/
    todo.md                         # Task board template
    lessons.md                      # Self-improvement log template
  scripts/
    validate.sh                     # Checks CODEBASE_MAP.md for unfilled placeholders
  examples/
    nextjs/                         # Next.js 15 + App Router template
    node-api/                       # Express + TypeScript template
    python-fastapi/                 # FastAPI + SQLAlchemy template
  install.sh                        # One-line setup script
```

## What CLAUDE.md Enforces

| Rule | What it does |
|------|-------------|
| **Session Boot** | Reads project map and past lessons before touching any code |
| **Plan First** | Writes a plan for multi-file changes, waits for your confirmation |
| **Scope Discipline** | Touches only what's needed, logs unrelated issues in "Not Now" |
| **Protected Changes** | Stops for approval on deps, schema, auth, API, and build changes |
| **Verification** | Typecheck, lint, test, smoke test — in that order, every time |
| **Self-Improvement** | Logs corrections to `tasks/lessons.md` and reviews them each session |

## Before / After

### Without the kit

```
You: "Add a search feature to the users page"

Claude: *immediately starts coding*
  - Installs 3 new packages without asking
  - Refactors the entire users module "while it's here"
  - Breaks the build because it didn't typecheck
  - Doesn't test anything
  - You spend 30 minutes reviewing and reverting unrelated changes
```

### With the kit

```
You: "Add a search feature to the users page"

Claude: "Let me restate: add search functionality to the users page.
I've read CODEBASE_MAP.md — the users page is at app/(dashboard)/users/page.tsx,
data comes from src/services/user.service.ts.

This touches 3+ files, so here's my plan:"

  ## Task: Add search to users page
  ### Approach
  1. Add search param handling in users/page.tsx
  2. Add `searchUsers()` to user.service.ts
  3. Add search input component
  ### Files to Touch
  - app/(dashboard)/users/page.tsx
  - src/services/user.service.ts
  - components/features/user-search.tsx (new)

  "Should I proceed with this plan?"

You: "Yes"

Claude: *implements, then runs:*
  1. tsc --noEmit ✓
  2. eslint ✓
  3. npm test ✓
  4. Opens the page, verifies search works ✓

  "Done. All verification passed."
```

## Validation

Check if your `CODEBASE_MAP.md` is properly filled in:

```bash
./scripts/validate.sh
```

Output for an unfilled template:

```
  WARN  [command] placeholder:
         Line 15: | Dev        | `[command]`     |
  WARN  [module] placeholder:
         Line 26:   ├── [module]/       # what it does
  WARN  Empty sections found:
         Line 5: ## What (empty section)

  8 issue(s) found. Fill in the placeholders above.
```

## Stack Templates

Each template includes a customized `CLAUDE.md` with stack-specific rules and a pre-filled `CODEBASE_MAP.md`:

| Template | Stack | Includes |
|----------|-------|----------|
| `nextjs` | Next.js 15, App Router, Prisma, Tailwind | Server/Client Component rules, build verification |
| `node-api` | Express, TypeScript, Knex.js | Layered architecture, API design conventions |
| `python-fastapi` | FastAPI, SQLAlchemy 2.0, Pydantic v2 | Async patterns, dependency injection, Alembic |

```bash
# Use a template
./install.sh --template nextjs
```

## Customization

This kit is a starting point. You should:

1. **Edit `CLAUDE.md`** — add project-specific rules, remove what doesn't apply
2. **Fill in `CODEBASE_MAP.md`** — the more detail, the better Claude performs
3. **Extend `agent_docs/`** — add guides specific to your project's patterns
4. **Track lessons** — `tasks/lessons.md` compounds over time, making Claude smarter per-project

## Contributing

PRs welcome. If you've built a template for a stack we don't cover yet, open a PR.

## License

MIT
