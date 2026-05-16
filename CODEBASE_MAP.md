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
│   ├── architecture-language.md   # Vocabulary for /deepening-review and /interface-design
│   └── project/                   # Project-specific docs (never touched by kit)
│       ├── mission.md             # Product mission and audience (optional template)
│       ├── tech-stack.md          # Technology choices with rationale (optional template)
│       └── roadmap.md             # Current priorities and milestones (optional template)
│
├── tasks/                         # Session state & tracking
│   ├── todo.md                    # Current task board
│   ├── lessons/                   # Self-improvement log (one file per lesson)
│   │   ├── _index.md              #   Top Rules + per-lesson links
│   │   ├── _TEMPLATE.md           #   Template for new lessons
│   │   └── <YYYY-MM-DD>-<slug>.md #   One file per lesson
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
│   │   ├── session-start.sh       # SessionStart: inject Tier 1 context pointers
│   │   ├── prompt-router.sh       # UserPromptSubmit: domain-keyword context injection
│   │   ├── protect-files.sh       # PreToolUse: block edits to secret files
│   │   ├── protect-changes.sh     # PreToolUse: block architectural changes w/o CLAUDE_APPROVED=1
│   │   ├── branch-protect.sh      # PreToolUse: block push to main/force push
│   │   ├── block-dangerous-commands.sh  # PreToolUse: block destructive commands
│   │   ├── conventional-commit.sh # PreToolUse: enforce commit message format
│   │   ├── secret-scan.sh         # PostToolUse: detect secrets in code
│   │   ├── unicode-scan.sh        # PostToolUse: detect invisible Unicode (Glassworm)
│   │   ├── loop-detect.sh         # PostToolUse: edit loop detection
│   │   ├── quality-gate.sh        # PostToolUse: run typecheck/lint, write .hook-state/
│   │   ├── stop-gate.sh           # Stop: block completion when last quality gate failed
│   │   ├── task-complete-notify.sh # Stop: desktop notification on success
│   │   ├── session-end.sh         # SessionEnd: append audit line to reports/session-audit.log
│   │   ├── auto-lint.sh           # PostToolUse: auto-lint after edits (opt-in)
│   │   ├── auto-format.sh         # PostToolUse: auto-format after edits (opt-in)
│   │   ├── skill-compliance.sh    # PostToolUse: skill checklist compliance (opt-in)
│   │   ├── skill-extract-reminder.sh  # UserPromptSubmit: skill extraction reminder (opt-in)
│   │   ├── lib/                    # Shared hook library (json-parse.sh)
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
│       ├── deepening-review/      # Depth/seam paradigm — interactive candidate grilling
│       ├── interface-design/      # Design It Twice — parallel competing interfaces
│       ├── testing-audit/         # Test coverage & quality audit
│       ├── dead-code-audit/       # Unused code detection
│       ├── refactoring-guide/     # Fowler-based refactoring plans
│       ├── accessibility-audit/   # WCAG 2.1 AA compliance
│       ├── dependency-audit/      # Vulnerability & license checks
│       ├── documentation-audit/   # Doc quality & sync audit
│       ├── project-health-report/ # Comprehensive health report (breadth-first, scoring)
│       ├── review-pipeline/       # Parallel multi-audit review with dedupe (PR-scope)
│       ├── lesson-refresh/        # Periodic refresh of tasks/lessons/ (keep/update/encode/archive)
│       ├── pulse/                 # Time-windowed outcome report saved to tasks/pulses/
│       ├── ship/                  # Deployment pipeline
│       ├── retro/                 # Sprint retrospective & analytics
│       ├── office-hours/          # Pre-coding product validation
│       ├── debug/                 # Root-cause debugging
│       ├── design-review/         # UI design consistency review
│       └── shape-spec/            # Feature spec folder creation
│
├── bin/                           # npm distribution entry point
│   ├── claude-code-kit.js         # Node.js entry point for npx
│   └── cli.sh                     # Shell CLI implementation
├── package.json                   # npm package definition
│
├── scripts/                       # Utility scripts
│   ├── validate.sh                # Validates CODEBASE_MAP completeness
│   ├── statusline.sh              # Terminal status line
│   ├── doctor.sh                  # Installation health checker
│   ├── convert.sh                 # Export agents to Cursor/Windsurf/Aider formats (writes to chosen output dir)
│   ├── validate-skills.sh         # Validates skill directory structure
│   ├── gen-skill-docs.sh          # Generates web MDX docs from SKILL.md files
│   ├── gen-agents-md.sh           # Generates cross-tool AGENTS.md from kit sources
│   └── build-skills.sh            # Builds SKILL.md from .tmpl templates + shared blocks
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
| `agent_docs/architecture-language.md` | Shared vocabulary for `/deepening-review` and `/interface-design` |
| `tasks/lessons/_index.md` | Top Rules + index of lesson files — reviewed every session |
| `tasks/lessons/<YYYY-MM-DD>-<slug>.md` | Individual lessons with YAML frontmatter — loaded on-demand |
| `CLAUDE.project.md` | Project overlay — project-specific rules that survive kit upgrades |
| `.kit-manifest` | Tracks which files are kit-managed vs. project-owned |
| `install.sh` | Entry point for new users |

---

## Architecture

ClaudeCodeKit is not a runtime application — it's a **configuration system** that layers on top of Claude Code CLI. It works through four mechanisms:

1. **Advisory rules** (`CLAUDE.md` → `agent_docs/`) — instructions the agent reads and follows. Can be conditionally loaded based on task type. Enforced by agent compliance, not technically.

2. **Deterministic hooks** (`.claude/hooks/`) — shell scripts that execute at six lifecycle points: SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, Stop, SessionEnd. These **cannot be bypassed** by the agent. Exit code 2 blocks the action (PreToolUse) or completion (Stop). Quality-gate writes verification state to `.hook-state/last_quality_gate.json`; stop-gate reads it. Audit log: `reports/session-audit.log`. Both directories are self-gitignored.

3. **Knowledge accumulation** (`tasks/lessons/` + `.claude/skills/`) — the agent learns from corrections (one lesson per file, with YAML frontmatter) and discoveries (skills) across sessions.

4. **Project overlay** (`CLAUDE.project.md` + `*/project/`) — a separation between kit-managed files (upgradeable) and project-specific customizations (never touched by kit). This allows projects to add stack-specific rules, hooks, and docs without merge conflicts during `--upgrade`.

Key design principle: CLAUDE.md acts as a **logical directory** — it contains minimal rules and conditional pointers to detailed guides. The agent reads only what's relevant to the current task, avoiding context bloat.

---

## Data Flow

```text
Session Start (Tiered — see CLAUDE.md "Session Boot")
  Tier 1 — Always:
    → CLAUDE.md (kit base rules; read implicitly by Claude Code)
    → CODEBASE_MAP.md
    → CLAUDE.project.md (if exists, project-specific overrides)

  Tier 2 — If continuing interrupted work:
    → tasks/handoff-*.md (latest, only if one exists)
    → tasks/todo.md (only if active tasks)

  Tier 3 — On demand:
    → tasks/lessons/_index.md "## Top Rules" section (first 15 lines) when relevant
    → tasks/lessons/<YYYY-MM-DD>-<slug>.md individual lesson files only when decisions could repeat past mistakes
    → tasks/decisions.md only when facing architectural choices
    → agent_docs/{relevant}.md per task type (workflow, debugging, testing, etc.)
    → agent_docs/project/{relevant}.md project-specific
    → .claude/skills/ loaded automatically via semantic matching

During Work
  → SessionStart: .claude/hooks/session-start.sh injects Tier 1 context pointers
  → UserPromptSubmit: .claude/hooks/prompt-router.sh routes keyword-matched reminders
  → PreToolUse: protect-files, protect-changes, branch-protect, block-dangerous-commands, conventional-commit
  → PostToolUse: secret-scan, unicode-scan, loop-detect, quality-gate (writes .hook-state/)
  → Stop: stop-gate (reads .hook-state/, blocks on failure), task-complete-notify
  → .claude/hooks/project/ project-specific hooks (same lifecycle)
  → tasks/todo.md updated as tasks progress

Session End
  → .claude/hooks/session-end.sh appends to reports/session-audit.log
  → tasks/handoff-{date}.md may be written manually by the agent when interrupted (not auto-generated by the hook)
  → tasks/lessons/<YYYY-MM-DD>-<slug>.md created if user corrected agent

After Compaction (mid-session context loss)
  → Re-read tasks/todo.md
  → Re-read files actively being edited
  → Re-read tasks/lessons/_index.md "## Top Rules" only

Upgrade (install.sh --upgrade)
  → .kit-manifest read to identify kit-managed files
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
