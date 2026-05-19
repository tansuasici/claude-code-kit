# Task Board

Track current and upcoming tasks here. The agent updates this file as work progresses.

---

## In Progress

_None — the v1.12.0 candidate batch (CLA-12 → CLA-18, CLA-22) landed on main on 2026-05-19; awaiting the release-please cut._

---

## Up Next

---

## Done

### v1.12.0 candidate batch — Harness foundations + skill catalog architecture

Merged into `main` on 2026-05-19 across PRs #124–#131. Awaiting the next release-please cut.

- [x] **CLA-12** / PR #124 — `/harness-init` skill scaffolds the OpenAI-style `docs/` tree (ARCHITECTURE/DESIGN/PLANS/QUALITY_SCORE/RELIABILITY + design-docs/, exec-plans/, references/). Idempotent.
- [x] **CLA-13** / PR #125 — `/quality-audit` + `/doc-gardening` skills with golden-principles drift detection. Reads `.claude/golden-principles.yaml`; writes audit report.
- [x] **CLA-14** / PR #126 — `/references-sync` skill pulls dependency `*-llms.txt` files into `docs/references/`.
- [x] **CLA-15** / PR #129 — ADR-015 documents the four-layer skill resolution order (project override > community extensions > project overlay > kit core). New `## Extending the Kit (Resolution Order)` section in `agent_docs/skills.md`.
- [x] **CLA-16** / PR #127 — `/tasks-to-linear` skill: one-way sync of the agent's TaskList → Linear issues with title-based dedupe, Todo default state, blocked-by blockquote workaround. ADR-013.
- [x] **CLA-17** / PR #128 — `/constitution` skill authors `golden-principles.yaml` via 5-question intake or codebase inference. Additive-merge; library covers JS/TS, Python, Go. ADR-014.
- [x] **CLA-18** / PR #131 — validator fixes: harness-init + scorecard descriptions trimmed under the 200-char ceiling; both gained `## Output Format` sections; scorecard added `## Distinct from related skills`.
- [x] **CLA-22** / PR #130 — `.claude/extensions/` Layer 2 slot with README; `install.sh` preserves it across upgrades; `scripts/validate-skills.sh` warns on Layer 1 vs Layer 4 name collisions.

Validator on merged main: 30 skills, 300 passed, 0 failed, 0 warnings.

---

### v1.11.0 batch — Inspiration triad (rtk + GBrain + karpathy)

Imported from GitHub #105–#116 into Linear (CLA-5 → CLA-11). Single batch, branch per issue. Released as v1.11.0 (#113) on 2026-05-18.

- [x] **CLA-5** / PR #117 — `bash-budget.sh` PostToolUse hook (rtk-inspired, signal-only). ADR-005 recorded.
- [x] **CLA-7** / PR #118 — typed lesson links via frontmatter + `scripts/lesson-graph.sh`. ADR-006.
- [x] **CLA-6** / PR #119 — session scorecards (enriched `session-end.sh` schema_version 2 + `/scorecard` skill). ADR-007.
- [x] **CLA-8** / PR #120 — KitBench eval harness (`bench/`, `scripts/run-bench.sh`, 15 scenarios). ADR-008.
- [x] **CLA-9** / PR #121 — Goal-Driven Task Reframing (docs in `agent_docs/workflow.md` + CLAUDE.md pointer).
- [x] **CLA-10** / PR #122 — explicit "Match existing style" rule (docs in `CLAUDE.md` + `agent_docs/conventions.md`).
- [x] **CLA-11** / PR #123 — Claude Code plugin marketplace entry (`.claude-plugin/` + manifest). Alternate distribution channel.

Ordering rationale: implementation issues first (5 → 7 → 6 → 8) so downstream features picked up upstream state. Pure docs (9, 10) followed. Plugin marketplace (11) last because it ships an alternate distribution channel separate from kit internals.

---

### #33 — Hook-shift: Move prompt-based discipline rules into deterministic hooks

**Goal**: Replace model-goodwill enforcement of "Verification (Mandatory Order)", "Session Boot Tier 1", and "Protected Changes" with deterministic lifecycle hooks. Inspired by Nader Dabit's "Agent Hooks: Deterministic Control for Agent Workflows" (2026-05-15). See `tasks/decisions.md → ADR-003` for the chosen approach (B — Full 6) and rationale.

- [x] 6 new hooks: `session-start.sh`, `prompt-router.sh`, `protect-changes.sh`, `quality-gate.sh`, `stop-gate.sh`, `session-end.sh` — chmod +x, smoke-tested (16/16 tests passed including regressions)
- [x] `.claude/settings.json` wired (standard profile): all 6 lifecycle slots now active
- [x] `install.sh` strict-profile heredoc mirrors standard profile + opt-in extras (auto-lint, auto-format, skill-compliance, skill-extract-reminder)
- [x] `.hook-state/` and `reports/` self-gitignore (hooks write a local `.gitignore` on first use); kit's own `.gitignore` updated
- [x] `agent_docs/hooks.md` rewritten with new tables, state-file convention, escape hatches (`CLAUDE_APPROVED=1`, `SKIP_QUALITY_GATE=1`), updated profile matrix
- [x] `CLAUDE.md` annotated: Session Boot, Verification, Protected Changes now have "(enforced via <hook>)" pointers
- [x] `CODEBASE_MAP.md` directory listing, Architecture, and Data Flow updated
- [x] `tasks/decisions.md` → ADR-003 recorded
- [x] No regressions: protect-files, secret-scan smoke tests still pass

**Deferred (not now)**:
- Multi-language test runner detection beyond Python/Node/Go/Rust (Ruby, Java, etc.)
- HTTP/MCP-style hook handlers (Nader mentioned these as advanced — out of scope)
- Cross-tool hook adapter (Cursor/Codex/Devin formats — separate task)

---

### #32 — Glassworm Invisible Unicode Detection Hook
- [x] Create `.claude/hooks/unicode-scan.sh` (PostToolUse hook)
- [x] Add to `.claude/settings.json` PostToolUse section
- [x] Update `agent_docs/hooks.md` with documentation
- [x] Update `CODEBASE_MAP.md`
- [x] Test with sample invisible Unicode payloads
- [x] Add to `install.sh` hook configuration

### #29 — Template-based Skill Generation System
- [x] Extract common blocks from existing skills into `skills/_shared/blocks/`
- [x] Create `.tmpl` template versions of existing skills in `skills/_templates/`
- [x] Write `scripts/build-skills.sh` build script (macOS-compatible, uses python3)
- [x] Convert 3 existing skills to templates (code-quality-audit, testing-audit, dead-code-audit)
- [x] Update CODEBASE_MAP.md and install.sh

### #30 — Retro Skill (closed, already implemented)
### #31 — Office Hours Skill (closed, already implemented)

---

## Not Now
