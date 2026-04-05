# CODEBASE_MAP.md

## What

ClaudeCodeKit is a drop-in starter template that enforces disciplined software engineering practices on Claude Code. It transforms agent behavior from "eager intern" to "staff engineer" through structured workflows: Plan → Confirm → Implement → Verify.

## Why

Developers using Claude Code and similar agents often get inconsistent results — the agent skips planning, makes silent assumptions, drifts in scope, or stops before tasks are truly complete. This kit provides the guardrails (rules, hooks, skills, templates) to make agent behavior predictable and high-quality across any project.

## Tech Stack

- **Shell scripts** (bash) — hooks, install script, utilities
- **Markdown** — all rules, guides, templates, skills
- **JSON** — Claude Code settings configuration
- No runtime dependencies — this is a configuration kit, not a library

## Key Commands

| Action | Command |
|--------|---------|
| Install | `curl -fsSL https://raw.githubusercontent.com/tansuasici/claude-code-kit/main/install.sh \| bash` |
| Install with template | `curl -fsSL ... \| bash -s -- --template nextjs` |
| Uninstall | `curl -fsSL https://raw.githubusercontent.com/tansuasici/claude-code-kit/main/uninstall.sh \| bash` |
| Validate CODEBASE_MAP | `./scripts/validate.sh CODEBASE_MAP.md` |
| Lint markdown | `markdownlint .` |

---

## Directory Structure

```text
.
├── CLAUDE.md                      # Core agent instructions (kit-managed)
├── CLAUDE.project.md              # Project-specific overlay (never touched by kit)
├── CODEBASE_MAP.md                # Project documentation template
├── DESIGN.md                      # Design system template (optional, for UI projects)
├── .kit-manifest                  # Tracks kit-managed files (auto-generated)
├── install.sh                     # One-line installer
├── uninstall.sh                   # Clean removal of all kit files
│
├── agent_docs/                    # Agent behavior guides (read conditionally)
│   ├── workflow.md                # Task lifecycle, planning, session strategy
│   ├── debugging.md               # 4-step debug protocol
│   ├── testing.md                 # Test strategy & patterns
│   ├── conventions.md             # Code style & git hygiene
│   ├── subagents.md               # When/how to use subagents
│   ├── hooks.md                   # Hook system guide
│   ├── skills.md                  # Skill extraction & cleanup
│   ├── contracts.md               # Task contract system
│   ├── prompting.md               # Bias awareness & neutral prompting
│   └── project/                   # Project-specific docs (never touched by kit)
│       ├── mission.md             # Product mission and audience (optional template)
│       ├── tech-stack.md          # Technology choices with rationale (optional template)
│       └── roadmap.md             # Current priorities and milestones (optional template)
│
├── tasks/                         # Session state & tracking
│   ├── todo.md                    # Current task board
│   ├── lessons.md                 # Self-improvement log
│   ├── decisions.md               # Architecture Decision Records
│   └── handoff.md                 # Session handoff template
│
├── .claude/                       # Claude Code configuration
│   ├── settings.json              # Hooks & permissions
│   ├── agents/                    # Custom agent definitions
│   │   ├── code-reviewer.md       # Code review agent
│   │   ├── security-reviewer.md   # Security review agent
│   │   ├── planner.md             # Implementation planning agent
│   │   ├── qa-reviewer.md         # Evidence-based QA verification agent
│   │   └── dead-code-remover.md   # Dead code removal agent
│   ├── hooks/                     # Deterministic shell script hooks
│   │   ├── protect-files.sh       # Block edits to sensitive files
│   │   ├── branch-protect.sh      # Block push to main/force push
│   │   ├── block-dangerous-commands.sh  # Block destructive commands
│   │   ├── loop-detect.sh         # Edit loop detection and prevention
│   │   ├── conventional-commit.sh # Enforce commit message format
│   │   ├── secret-scan.sh         # Detect secrets in code
│   │   ├── unicode-scan.sh        # Detect invisible Unicode (Glassworm defense)
│   │   ├── auto-lint.sh           # Auto-lint after edits (opt-in)
│   │   ├── auto-format.sh         # Auto-format after edits (opt-in)
│   │   ├── task-complete-notify.sh # Desktop notification on completion
│   │   ├── skill-compliance.sh     # Skill checklist compliance (opt-in)
│   │   ├── skill-extract-reminder.sh  # Skill extraction reminder (opt-in)
│   │   └── project/               # Project-specific hooks (never touched by kit)
│   └── skills/                    # Reusable knowledge
│       ├── _shared/               # Shared template blocks
│       │   └── blocks/            # Reusable content blocks (preamble, scope, etc.)
│       ├── _templates/            # .tmpl skill templates (source of truth)
│       ├── skill-extractor/       # Meta-skill for extracting knowledge
│       ├── skill-generator/       # Meta-skill for generating project skills
│       ├── code-quality-audit/    # Code smells & error handling audit
│       ├── performance-audit/     # Bottleneck & rendering analysis
│       ├── architecture-review/   # SOLID & module boundary review
│       ├── testing-audit/         # Test coverage & quality audit
│       ├── dead-code-audit/       # Unused code detection
│       ├── refactoring-guide/     # Fowler-based refactoring plans
│       ├── accessibility-audit/   # WCAG 2.1 AA compliance
│       ├── dependency-audit/      # Vulnerability & license checks
│       ├── documentation-audit/   # Doc quality & sync audit
│       ├── project-health-report/ # Comprehensive health report
│       ├── ship/                  # Deployment pipeline
│       ├── retro/                 # Sprint retrospective & analytics
│       ├── office-hours/          # Pre-coding product validation
│       ├── debug/                 # Root-cause debugging
│       ├── design-review/         # UI design consistency review
│       └── shape-spec/            # Feature spec folder creation
│
├── scripts/                       # Utility scripts
│   ├── validate.sh                # Validates CODEBASE_MAP completeness
│   ├── statusline.sh              # Terminal status line
│   ├── doctor.sh                  # Installation health checker
│   ├── convert.sh                 # Export agents to Cursor/Windsurf/Aider formats
│   ├── validate-skills.sh         # Validates skill directory structure
│   ├── gen-skill-docs.sh          # Generates web MDX docs from SKILL.md files
│   └── build-skills.sh            # Builds SKILL.md from .tmpl templates + shared blocks
│
├── exports/                       # Agent format exports
│   ├── cursor/                    # Cursor editor format
│   ├── windsurf/                  # Windsurf editor format
│   └── aider/                     # Aider format
│
└── examples/                      # Stack-specific templates
    ├── nextjs/                    # Next.js 16 + App Router
    ├── node-api/                  # Express + TypeScript
    └── python-fastapi/            # FastAPI + SQLAlchemy
```

## Critical Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | The brain — all agent behavior flows from here |
| `.claude/settings.json` | Hook configuration and permission allow/deny lists |
| `agent_docs/workflow.md` | Task lifecycle, research/implementation split, session strategy |
| `agent_docs/contracts.md` | Task contract system for deterministic completion |
| `agent_docs/prompting.md` | Sycophancy awareness and neutral prompting |
| `tasks/lessons.md` | Accumulated corrections — reviewed every session |
| `CLAUDE.project.md` | Project overlay — project-specific rules that survive kit upgrades |
| `.kit-manifest` | Tracks which files are kit-managed vs. project-owned |
| `install.sh` | Entry point for new users |

---

## Architecture

ClaudeCodeKit is not a runtime application — it's a **configuration system** that layers on top of Claude Code CLI. It works through four mechanisms:

1. **Advisory rules** (`CLAUDE.md` → `agent_docs/`) — instructions the agent reads and follows. Can be conditionally loaded based on task type. Enforced by agent compliance, not technically.

2. **Deterministic hooks** (`.claude/hooks/`) — shell scripts that execute at specific lifecycle points (PreToolUse, PostToolUse, Stop). These **cannot be bypassed** by the agent. Exit code 2 blocks the action.

3. **Knowledge accumulation** (`tasks/lessons.md` + `.claude/skills/`) — the agent learns from corrections (lessons) and discoveries (skills) across sessions.

4. **Project overlay** (`CLAUDE.project.md` + `*/project/`) — a separation between kit-managed files (upgradeable) and project-specific customizations (never touched by kit). This allows projects to add stack-specific rules, hooks, and docs without merge conflicts during `--upgrade`.

Key design principle: CLAUDE.md acts as a **logical directory** — it contains minimal rules and conditional pointers to detailed guides. The agent reads only what's relevant to the current task, avoiding context bloat.

---

## Data Flow

```text
Session Start
  → CLAUDE.md (read always, kit base rules)
  → CLAUDE.project.md (read always if exists, project-specific overrides)
  → CODEBASE_MAP.md (read always)
  → tasks/lessons.md (read always)
  → tasks/decisions.md (read always if exists)
  → tasks/handoff-*.md (read latest if exists)
  → agent_docs/{relevant}.md (read conditionally per task type)
  → agent_docs/project/{relevant}.md (read conditionally, project-specific)
  → .claude/skills/ (loaded automatically via semantic matching)

During Work
  → .claude/hooks/ (execute deterministically on every tool call)
  → .claude/hooks/project/ (project-specific hooks, same lifecycle)
  → tasks/todo.md (updated as tasks progress)

Session End
  → tasks/handoff-{date}.md (generated if mid-work)
  → tasks/lessons.md (updated if user corrected agent)

Upgrade (install.sh --upgrade)
  → .kit-manifest (read to identify kit-managed files)
  → Kit files updated, project overlay files skipped
```

---

## External Dependencies

| Service | Purpose | Docs |
|---------|---------|------|
| Claude Code CLI | The agent runtime this kit configures | [docs.anthropic.com](https://docs.anthropic.com) |
| markdownlint | Optional markdown linting | [github.com/DavidAnson/markdownlint](https://github.com/DavidAnson/markdownlint) |

---

## Known Constraints

- This is a template/config kit — it has no source code to build, test, or typecheck
- Hooks must be executable (`chmod +x`) — the install script handles this
- Hooks receive JSON via stdin — parsing is done with grep/cut (no jq dependency). This is fragile with escaped quotes or non-standard formatting but avoids external dependencies
- Skills require Claude Code's semantic matching feature — won't work on older versions
- CODEBASE_MAP.md is intentionally a template with placeholders — projects must fill it in

## Environment

- Config: `.claude/settings.json` (hooks, permissions)
- Local overrides: `.claude/settings.local.json` (gitignored)
- No secrets, no .env files — this kit doesn't handle runtime configuration
