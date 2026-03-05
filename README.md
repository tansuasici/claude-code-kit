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
cp -r /tmp/cck/agent_docs /tmp/cck/tasks /tmp/cck/scripts /tmp/cck/.claude .
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
    hooks.md                        # Hooks guide & how to write your own
    skills.md                       # Skill extraction guide & best practices
  tasks/
    todo.md                         # Task board template
    lessons.md                      # Self-improvement log template
    decisions.md                    # Architecture Decision Records
    handoff.md                      # Session handoff template
  scripts/
    validate.sh                     # Checks CODEBASE_MAP.md for unfilled placeholders
    statusline.sh                   # Terminal status line (model, branch, context %, cost)
  .claude/
    settings.json                   # Hook configurations & permissions
    agents/
      security-reviewer.md          # Scans code for vulnerabilities
      code-reviewer.md              # Reviews for correctness & quality
      planner.md                    # Creates implementation plans
    hooks/
      protect-files.sh              # Blocks edits to .env, credentials, keys
      branch-protect.sh             # Blocks push to main/master & force push
      block-dangerous-commands.sh   # Blocks rm -rf, git reset --hard, DROP TABLE
      auto-lint.sh                  # Auto-runs linter after file edits
      auto-format.sh                # Auto-runs formatter after file edits
      secret-scan.sh                # Scans for leaked secrets in edited files
      task-complete-notify.sh       # Desktop notification when task finishes
      conventional-commit.sh        # Enforces conventional commit format
      skill-extract-reminder.sh     # Reminds to extract discoveries (opt-in)
    skills/
      skill-extractor/              # Autonomous knowledge extraction skill
        SKILL.md
        resources/
          skill-template.md
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

## Hooks

Hooks are shell scripts that run automatically — unlike CLAUDE.md rules (advisory), hooks are **deterministic**.

### Included hooks

| Hook | Type | What it does |
|------|------|-------------|
| `protect-files` | PreToolUse | Blocks edits to `.env`, credentials, private keys, lock files |
| `branch-protect` | PreToolUse | Blocks push to `main`/`master` and force pushes |
| `block-dangerous-commands` | PreToolUse | Blocks `rm -rf /`, `git reset --hard`, `DROP TABLE`, etc. |
| `auto-lint` | PostToolUse | Runs linter after edits (eslint, ruff, gofmt, clippy) |
| `auto-format` | PostToolUse | Runs formatter after edits (prettier, black, rustfmt) |
| `conventional-commit` | PreToolUse | Enforces `feat:`, `fix:`, `refactor:` commit message format |
| `secret-scan` | PostToolUse | Warns if API keys, tokens, or passwords are found |
| `task-complete-notify` | Stop | Desktop notification + sound when Claude finishes |
| `skill-extract-reminder` | UserPromptSubmit | Reminds Claude to consider extracting non-obvious discoveries as skills |

### Enabled by default

`protect-files`, `branch-protect`, `block-dangerous-commands`, `conventional-commit`, `secret-scan`, and `task-complete-notify` are enabled in `.claude/settings.json`.

`auto-lint`, `auto-format`, and `skill-extract-reminder` are **not enabled by default** — they can be slow or conflict with project configs. See `agent_docs/hooks.md` for how to enable them.

### Write your own

```bash
#!/usr/bin/env bash
set -euo pipefail
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | cut -d'"' -f4)
# Your logic here
exit 0  # allow (exit 2 to block)
```

See `agent_docs/hooks.md` for the full guide.

## Session Handoff

Long sessions lose context. The handoff system preserves it across sessions:

1. Before ending a session, Claude generates `tasks/handoff-[date].md`
2. Next session reads the handoff file and resumes where you left off
3. Reduces context transfer from 10,000+ tokens to ~1,500

See `tasks/handoff.md` for the template.

## Skill Extraction

Claude discovers non-obvious things during sessions — undocumented framework quirks, tricky workarounds, config gotchas. The skill extraction system captures these as `.claude/skills/<name>/SKILL.md` files that Claude Code loads automatically via semantic matching.

- Run `/skill-extractor` to review the current session for extractable knowledge
- Skills complement `tasks/lessons.md`: lessons track user corrections, skills track Claude's discoveries
- Enable `skill-extract-reminder` hook for automatic reminders (opt-in)

See `agent_docs/skills.md` for the full guide.

## Architecture Decision Records

When Claude presents options A, B, and C and you pick B — the reasoning for rejecting A and C needs to be recorded. `tasks/decisions.md` tracks these as ADRs (Architecture Decision Records) with context, options, and consequences.

## Status Line

Shows model, git branch, context usage, and session cost in the terminal:

```
sonnet-4.5 | feat/search | ████████░░ 78% | $1.24
```

Add to `.claude/settings.json`:

```json
{
  "statusLine": {
    "command": "./scripts/statusline.sh"
  }
}
```

## Permissions

`.claude/settings.json` includes a curated permission allow/deny list:

- **Allowed**: test runners, linters, typecheckers, git read commands
- **Denied**: network tools (`curl`, `wget`), secret file reads (`.env`, credentials), package publishing (`npm publish`, `docker push`)

Review and customize for your project.

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
