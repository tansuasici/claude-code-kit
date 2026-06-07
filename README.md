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
npx @tansuasici/claude-code-kit init
```

Or with curl:

```bash
curl -fsSL https://raw.githubusercontent.com/tansuasici/claude-code-kit/main/install.sh | bash
```

Or as a [Claude Code plugin](https://code.claude.com/docs/en/plugins):

```text
/plugin marketplace add tansuasici/claude-code-kit
/plugin install claude-code-kit@claude-code-kit
```

| Path | What you get | When to use |
|---|---|---|
| **npx / curl** | Full kit — CLAUDE.md, agent_docs, all skills, all hooks, agents, scripts, examples | Default. Best when you want the comprehensive discipline layer in your repo. |
| **Plugin marketplace** | Kit as a Claude Code plugin (skills + hooks namespaced under `/claude-code-kit:*`) | Lightweight discovery path; sits alongside other plugins. Does not seed `CLAUDE.md` / `CODEBASE_MAP.md` into your repo. |

Then fill in `CODEBASE_MAP.md` with your project's details and start a Claude Code session.

> **Maintainers:** see [`RELEASING.md`](./RELEASING.md) for the release flow (npm token setup, 2FA mode requirement, EOTP recovery).

### Installer options

| Flag | Description |
|------|-------------|
| `--template nextjs` | Use a stack-specific template (`nextjs`, `node-api`, `python-fastapi`). Auto-detected if omitted. |
| `--profile minimal` | Hooks only, no CLAUDE.md or docs |
| `--profile strict` | All hooks enabled — the 4 opt-in ones too (auto-lint, auto-format, skill-compliance, skill-extract-reminder) |
| `--upgrade` | Add new files without overwriting your customizations |
| `--diff` | Compare local installation against latest kit (read-only) |
| `--gitignore` | Add kit files to `.gitignore` (keep kit local, don't push to repo) |
| `--wiki` | Add knowledge wiki module (personal knowledge base) |
| `--html` | Add HTML artifacts module (specs, reports, PR writeups as HTML — see `ARTIFACTS.md`) |
| `--version v1.0.0` | Install a specific version instead of latest |

### Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/tansuasici/claude-code-kit/main/uninstall.sh | bash
```

| Flag | Description |
|------|-------------|
| `--dry-run` | Show what would be removed without deleting |
| `--keep-tasks` | Preserve `tasks/` directory (lessons, decisions, handoffs) |
| `--keep-project` | Preserve project overlay files (`CLAUDE.project.md`, `agent_docs/project/`, etc.) |
| `--force` | Remove without confirmation |

Examples:

```bash
# Install with npx
npx @tansuasici/claude-code-kit init --template nextjs
npx @tansuasici/claude-code-kit init --profile strict
npx @tansuasici/claude-code-kit init --wiki
npx @tansuasici/claude-code-kit init --html
npx @tansuasici/claude-code-kit init --upgrade

# Or with curl
curl -fsSL .../install.sh | bash -s -- --template nextjs
curl -fsSL .../install.sh | bash -s -- --gitignore
curl -fsSL .../install.sh | bash -s -- --upgrade
curl -fsSL .../install.sh | bash -s -- --diff
curl -fsSL .../install.sh | bash -s -- --version v1.0.0
```

### npx CLI commands

```bash
npx @tansuasici/claude-code-kit init              # Install kit
npx @tansuasici/claude-code-kit doctor            # Check installation health
npx @tansuasici/claude-code-kit skills            # List available /skill commands
npx @tansuasici/claude-code-kit convert all       # Export to Cursor/Windsurf/Aider/AGENTS.md
npx @tansuasici/claude-code-kit generate agents-md  # Generate AGENTS.md only
npx @tansuasici/claude-code-kit --version         # Show version
```

<details>
<summary>Manual install</summary>

```bash
git clone --depth 1 https://github.com/tansuasici/claude-code-kit.git /tmp/cck
cp /tmp/cck/CLAUDE.md /tmp/cck/CODEBASE_MAP.md /tmp/cck/CLAUDE.project.md .
cp -r /tmp/cck/agent_docs /tmp/cck/tasks /tmp/cck/scripts /tmp/cck/.claude .
rm -rf /tmp/cck
```

</details>

## What CLAUDE.md Enforces

| Rule | What it does |
|------|-------------|
| **Tiered Session Boot** | Loads context in 3 tiers (always → if continuing → on demand) to minimize token overhead |
| **Plan First** | Writes a plan for multi-file changes, waits for your confirmation |
| **Scope Discipline** | Touches only what's needed, logs unrelated issues in "Not Now" |
| **Protected Changes** | Stops for approval on deps, schema, auth, API, and build changes |
| **Verification** | Typecheck, lint, test, smoke test — in that order, every time |
| **Self-Improvement** | Logs corrections to `tasks/lessons/` (one file per lesson) and reviews `_index.md` Top Rules each session |

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

Hooks are shell scripts that run automatically — unlike CLAUDE.md rules (advisory), hooks are **deterministic**. The kit ships **23** hooks; the standard profile wires up 19, and 4 are opt-in (they can be slow or conflict with project configs).

**Guardrails — block on violation (PreToolUse / Stop):**

| Hook | Event | What it does |
|------|------|-------------|
| `protect-files` | PreToolUse | Blocks edits to `.env`, credentials, private keys, lock files |
| `protect-changes` | PreToolUse | Blocks edits to dependency manifests, migrations, and auth logic. Build configs block only under the **strict** profile (`CCK_PROTECT_BUILD_CONFIGS=1`); UI under `components/` is exempt |
| `branch-protect` | PreToolUse | Blocks push to `main`/`master` and force pushes |
| `block-dangerous-commands` | PreToolUse | Blocks `rm -rf /`, `git reset --hard`, `DROP TABLE`, etc. |
| `conventional-commit` | PreToolUse | Enforces `feat:`, `fix:`, `refactor:` commit message format |
| `quality-gate` | PostToolUse | Runs typecheck / lint / syntax-check after an edit; records the verdict |
| `stop-gate` | Stop | Blocks completion when the last quality gate failed (bypass: `SKIP_QUALITY_GATE=1`) |

**Context & observability — inject or warn, never block:**

| Hook | Event | What it does |
|------|------|-------------|
| `session-start` | SessionStart | New session: injects Tier-1 pointers, top rules, active task, branch + dirty-tree status, resets session state. After a compaction (`source=compact`): re-injects the working anchors without resetting state |
| `prompt-router` | UserPromptSubmit | Injects a reminder when a prompt touches a sensitive inflection (auth, deps, schema) |
| `secret-scan` | PostToolUse | Warns if API keys, tokens, or passwords are found |
| `unicode-scan` | PostToolUse | Detects invisible Unicode (Glassworm supply-chain attack defense) |
| `loop-detect` | PostToolUse | Detects edit loops — warns at 4, signals at 6 edits to the same file |
| `bash-budget` | PostToolUse | Warns once when cumulative Bash output crosses a token threshold |
| `read-budget` | PostToolUse | Warns once when cumulative file-read output crosses a token threshold (tiered-loading nudge) |
| `subagent-pre` / `subagent-post` | PreToolUse / PostToolUse | Log sub-agent (`Task`) invocations and fold their handoff summaries |
| `session-end` | SessionEnd | Writes a session audit line + scorecard inputs |
| `journal-fold` | SessionEnd | Folds `/note` journal findings into the session handoff |
| `task-complete-notify` | Stop | Desktop notification + sound when Claude finishes |

**Opt-in — not enabled by default:**

| Hook | Event | What it does |
|------|------|-------------|
| `auto-lint` | PostToolUse | Runs linter after edits |
| `auto-format` | PostToolUse | Runs formatter after edits |
| `skill-compliance` | PostToolUse | Checks edited files against active skill checklists |
| `skill-extract-reminder` | UserPromptSubmit | Reminds to extract discoveries as skills |

See `agent_docs/hooks.md` for how to enable the opt-in hooks and write your own.

### KitBench — hooks are tested

The hooks above aren't documentation, they're a contract. The kit ships [`bench/`](bench/README.md): a reproducible eval harness with 38 scenarios covering every blocking hook plus regression tests for past bugs (composer.lock slip-through, `EXIT_CODE=$?` after `|| true`, `.github/workflows/ci.yml` basename-with-slash miss, word-boundary regex rejecting "authentication", stale quality-gate verdict blocking a fresh session). Run it any time with `./scripts/run-bench.sh`; CI runs it on every PR.

```text
KitBench
========================================
  s01-protect-files-blocks-env                      PASS
  s02-protect-files-blocks-composer-lock            PASS
  s03-protect-changes-blocks-package-json           PASS
  ...                                               PASS
========================================
  38/38 PASS  0 FAIL
```

## Auto Mode

Claude Code's **auto mode** (`claude --permission-mode auto`, or `Shift+Tab` to it) auto-approves safe actions and stops only on the risky, irreversible ones — fewer prompts, without the blunt `--dangerously-skip-permissions`. The kit is the floor that makes it safe to turn on:

- The `PreToolUse` blocking hooks (`protect-files`, `protect-changes`, `branch-protect`, `block-dangerous-commands`) fire **before** the auto-mode classifier and hard-block on `exit 2`.
- The curated `permissions.deny` list (`curl`, `wget`, `npm publish`, `cat .env*`, …) resolves before the classifier and can't be overridden by it.

The classifier can only *further* restrict — never un-block — what the kit denies. A repo can't grant itself auto mode (`defaultMode: "auto"` is ignored in project settings), so you opt in at the user level:

```bash
claude --permission-mode auto
```

For the full precedence model, the strict posture (`deny` floor + `disableBypassPermissionsMode`), and the classifier-tuning knobs, see [`agent_docs/auto-mode.md`](agent_docs/auto-mode.md).

## Agents

Built-in agents for code review, planning, and maintenance:

| Agent | What it does |
|-------|-------------|
| `code-reviewer` | Reviews for correctness, quality, and best practices |
| `security-reviewer` | Scans code for vulnerabilities and security issues |
| `qa-reviewer` | Evidence-based QA verification |
| `planner` | Creates implementation plans with 3-lens review and failure modes |
| `dead-code-remover` | Removes verified unused code through static reference analysis |
| `devils-advocate` | Adversarial reviewer — tries to *falsify* a change (assumptions, breaking inputs, quiet reinterpretations); optional lens in `/review-pipeline` |
| `wiki-maintainer` | Knowledge wiki maintenance — ingest, cross-reference, health checks *(requires `--wiki`)* |

## Skills

User-invocable audit and guide skills — run with `/skill-name`:

| Skill | What it does |
|-------|-------------|
| `/code-quality-audit` | Audits code smells, error handling, and maintainability |
| `/performance-audit` | Identifies bottlenecks in startup, rendering, memory, and I/O |
| `/architecture-review` | Reviews SOLID compliance, module boundaries, and dependencies |
| `/deepening-review` | Depth/seam paradigm — surfaces shallow modules and grills the chosen one interactively |
| `/interface-design` | Design It Twice — parallel sub-agents produce competing interfaces, then compare |
| `/testing-audit` | Audits test coverage, quality, and testing strategy |
| `/dead-code-audit` | Detects unused functions, dead imports, and orphan files |
| `/refactoring-guide` | Fowler-based refactoring recommendations with execution plans |
| `/accessibility-audit` | WCAG 2.1 AA compliance audit for UI code |
| `/dependency-audit` | Checks dependencies for vulnerabilities, licenses, and bloat |
| `/documentation-audit` | Audits inline docs, API docs, and README quality |
| `/project-health-report` | Comprehensive multi-dimensional project health report |
| `/ship` | Full deployment pipeline — tests, coverage, CHANGELOG, bisectable commits, PR |
| `/retro` | Weekly retrospective with session analytics and LOC metrics |
| `/office-hours` | Pre-coding product validation — clarify what and why before coding |
| `/debug` | Systematic root-cause debugging with evidence-before-fix enforcement |
| `/design-review` | UI design consistency, AI slop detection, and responsive behavior |
| `/ui-component-builder` | Builds production-ready UI components with accessibility, states, and responsive behavior — not retrofitted polish |
| `/skill-extractor` | Extracts non-obvious knowledge into reusable skills *(supports `mode:headless`)* |
| `/skill-generator` | Generates project-specific coding skills from tech stack analysis |
| `/shape-spec` | Creates timestamped feature spec folders for multi-session planning |
| `/review-pipeline` | Runs multiple audits in parallel over a PR-scope diff, dedupes findings, and saves a confidence-gated report *(supports `mode:headless`)* |
| `/feature-cycle` | End-to-end orchestrator — chains `shape-spec` → `planner` → implement → verify → `/review-pipeline` → `/ship` from a local spec, halting on any gate failure *(supports `mode:headless`)* |
| `/lesson-refresh` | Periodic refresh of `tasks/lessons/` — keep / update / promote / encode / archive verdicts *(supports `mode:headless`)* |
| `/pulse` | Time-windowed outcome report saved to `tasks/pulses/` — what shipped, broke, was learned, is open *(supports `mode:headless`)* |
| `/note` | Appends a timestamped `finding`/`decision`/`summary` to the session journal — across-compaction memory, folded into handoff at session end |
| `/constitution` | Authors `golden-principles.yaml` from a 5-question intake or codebase inference — the rules `/quality-audit` checks against *(supports `mode:headless`)* |
| `/quality-audit` | Audits code against the project's `golden-principles.yaml` and updates `docs/QUALITY_SCORE.md` *(supports `mode:headless`)* |
| `/scorecard` | Per-session scorecard from hook telemetry — quality-gate pass rate, blocks fired, bash budget *(supports `mode:headless`)* |
| `/harness-init` | Scaffolds the harness docs pattern (`docs/ARCHITECTURE.md`, design docs, references) without overwriting existing files *(supports `mode:headless`)* |
| `/references-sync` | Populates `docs/references/<package>-llms.txt` so the agent reads curated library docs on demand *(supports `mode:headless`)* |
| `/doc-gardening` | Prunes stale docs, fixes drift, and refreshes cross-references *(supports `mode:headless`)* |
| `/web-read` | Extracts clean markdown from a URL via the Defuddle CLI to cut tokens vs WebFetch — falls back to WebFetch if the CLI isn't installed |
| `/capabilities` | One-shot briefing of everything the kit makes available here — skills, agents, active hooks, enabled modules — read live from disk |
| `/verification-status` | Renders the per-task verification ledger (auto-gates) and records the manual smoke-test + silent-failure checks CLAUDE.md mandates |
| `/wiki-ingest` | Ingest source into knowledge wiki — summarize, cross-reference, update index *(requires `--wiki`)* |
| `/wiki-lint` | Health-check the knowledge wiki — contradictions, orphans, stale content *(requires `--wiki`)* |
| `/wiki-briefing` | Morning briefing from the wiki — recent activity, new sources, open items *(requires `--wiki`)* |

## Stack Templates

Each template includes a customized `CLAUDE.md` with stack-specific rules and a pre-filled `CODEBASE_MAP.md`:

| Template | Stack | Includes |
|----------|-------|----------|
| `nextjs` | Next.js 16, App Router, Prisma, Tailwind | Server/Client Component rules, build verification |
| `node-api` | Express, TypeScript, Knex.js | Layered architecture, API design conventions |
| `python-fastapi` | FastAPI, SQLAlchemy 2.0, Pydantic v2 | Async patterns, dependency injection, Alembic |
| `go` | Go modules, stdlib-first | Error wrapping, context propagation, `-race` tests, small interfaces |
| `rust` | Cargo, edition-pinned | `Result`/`?` (no `unwrap`), clippy `-D warnings`, `unsafe` gating |
| `django` | Django (+ DRF), ORM | Fat models, migration discipline, N+1 avoidance, settings-via-env |

Auto-detected from your project files (`next.config.*`, `go.mod`, `Cargo.toml`, `manage.py`, `requirements.txt`, `package.json`) when `--template` is omitted.

## Scripts

| Script | What it does |
|--------|-------------|
| `./scripts/doctor.sh` | Checks installation health (missing files, broken hooks, invalid settings) |
| `./scripts/validate.sh` | Checks `CODEBASE_MAP.md` for unfilled placeholders |
| `./scripts/statusline.sh` | Terminal status line showing model, branch, context %, cost |
| `./scripts/convert.sh` | Exports agents to Cursor, Windsurf, Aider, and AGENTS.md formats |
| `./scripts/gen-agents-md.sh` | Generates cross-tool AGENTS.md from project sources |
| `./scripts/validate-skills.sh` | Validates skill directory structure |
| `./scripts/gen-skill-docs.sh` | Generates web MDX docs from SKILL.md files |
| `./scripts/build-skills.sh` | Builds SKILL.md from `.tmpl` templates + shared blocks |
| `./scripts/migrate-lessons.sh` | One-time migration from legacy `tasks/lessons.md` to per-file `tasks/lessons/` structure |
| `./scripts/run-bench.sh` | Runs KitBench — every hook scenario in `bench/scenarios/` (CI runs this on each PR) |
| `./scripts/test-install.sh` | Smoke-tests install → upgrade → uninstall on a throwaway project (CI runs this on ubuntu + macOS) |
| `./scripts/sync-manifest.sh` | Regenerates `.kit-manifest`; `--check` fails CI when it's stale |
| `./scripts/lesson-resurface.sh` | Backs `/lesson-resurface` — returns dormant-lesson pointers matched by topic |
| `./scripts/lesson-graph.sh` | Generates the `tasks/lessons/_index.md` auto-sections from `applies_to` tags |
| `./scripts/note.sh` | Backs `/note` — appends a validated, timestamped line to the session journal |

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

**AGENTS.md Export** — Generate a cross-tool [AGENTS.md](https://agents.md/) file from your project configuration. Compatible with GitHub Copilot, OpenAI Codex, Cursor, Google Jules, and Aider. Source of truth remains `CLAUDE.md` — AGENTS.md is a one-way derived output.

**Tiered Session Boot** — Context loads in 3 tiers to minimize token overhead: Tier 1 (always: project map + overlay), Tier 2 (if continuing: handoff + todo), Tier 3 (on demand: lessons top rules, decisions). Reduces startup token cost ~40-50%.

**npx Distribution** — Install and manage the kit with `npx @tansuasici/claude-code-kit init`. Supports init, upgrade, doctor, convert, and generate commands.

**Session Handoff** — Long sessions lose context. Before ending, Claude generates `tasks/handoff-[date].md`. The next session reads it and resumes where you left off.

**Skill Extraction** — Claude discovers non-obvious things during sessions (framework quirks, workarounds, config gotchas). The skill system captures these as `.claude/skills/<name>/SKILL.md` files that load automatically via semantic matching. Run `/skill-extractor` to review.

**Architecture Decision Records** — When Claude presents options and you pick one, the reasoning gets recorded in `tasks/decisions.md` as ADRs with context, options, and consequences.

**DESIGN.md** — Optional design system template for UI projects. Captures colors, typography, spacing, component styles in a format agents read natively. The `/design-review` skill checks implementation against it.

**Knowledge Wiki** — Optional knowledge wiki module (install with `--wiki`). Based on Andrej Karpathy's LLM Wiki pattern: Claude incrementally builds and maintains a persistent, interlinked wiki from raw sources. Three operations: `/wiki-ingest` processes new sources into the wiki, `/wiki-lint` health-checks for contradictions and orphans, `/wiki-briefing` gives you a daily summary. The wiki compounds — every source you add makes it smarter.

**HTML Artifacts** — Optional module (install with `--html`). Based on the Claude Code team's pattern of preferring HTML output over markdown for specs, plans, PR writeups, reports, and design prototypes — richer information (SVG, tables, code, interactions), easier to share (upload + link), and easier to read for anyone outside your terminal. The kit ships `ARTIFACTS.md` (conventions) and a `design-system.html` reference so every generated artifact stays on-brand. Deliberately ships *without* a `/html` skill — the original recommendation is to just prompt for HTML, not to over-structure it.

**Product Context** — Optional templates in `agent_docs/project/` (mission.md, tech-stack.md, roadmap.md) give agents product awareness beyond code conventions.

**Permissions** — `.claude/settings.json` includes curated allow/deny lists. Allowed: test runners, linters, git reads. Denied: `curl`, `wget`, `.env` reads, `npm publish`. Review and customize for your project.

**Project Overlay** — Separate kit-managed files from project-specific customizations. `CLAUDE.project.md`, `agent_docs/project/`, and `.claude/hooks/project/` are never touched by kit upgrades, so your project rules survive `--upgrade` cleanly.

## What's Inside

<details>
<summary>Full directory structure</summary>

```text
claude-code-kit/
  CLAUDE.md                        # Core agent instructions (kit-managed)
  CLAUDE.project.md                # Project-specific overlay (yours, never overwritten)
  CODEBASE_MAP.md                  # Project mapping template
  AGENTS.md                        # Cross-tool standard (generated by gen-agents-md.sh)
  package.json                     # npm package definition (for npx distribution)
  .kit-manifest                    # Tracks kit-managed files (auto-regenerated by scripts/sync-manifest.sh; CI fails if stale)
  install.sh                       # One-line setup script
  uninstall.sh                     # Clean removal script
  bin/
    claude-code-kit.js             # Node.js entry point for npx
    cli.sh                         # Shell CLI implementation
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
    architecture-language.md       #   Vocabulary for /deepening-review and /interface-design
    project/                       #   Project-specific docs (yours)
  tasks/                           # Session state & tracking
    todo.md, decisions.md, handoff.md
    lessons/                       #   Per-file lessons (YAML frontmatter)
      _index.md                    #     Top Rules + per-lesson links
      _TEMPLATE.md                 #     Template for new lessons
      <YYYY-MM-DD>-<slug>.md       #     One file per lesson
  scripts/                         # Utility scripts
    doctor.sh, validate.sh, statusline.sh, convert.sh, validate-skills.sh, build-skills.sh, gen-skill-docs.sh, gen-agents-md.sh
  # --- Optional: Knowledge Wiki (--wiki) ---
  WIKI.md                          # Wiki schema & conventions
  raw-sources/                     # Immutable source documents (yours)
  wiki/                            # Claude-maintained knowledge base
    index.md, log.md               # Navigation & activity log
    summaries/, entities/, concepts/ # Wiki page directories
  # --- Optional: HTML Artifacts (--html) ---
  ARTIFACTS.md                     # HTML artifact conventions & schema
  artifacts/                       # Generated HTML artifacts
    design-system.html             # Reference tokens — every artifact mirrors these
    index.html                     # Catalog of all artifacts
  .claude/
    settings.json                  # Hook configs & permissions
    agents/                        # code-reviewer, security-reviewer, planner, qa-reviewer, dead-code-remover, wiki-maintainer
    hooks/                         # 22 deterministic hook scripts (lib/ shared helpers)
      project/                     # Project-specific hooks (yours)
    skills/                        # Reusable knowledge & audit skills
      _shared/blocks/              # Shared template blocks (preamble, scope, etc.)
      _templates/                  # .tmpl skill templates (source of truth)
      skill-extractor/             # Meta-skill for knowledge extraction
      skill-generator/             # Meta-skill for generating project skills
      code-quality-audit/          # Code smells & error handling audit
      performance-audit/           # Bottleneck & rendering analysis
      architecture-review/         # SOLID & module boundary review
      deepening-review/            # Depth/seam paradigm — interactive candidate grilling
      interface-design/            # Design It Twice — parallel competing interfaces
      testing-audit/               # Test coverage & quality audit
      dead-code-audit/             # Unused code detection
      refactoring-guide/           # Fowler-based refactoring plans
      accessibility-audit/         # WCAG 2.1 AA compliance
      dependency-audit/            # Vulnerability & license checks
      documentation-audit/         # Doc quality & sync audit
      doc-gardening/               # Docs↔code drift detection
      project-health-report/       # Comprehensive health report
      review-pipeline/             # Parallel multi-audit review (PR-scope)
      quality-audit/               # golden-principles.yaml drift audit
      constitution/                # Author/extend golden-principles.yaml
      references-sync/             # Sync llms.txt-style dependency refs
      harness-init/                # Scaffold docs/ harness structure
      feature-cycle/               # End-to-end lifecycle orchestrator
      lesson-refresh/              # Periodic tasks/lessons/ refresh
      lesson-resurface/            # Surface dormant lessons by topic
      pulse/                       # Time-windowed outcome report
      scorecard/                   # Session-telemetry scorecard
      note/                        # Session-journal note (across compaction)
      ship/                        # Deployment pipeline
      retro/                       # Sprint retrospective & analytics
      office-hours/                # Pre-coding product validation
      debug/                       # Root-cause debugging
      design-review/               # UI design consistency review
      ui-component-builder/        # Production-ready UI component generator
      shape-spec/                  # Feature spec folder creation
      wiki-ingest/                 # Wiki source ingestion (--wiki)
      wiki-lint/                   # Wiki health checks (--wiki)
      wiki-briefing/               # Wiki daily briefing (--wiki)
  examples/
    nextjs/                        # Next.js 16 + App Router template
    node-api/                      # Express + TypeScript template
    python-fastapi/                # FastAPI + SQLAlchemy template
```

</details>

## Project Overlay

The kit separates **kit-managed files** (updated by `--upgrade`) from **project-specific files** (never touched):

| Layer | Files | Managed by |
|-------|-------|------------|
| Kit base | `CLAUDE.md`, `agent_docs/*.md`, `.claude/hooks/*.sh` | `install.sh --upgrade` |
| Project overlay | `CLAUDE.project.md`, `agent_docs/project/`, `.claude/hooks/project/` | You |

Project rules in `CLAUDE.project.md` override kit defaults. Add project-specific docs (offline-first patterns, SignalR conventions, etc.) to `agent_docs/project/` and project-specific hooks to `.claude/hooks/project/`.

The `.kit-manifest` file tracks which files are kit-managed, so upgrades know what to update and what to skip.

## Customization

This kit is a starting point. You should:

1. **Fill in `CODEBASE_MAP.md`** — the more detail, the better Claude performs
2. **Customize `CLAUDE.project.md`** — add project-specific rules, constraints, and patterns
3. **Add project docs** — put stack-specific guides in `agent_docs/project/`
4. **Track lessons** — `tasks/lessons/` compounds over time (one file per lesson, with YAML frontmatter and a Top Rules index), making Claude smarter per-project

## Contributing

PRs welcome. If you've built a template for a stack we don't cover yet, open a PR.

## License

MIT
