# Task Board

Track current and upcoming tasks here. The agent updates this file as work progresses.

---

## In Progress

### CLA-15 — Skill catalog resolution-order research (docs-only PR)

**Goal**: Decide whether ClaudeCodeKit adopts Spec Kit's extensions/presets architecture, with the verifiable outcome being a written decision (ADR), a kit-facing documentation update, and a concrete follow-up implementation issue or two. Verification: ADR-015 lands; `agent_docs/skills.md` gets the new "Extending the Kit" section; two follow-up Linear issues are open and linked back to CLA-15.

**Context**: Spec Kit ships a 4-tier directory model (`overrides/` > `presets/` > `extensions/` > `core/`) managed via a `specify` CLI. ClaudeCodeKit has overlapping primitives (`_shared/blocks/`, `_templates/`, `hooks/project/`, `.claude-plugin/plugin.json`) but no formal precedence between kit defaults, community contributions, and per-project tweaks. The question is whether to adopt Spec Kit's structure, layer on top, or stay separate.

Linear: [CLA-15](https://linear.app/claudecodekit/issue/CLA-15/adopt-spec-kit-style-extensions-presets-architecture-for-skill-catalog)

### Decision (see ADR-015)

Option C — document a four-layer resolution order using existing kit primitives; do not adopt Spec Kit's CLI or directory names.

Layers:
1. Project-local overrides — `.claude/skills/<name>/SKILL.md` (replaces kit version)
2. Community extensions — `.claude/extensions/<name>/SKILL.md` (sibling to skills/)
3. Project-overlay slot — `.claude/skills/<name>/project/` (additive, kit-aware)
4. Kit core — `.claude/skills/<name>/SKILL.md` (default)

### Approach
1. Author ADR-015 (done in this PR) documenting the research, options, and decision.
2. Author the "Extending the Kit (Resolution Order)" section in `agent_docs/skills.md` (done in this PR).
3. Open two follow-up Linear issues:
   - **Implementation** (P3): create the `.claude/extensions/` placeholder + README; wire `install.sh` to preserve it across upgrades; teach `scripts/validate-skills.sh` to warn on Layer 1 vs Layer 4 name collisions.
   - **Documentation** (P3): add "Spec Kit compatibility" section to README and `web/` docs site explaining the vocabulary mapping.
4. Mark CLA-15 done after follow-up issues open.

### Files to Touch (this PR)
- `agent_docs/skills.md` — new `## Extending the Kit (Resolution Order)` section (between Headless Mode Contract and Skill Lifecycle)
- `tasks/decisions.md` — ADR-015
- `tasks/todo.md` — this plan

### Not Now
- A registry / catalog of community extensions
- A `kit extension add <name>` CLI
- Spec Kit interop (publishing kit's skills as Spec Kit extensions) — wait for demand

---

### v1.11.0 batch — Inspiration triad (rtk + GBrain + karpathy)

Imported from GitHub #105–#116 into Linear (CLA-5 → CLA-11). Single batch, branch per issue, deploy on completion.

- [x] **CLA-5** / GH #105 — `bash-budget.sh` PostToolUse hook (rtk-inspired, signal-only). ADR-005 recorded.
- [ ] **CLA-7** / GH #107 — typed lesson links via frontmatter + `scripts/lesson-graph.sh`. ADR-006.
- [ ] **CLA-6** / GH #106 — session scorecards (enriched `session-end.sh` + `/scorecard` skill). ADR-007.
- [ ] **CLA-8** / GH #108 — KitBench eval harness (`bench/`, `scripts/run-bench.sh`, 15 scenarios). ADR-008.
- [ ] **CLA-9** / GH #114 — Goal-Driven Task Reframing (docs in `agent_docs/workflow.md` + CLAUDE.md pointer).
- [ ] **CLA-10** / GH #115 — explicit "Match existing style" rule (docs in `CLAUDE.md` + `agent_docs/conventions.md`).
- [ ] **CLA-11** / GH #116 — Claude Code plugin marketplace entry (`.claude-plugin/` + manifest). Separate scope — v1.12.0 candidate, included in this batch per user direction.

Ordering rationale: implementation issues first (5 → 7 → 6 → 8) so downstream features can pick up upstream state. Pure docs (9, 10) follow. Plugin marketplace (11) last because it ships an alternate distribution channel separate from kit internals.

---

## Up Next

---

## Done

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
