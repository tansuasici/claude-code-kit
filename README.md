<p align="center">
  <img src="assets/logo.png" alt="Claude Code Kit" width="160">
</p>

<h1 align="center">Claude Code Kit</h1>

<p align="center">Drop-in starter templates that make Claude Code behave like a disciplined staff engineer instead of an eager intern.</p>

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

```bash
curl -fsSL https://raw.githubusercontent.com/tansuasici/claude-code-kit/main/install.sh | bash
```

Then fill in `CODEBASE_MAP.md` with your project's details and start a Claude Code session.

### Installer options

| Flag | Description |
|------|-------------|
| `--template nextjs` | Use a stack-specific template (`nextjs`, `node-api`, `python-fastapi`) |
| `--profile minimal` | Hooks only, no CLAUDE.md or docs |
| `--profile strict` | All hooks enabled (auto-lint, auto-format, skill-extract-reminder) |
| `--upgrade` | Add new files without overwriting your customizations |
| `--diff` | Compare local installation against latest kit (read-only) |
| `--gitignore` | Add kit files to `.gitignore` (keep kit local, don't push to repo) |
| `--version v1.0.0` | Install a specific version instead of latest |

### Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/tansuasici/claude-code-kit/main/uninstall.sh | bash
```

| Flag | Description |
|------|-------------|
| `--dry-run` | Show what would be removed without deleting |
| `--keep-tasks` | Preserve `tasks/` directory (lessons, decisions, handoffs) |
| `--force` | Remove without confirmation |

Examples:

```bash
# Install with Next.js template
curl -fsSL .../install.sh | bash -s -- --template nextjs

# Install privately (kit stays local, won't be pushed to repo)
curl -fsSL .../install.sh | bash -s -- --gitignore

# Upgrade existing installation
curl -fsSL .../install.sh | bash -s -- --upgrade

# Check what changed since you installed
curl -fsSL .../install.sh | bash -s -- --diff

# Install a specific version
curl -fsSL .../install.sh | bash -s -- --version v1.0.0
```

<details>
<summary>Manual install</summary>

```bash
git clone --depth 1 https://github.com/tansuasici/claude-code-kit.git /tmp/cck
cp /tmp/cck/CLAUDE.md /tmp/cck/CODEBASE_MAP.md .
cp -r /tmp/cck/agent_docs /tmp/cck/tasks /tmp/cck/scripts /tmp/cck/.claude .
rm -rf /tmp/cck
```

</details>

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

<details>
<summary>Without the kit</summary>

```text
You: "Add a search feature to the users page"

Claude: *immediately starts coding*
  - Installs 3 new packages without asking
  - Refactors the entire users module "while it's here"
  - Breaks the build because it didn't typecheck
  - Doesn't test anything
  - You spend 30 minutes reviewing and reverting unrelated changes
```

</details>

<details open>
<summary>With the kit</summary>

```text
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

</details>

## Hooks

Hooks are shell scripts that run automatically — unlike CLAUDE.md rules (advisory), hooks are **deterministic**.

| Hook | Type | What it does |
|------|------|-------------|
| `protect-files` | PreToolUse | Blocks edits to `.env`, credentials, private keys, lock files |
| `branch-protect` | PreToolUse | Blocks push to `main`/`master` and force pushes |
| `block-dangerous-commands` | PreToolUse | Blocks `rm -rf /`, `git reset --hard`, `DROP TABLE`, etc. |
| `conventional-commit` | PreToolUse | Enforces `feat:`, `fix:`, `refactor:` commit message format |
| `secret-scan` | PostToolUse | Warns if API keys, tokens, or passwords are found |
| `task-complete-notify` | Stop | Desktop notification + sound when Claude finishes |
| `auto-lint` | PostToolUse | Runs linter after edits *(opt-in)* |
| `auto-format` | PostToolUse | Runs formatter after edits *(opt-in)* |
| `skill-extract-reminder` | UserPromptSubmit | Reminds to extract discoveries as skills *(opt-in)* |

Opt-in hooks are not enabled by default — they can be slow or conflict with project configs. See `agent_docs/hooks.md` for how to enable them and write your own.

## Agents

Built-in agents for code review and planning:

| Agent | What it does |
|-------|-------------|
| `code-reviewer` | Reviews for correctness, quality, and best practices |
| `security-reviewer` | Scans code for vulnerabilities and security issues |
| `qa-reviewer` | Evidence-based QA verification |
| `planner` | Creates implementation plans before coding |

## Stack Templates

Each template includes a customized `CLAUDE.md` with stack-specific rules and a pre-filled `CODEBASE_MAP.md`:

| Template | Stack | Includes |
|----------|-------|----------|
| `nextjs` | Next.js 15, App Router, Prisma, Tailwind | Server/Client Component rules, build verification |
| `node-api` | Express, TypeScript, Knex.js | Layered architecture, API design conventions |
| `python-fastapi` | FastAPI, SQLAlchemy 2.0, Pydantic v2 | Async patterns, dependency injection, Alembic |

## Scripts

| Script | What it does |
|--------|-------------|
| `./scripts/doctor.sh` | Checks installation health (missing files, broken hooks, invalid settings) |
| `./scripts/validate.sh` | Checks `CODEBASE_MAP.md` for unfilled placeholders |
| `./scripts/statusline.sh` | Terminal status line showing model, branch, context %, cost |
| `./scripts/convert.sh` | Exports agents to Cursor, Windsurf, and Aider formats |

### Status line setup

Add to `.claude/settings.json`:

```json
{
  "statusLine": {
    "command": "./scripts/statusline.sh"
  }
}
```

```text
sonnet-4.5 | feat/search | ████████░░ 78% | $1.24
```

## Features

**Session Handoff** — Long sessions lose context. Before ending, Claude generates `tasks/handoff-[date].md`. The next session reads it and resumes where you left off.

**Skill Extraction** — Claude discovers non-obvious things during sessions (framework quirks, workarounds, config gotchas). The skill system captures these as `.claude/skills/<name>/SKILL.md` files that load automatically via semantic matching. Run `/skill-extractor` to review.

**Architecture Decision Records** — When Claude presents options and you pick one, the reasoning gets recorded in `tasks/decisions.md` as ADRs with context, options, and consequences.

**Permissions** — `.claude/settings.json` includes curated allow/deny lists. Allowed: test runners, linters, git reads. Denied: `curl`, `wget`, `.env` reads, `npm publish`. Review and customize for your project.

## What's Inside

<details>
<summary>Full directory structure</summary>

```text
claude-code-kit/
  CLAUDE.md                        # Core agent instructions
  CODEBASE_MAP.md                  # Project mapping template
  install.sh                       # One-line setup script
  uninstall.sh                     # Clean removal script
  agent_docs/                      # Agent behavior guides
    workflow.md                    #   Planning templates & task lifecycle
    debugging.md                   #   4-step debugging protocol
    testing.md                     #   Test strategy & patterns
    conventions.md                 #   Naming, structure, git hygiene
    subagents.md                   #   When & how to use subagents
    hooks.md                       #   Hooks guide & how to write your own
    skills.md                      #   Skill extraction guide
    contracts.md                   #   Task contract system
    prompting.md                   #   Bias awareness & neutral prompting
  tasks/                           # Session state & tracking
    todo.md, lessons.md, decisions.md, handoff.md
  scripts/                         # Utility scripts
    doctor.sh, validate.sh, statusline.sh, convert.sh
  .claude/
    settings.json                  # Hook configs & permissions
    agents/                        # code-reviewer, security-reviewer, planner, qa-reviewer
    hooks/                         # 9 deterministic hook scripts
    skills/skill-extractor/        # Meta-skill for knowledge extraction
  examples/
    nextjs/                        # Next.js 15 + App Router template
    node-api/                      # Express + TypeScript template
    python-fastapi/                # FastAPI + SQLAlchemy template
```

</details>

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
