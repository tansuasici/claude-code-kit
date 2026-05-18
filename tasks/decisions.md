# Architecture Decision Records

Track important technical decisions here so they don't get lost between sessions.

---

## Format

```markdown
### ADR-[number]: [Short title]
- **Date**: YYYY-MM-DD
- **Status**: proposed | accepted | rejected | superseded
- **Context**: [What problem are we solving? What constraint exists?]
- **Options**:
  - A) [Option] — Pros: ... / Cons: ...
  - B) [Option] — Pros: ... / Cons: ...
- **Decision**: [Which option and why]
- **Consequences**: [What changes as a result? Any risks?]
```

---

## Example

### ADR-001: Use Zod for request validation
- **Date**: 2026-03-01
- **Status**: accepted
- **Context**: API endpoints accept user input without validation. Need runtime validation with TypeScript type inference.
- **Options**:
  - A) Zod — Pros: TypeScript-first, small bundle, great DX / Cons: another dependency
  - B) Joi — Pros: mature, battle-tested / Cons: no TS inference, larger
  - C) Manual validation — Pros: no dependency / Cons: error-prone, verbose
- **Decision**: Zod (A). TypeScript inference eliminates duplicate type definitions. Small enough to justify the dependency.
- **Consequences**: All route handlers must validate input with Zod schemas. Schemas live in `src/schemas/`.

---

<!-- Add new decisions below this line -->

### ADR-005: Bash output budget observability (PostToolUse signal hook, non-blocking)
- **Date**: 2026-05-18
- **Status**: accepted
- **Context**: The kit ships 18 hooks watching Edit/Write but zero observability on Bash output. Empirically, Bash output (test logs, diff dumps, find/rg results) is the #1 context-window consumer in agentic sessions — frequently 30K+ tokens before the agent realises compaction is near. Inspired by [rtk](https://github.com/rtk-ai/rtk)'s core observation about command output dominance, but rtk's approach (lossy proxy-rewrite) conflicts with the kit's titiz / fidelity-preserving stance. The gap to close is awareness, not silent compression.
- **Options**:
  - A) **Adopt rtk-style proxy rewrite** — wrap Bash to rewrite verbose output (truncate, summarise). Pros: directly reduces tokens. Cons: lossy, hides information the agent might need, violates "verbatim outputs" expectations, introduces a wrapper layer.
  - B) **Signal-only PostToolUse hook** — track cumulative `len(stdout)+len(stderr)` per session as a `chars/4` token estimate; emit one-shot stderr warning at `$BASH_BUDGET_THRESHOLD` (default 50K). Pros: zero lossy behaviour, deterministic, no deps, low maintenance. Cons: doesn't reduce tokens itself — agent must react.
  - C) **Per-command policy with replacement suggestions** — hook inspects the command and rewrites verbose forms (e.g. `git status` → `git status --short`) before they run. Pros: actually saves tokens. Cons: surprising rewrites, command semantics shift mid-session, breaks scripts that parse output, much more code to maintain.
- **Decision**: B (signal-only). Rationale: the kit's hook philosophy is "measure and block", not "rewrite silently". Awareness + a `Compact Output Flags` table in `agent_docs/conventions.md` lets the agent react with full agency. The hook never alters behaviour; it only annotates the cost.
- **Sub-decisions**:
  - **Threshold default 50000 tokens** — covers ~200K chars stdout, roughly the point where compaction risk becomes material on a 200K-context model.
  - **One-shot warning per session** (`warned: true` latch) — repeating the warning every call past threshold would become noise; the agent already has the signal.
  - **`chars / 4` heuristic, no tokeniser** — deterministic, no Python/tokeniser dependency, accurate enough for a threshold signal (true token count would be marginally different but not directionally).
  - **First two words of the command** as the `by_command_top5` bucket key — distinguishes `git diff` from `git status` without proliferating one-off keys per file argument.
  - **Profile**: standard + strict (mirrors quality-gate). Observability is core, not opt-in.
- **Consequences**:
  - New hook `.claude/hooks/bash-budget.sh` (PostToolUse, matcher `Bash`)
  - New state file `.hook-state/bash-budget.json` (schema_version 1; self-gitignored via existing `.hook-state/.gitignore` pattern)
  - New env var `BASH_BUDGET_THRESHOLD` (escape hatch / tuning knob)
  - `agent_docs/conventions.md` gains a `## Compact Output Flags` reference table
  - `agent_docs/hooks.md` PostToolUse table gains a `Matcher` column (now that two matchers coexist there)
  - The hook reads `tool_response.stdout/stderr` directly via `jq` / `python3` because `lib/json-parse.sh` only handles `tool_input.*`. If a third hook needs `tool_response.*`, factor that into the shared lib.

### ADR-004: Adopt three skill conventions from codex-complexity-optimizer (Core Rule, Default Behavior, Phase 1 Inventory)
- **Date**: 2026-05-18
- **Status**: accepted
- **Context**: The kit's 23 skills had inconsistent structure: Phase 1 named variously ("Scope" / "Scope & Inventory" / "Test Inventory" / etc.), no top-level ethical scope statement, and audit skills required users to specify what to audit instead of producing a report autonomously. While reviewing [codex-complexity-optimizer](https://github.com/Kappaemme-git/codex-complexity-optimizer) (728 stars, 3 days old), three patterns stood out as directly applicable to the kit's existing skill family.
- **Options**:
  - A) **Adopt three patterns** — Core Rule (all 23 skills), Default Behavior + Phase 1 Inventory naming (10 audit skills). Pure markdown changes, no new infrastructure.
  - B) **Adopt the whole complexity-optimizer skill** — drop in as a new skill. Maintenance burden (sync with upstream), overlaps with `performance-audit`.
  - C) **Take inspiration but redesign** — write new skill conventions from scratch. Higher quality bar, but unnecessary — the codex patterns are already well-shaped.
- **Decision**: A (three patterns). Rationale: small, mechanical, immediately useful, doesn't add an outsider skill to maintain. The Phase 1 Inventory framing ("candidates, not findings") solves a real problem we've seen — agents reporting scanner raw counts as final findings.
- **Sub-decisions**:
  - **Audit-class set is explicit (10 skills)**, not heuristic. Codifying which skills get Default Behavior + Phase 1 patterns by name list (`code-quality-audit`, `performance-audit`, `architecture-review`, etc.) avoids classifier drift in `validate-skills.sh`.
  - **Core Rule is universal** (all 23 skills). Even non-audit skills (debug, ship, lesson-refresh) benefit from a one-sentence "deal-breaker" anchor.
  - **Phase 1 framing is uniform text**, not skill-bespoke. Reduces drift, makes the convention scannable.
  - **Validator warns, doesn't fail.** v1 ships as advisory; can promote to fail-block in a future revision after the convention settles.
- **Consequences**:
  - 23 skill SKILL.md files modified (insert Core Rule)
  - 10 of those also got Default Behavior + Phase 1 Inventory framing
  - 3 .tmpl templates updated to match (otherwise `build-skills.sh` would overwrite the patches)
  - 3 new shared blocks created as documentation: `core-rule.md`, `default-behavior.md`, `inventory-framing.md`
  - `scripts/validate-skills.sh` gained 3 new checks (warnings only)
  - `agent_docs/skills.md` documents the conventions
  - Patcher script `/tmp/patch-skills.py` was used for the bulk migration; not committed (one-shot tooling)
  - Future skills should follow the conventions from inception — `skill-generator` skill updates the agent on how

### ADR-003: Hook-shift — move prompt-based discipline rules into deterministic lifecycle hooks
- **Date**: 2026-05-16
- **Status**: accepted
- **Context**: CLAUDE.md enforces "Verification (Mandatory Order)", "Session Boot (Tiered)", "Protected Changes (Approval Required)" via prompt. These depend on model goodwill — Claude can ignore, forget, or skip them. Inspired by Nader Dabit's "Agent Hooks: Deterministic Control for Agent Workflows" (2026-05-15), which argues: *"Use prompts for guidance. Use hooks for behavior that should run every time."* Mapped existing kit hooks against the canonical 6 lifecycle points and identified gaps: no SessionStart, no SessionEnd, no completion gate on Stop, minimal UserPromptSubmit.
- **Options**:
  - A) **Core 3** — Only the highest-leverage gaps: session-start, quality-gate, stop-gate. Skips PreToolUse architectural protection and SessionEnd audit. Lower risk, faster to ship.
  - B) **Full 6** — All six lifecycle points covered: session-start, prompt-router, protect-changes, quality-gate, stop-gate, session-end. Complete framework, larger change, requires `.hook-state/` directory and `.gitignore` update.
  - C) **Minimum (gate only)** — Just quality-gate + stop-gate. Solves the strongest Nader argument (completion gating) but leaves Tier 1 boot and audit as prompt-only.
- **Decision**: B (Full 6). Rationale: the kit's positioning is "disciplined staff engineer behavior" — partial coverage undermines the value prop. Completion gating without auto-context (session-start) leaves a gap where Claude skips Tier 1. Architectural protection (protect-changes) is the second-most-frequent prompt-rule violation per user reports. Once the `.hook-state/` infrastructure is in place, adding the remaining hooks is cheap.
- **Sub-decisions**:
  - **quality-gate profile**: enabled in both `standard` and `strict`. Rationale: deterministic verification is core, not optional. Users on broken test infra use the escape hatch.
  - **stop-gate behavior**: hard-block (exit 2) with `SKIP_QUALITY_GATE=1` env-var escape. Rationale: soft-warn defeats the purpose — completion would still depend on model reading stderr.
- **Consequences**:
  - 6 new hooks: `session-start.sh`, `prompt-router.sh`, `protect-changes.sh`, `quality-gate.sh`, `stop-gate.sh`, `session-end.sh`
  - New transient state directory: `.hook-state/` (gitignored, created on demand by quality-gate.sh)
  - New audit log: `reports/session-audit.log` (gitignored)
  - `CLAUDE.md` rules annotated with `(enforced via <hook>)` where the hook now covers them — prompt remains as documentation of intent
  - `protect-changes.sh` is opinionated about which paths are "architectural" (package.json, requirements.txt, pyproject.toml, Cargo.toml, go.mod, Gemfile, migrations/**, **/auth/**, **/security/**, Dockerfile, build configs, `.github/workflows/**`) — projects loosen the policy by removing the hook from `.claude/settings.json` PreToolUse and adding a custom replacement under `.claude/hooks/project/`. There is no auto-sourcing override mechanism; the swap is explicit in settings.
  - Existing prompt-based rules in `CLAUDE.md` are NOT removed — they continue to serve as documentation and as the source of truth for *why* the hooks exist
  - Upgrade path: `install.sh --upgrade` adds the 6 hooks without overwriting `CLAUDE.project.md` or project-specific hooks

### ADR-002: Squash-only merge for kit and web repos
- **Date**: 2026-04-26
- **Status**: accepted
- **Context**: Past CHANGELOGs (v1.6.0–v1.7.2) showed every PR's bug-fix line *twice*. Each entry came from (1) the original `fix:`/`feat:` commit on the feature branch and (2) the merge commit GitHub creates on `--merge`, whose body auto-inherits the feature branch's HEAD commit subject. release-please's conventional-commits parser saw both and emitted two entries per PR.
- **Options**:
  - A) **Squash merge only** — single commit on `main` with PR title as subject. One changelog entry per PR. Loses intermediate branch commits (acceptable for this repo size).
  - B) **Rebase merge only** — replays each commit on `main` linearly. No merge commit pollution. But every "fix lint" / "address review" commit ends up in changelog separately.
  - C) **Keep merge + filter release-please** — config a regex to drop merge commits. Brittle, depends on release-please internals.
- **Decision**: A (squash only). Disabled `--enable-merge-commit` and `--enable-rebase-merge` at GitHub repo level for both `claude-code-kit` and `claude-code-kit-web` so the wrong strategy can't be selected by mistake.
- **Consequences**:
  - Future PRs must be merged with `gh pr merge --squash` (the only option GitHub now exposes).
  - release-please will produce one changelog entry per PR.
  - Past v1.6.x / 1.7.x duplicate entries remain — git history is immutable, fixing them isn't worth a force-push.
  - Documented in `agent_docs/conventions.md` under "Merging Pull Requests".
