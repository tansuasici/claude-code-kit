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

### ADR-006: Typed-relation graph for lessons (zero-LLM, frontmatter-driven)
- **Date**: 2026-05-18
- **Status**: accepted
- **Note**: ADR-005 lives in a sibling v1.11.0 PR (#117 — bash-budget hook). Numbering assumes #117 lands first; if order changes, this becomes ADR-005 and the sibling becomes ADR-006.
- **Context**: `tasks/lessons/` works well at ~10 lessons. At 50+, the flat `_index.md` index loses signal: superseded rules sit next to current ones, the agent can't tell which guidance is fresh, and silent contradictions accumulate. Inspired by [GBrain](https://github.com/garrytan/gbrain)'s **zero-LLM typed-edge knowledge graph** — relations between lessons should be explicit, deterministic, and parseable without inference. The kit can adopt the same pattern at much smaller scale: lesson-to-lesson and lesson-to-decision links carried in YAML frontmatter.
- **Options**:
  - A) **Typed YAML fields + python graph script** — extend `_TEMPLATE.md` with `supersedes`, `applies_to`, `contradicts`, `related_decisions`; ship `scripts/lesson-graph.sh` to parse, validate, and rewrite `_index.md` auto-sections. Pros: deterministic, zero third-party deps (bash + python3 stdlib), fast, idempotent, fits the kit's "ship a script + a template" pattern. Cons: a tiny custom YAML subset to maintain (no nested maps, no block lists — only what the kit's frontmatter actually uses).
  - B) **Adopt a real graph DB / SQLite cache** — store lessons in a structured store, query the index from the store. Pros: scales arbitrarily. Cons: massive overkill for ~10–50 records, introduces runtime + persistence, breaks the kit's "just markdown" promise.
  - C) **LLM-extracted relations** — let Claude infer `supersedes`/`contradicts` by reading lesson bodies on demand. Pros: no schema change. Cons: non-deterministic, expensive at session boot, contradicts the kit's hook philosophy ("use prompts for guidance; use code for behavior that should run every time").
  - D) **Status quo: rely on the `related: []` field + manual `_index.md`** — no schema change, no script. Pros: no work. Cons: the problem the issue describes (silent contradictions, stale Top Rules) is exactly what status quo produces.
- **Decision**: A (typed fields + graph script). Rationale: the kit's whole positioning is *deterministic discipline* — relation extraction must follow the same rule. Bash + python3 + a ~200-line script is the natural shape; it slots next to `migrate-lessons.sh` / `build-skills.sh` / `validate-skills.sh`. The new fields are **additive and optional**, so existing lessons remain valid with no migration cost.
- **Sub-decisions**:
  - **Keep the legacy `related: []` field**. It's free-form and untyped — useful for cross-references that don't fit a typed slot. Removing it would be a breaking change for whoever already filled it in.
  - **Auto-generate four sections, splice into `_index.md` between marker comments**. Markers (`<!-- BEGIN/END AUTO-GENERATED <name> -->`) allow the script to be idempotent and let humans freely add manual prose around them.
  - **Section order**: Top Rules → By Topic → Recently Added → Superseded. Top-of-mind first, archive-of-mind last. Format Reference and Lifecycle (manual prose) live below the auto sections.
  - **Custom YAML parser, not PyYAML**. The kit ships no Python dependencies; PyYAML would force a `pip install` step. The parser handles only the subset the lesson format uses (flat keys, inline lists, scalars) and rejects anything else with a clear error.
  - **`--check` mode for CI / pre-commit**. Exits non-zero when any warning is emitted; teams can wire this into `.github/workflows/validate.yml` without committing the generated `_index.md`.
  - **Lesson-refresh skill consumes the warnings**. New "Phase 1.5: Graph signals" in `SKILL.md` maps each warning class to a verdict bias, so periodic refreshes resolve graph debt as a normal byproduct.
- **Consequences**:
  - `tasks/lessons/_TEMPLATE.md` gains 4 optional frontmatter fields: `supersedes`, `applies_to`, `contradicts`, `related_decisions`
  - New script `scripts/lesson-graph.sh` (bash wrapper + python3 graph + writer)
  - `tasks/lessons/_index.md` restructured: 4 auto-generated sections between markers, manual prose (Format Reference, Lifecycle) follows
  - `.claude/skills/lesson-refresh/SKILL.md` gains a "Phase 1.5: Graph signals" block that maps each graph warning to a verdict bias
  - `install.sh` `--gitignore` listing gains `scripts/lesson-graph.sh` (kit-managed, like its siblings)
  - The shipped example lesson `2026-04-15-example-tsconfig.md` is migrated to use `applies_to: [scope-discipline, tooling]` as a real-world demonstration of the new schema
  - Validation warnings detect: `supersedes-target-missing`, `contradicts-target-missing`, `supersedes-cycle` (transitive), `contradicts-loop` (mutual), `top-rule-but-superseded`

### ADR-007: Session scorecards — structured metrics emitted by SessionEnd, aggregated by /scorecard
- **Date**: 2026-05-18
- **Status**: accepted
- **Note**: ADR numbering assumes the v1.11.0 batch merges in this order — #117 (bash-budget) → #118 (lesson graph) → this PR. If merge order changes, renumber accordingly.
- **Context**: `session-end.sh` already writes a one-line audit record per session, but the v1 line only carries identifiers + `last_quality_gate`. The kit makes behavioral claims ("staff-engineer behavior", "disciplined process") but offers no per-session evidence — those claims remain a vibe question. Inspired by GBrain's `founder scorecard` pattern: structured assertions rolled into a stable JSON contract over time. Without per-session counts of hook fires, quality-gate runs, edits, and bypasses, there's no signal for whether the kit's discipline rules are actually firing.
- **Options**:
  - A) **Schema_version 2 enrichment + dedicated `/scorecard` skill** — extend session-end to aggregate `.hook-state/*` files plus the transcript into a metrics object; add a `/scorecard` skill that reads the windowed audit log and renders a markdown table. Pros: builds on the existing JSONL log (no new persistence layer), keeps v1 parsers working, surfaces a single readable summary. Cons: requires touching every blocking hook to add the counter bump.
  - B) **Telemetry to an external endpoint** — POST per-session metrics to a hosted collector. Pros: enables cross-machine aggregation. Cons: violates the kit's "no external services, no API keys" principle; adds privacy + reliability surface.
  - C) **Pure prompt-based reporting** — at session-end, ask the agent to summarize its own session. Pros: zero infrastructure. Cons: non-deterministic, the agent can omit/inflate, defeats the "deterministic measurement" point.
  - D) **Skip — let users run `/retro` for narrative review** — `/retro` already exists. Pros: no work. Cons: `/retro` is narrative + qualitative; it can't answer "did stop-gate actually fire 3 times this week?" deterministically.
- **Decision**: A (enrich + `/scorecard` skill). Rationale: the schema_version 2 record gives the kit a stable, machine-readable contract; v1 records remain valid (additive change, not breaking); the new `/scorecard` skill closes the loop with a human-readable view. The counter-bump pattern is minimal (one helper call per blocking hook, ~5 lines each); the shared `lib/state-counter.sh` keeps it DRY.
- **Sub-decisions**:
  - **Counter bump on `exit 2` only, not on every hook run**. The metric we want is "how often did the agent try to do something we blocked?", not "how often did the hook fire". A passing run is a non-event; a blocked run is the signal.
  - **`/scorecard` is a skill, not a script**. Aggregation requires judgment about windowing and threshold callouts that fit the agent's natural workflow. A shell script would force users to memorize flags; the skill lets `/scorecard --window 30d` flow naturally.
  - **`lessons_added` and `decisions_added` are mtime-based**, not git-aware. "Was the lesson archive evolved this session?" is the right question; whether the agent created a new file vs. edited an existing one is noise.
  - **`compactions_observed` is best-effort** from transcript parsing. The kit doesn't own Claude Code's transcript wire format, so over/under-counts are acceptable as long as the trend is informative. If the schema changes upstream, this field can be dropped — it's optional.
  - **Profile**: enabled in **standard** and **strict** (same as `quality-gate`). Observability of discipline is core, not opt-in.
- **Consequences**:
  - 5 blocking hooks (`protect-files`, `protect-changes`, `branch-protect`, `block-dangerous-commands`, `stop-gate`) each gain a one-line `bump_counter` call before their `exit 2`
  - `quality-gate.sh` writes both `last_quality_gate.json` (existing) and `quality-gate-history.json` (new cumulative runs / failures / last_status)
  - `stop-gate.sh` bumps `skip_gate_used` in the history file when the `SKIP_QUALITY_GATE` env is honored
  - `session-start.sh` writes `.hook-state/session-meta.json` (session_id, started_at, started_at_epoch) and resets stale `.hook-state/hook-firings.json`, `quality-gate-history.json`, `bash-budget.json` from any prior session
  - `session-end.sh` is rewritten: schema_version 2 records carry the full `metrics` object alongside the v1 top-level fields (timestamp, event, session_id, reason, transcript_path, last_quality_gate). v1 parsers continue to work because the v1 fields are preserved verbatim.
  - New shared lib `.claude/hooks/lib/state-counter.sh` (`bump_counter`, `reset_state`)
  - New skill `.claude/skills/scorecard/SKILL.md` — `/scorecard` invokes the aggregator (read-only against `reports/session-audit.log`)
  - `agent_docs/hooks.md` State Files table grows from 2 rows to 5; new helper lib mentioned in `lib/` reference
  - Backward compat: if `python3` is unavailable on the target machine, `session-end.sh` falls back to the v1 single-line shape. The block counters and quality-gate history simply don't accumulate in that environment.

### ADR-008: KitBench — reproducible eval harness for the kit's deterministic-enforcement claims
- **Date**: 2026-05-18
- **Status**: accepted
- **Note**: ADR numbering assumes the v1.11.0 batch merges in this order — #117 (bash-budget, ADR-005) → #118 (lesson graph, ADR-006) → #119 (session scorecards, ADR-007) → this PR. Renumber on merge order changes.
- **Context**: The kit promises *deterministic enforcement* (ADR-003) and ships 18+ hooks. But hooks are bash scripts whose correctness depends on hard-to-test regex/grep semantics — and the v1.10.0 review caught multiple specific bugs (composer.lock slip-through in `protect-files`, `EXIT_CODE=$?` after `|| true` in `quality-gate`, basename-with-slash miss on `.github/workflows/ci.yml` in `protect-changes`, word-boundary regex rejecting "authentication" in `prompt-router`). Without a regression bench, those bugs were found by accident; the next analogous bug will be found by accident too. Inspired by [GBrain's BrainBench](https://github.com/garrytan/gbrain-evals) — *kits that make behavioural claims should ship benchmarks for those claims*.
- **Options**:
  - A) **Deterministic JSON-scenario harness** — each scenario is a single JSON file in `bench/scenarios/`: hook to run, setup files, stdin payload, env overrides, and expected assertions (exit code, stderr/stdout substrings, state-file fields, file existence). A runner (`scripts/run-bench.sh`) iterates them in isolated temp dirs and prints pass/fail. Pros: zero LLM, zero deps beyond `python3 + bash`, fast (<5s for 15 scenarios), trivial to add regression cases. Cons: doesn't cover end-to-end session behaviour — only the individual hook contracts.
  - B) **LLM-graded end-to-end evals** — drive a real Claude Code session, score the output. Pros: tests the whole stack. Cons: non-deterministic, slow, expensive, and the failure modes the kit cares about (a regex bug missing `.env.production`) don't show up as model-output differences.
  - C) **Per-hook unit tests in bash** — write `bats` or `shunit2` tests next to each hook. Pros: idiomatic for shell. Cons: adds a test framework dependency, harder to express "the state file must contain field X with value Y", harder to make scenarios self-contained portable JSON.
  - D) **Skip — rely on manual smoke testing per PR** — the status quo. Pros: no work. Cons: doesn't catch regressions, doesn't surface as a credibility marker, doesn't scale with the hook count.
- **Decision**: A (JSON-scenario harness). Rationale: matches the kit's existing tooling shape (bash scripts + python3 stdlib for JSON, no third-party deps), produces clear pass/fail output suitable for CI, and the scenario file format is friendly enough that adding a regression case takes <5 minutes (one JSON file, no boilerplate). The deliberate non-coverage of end-to-end Claude Code behaviour is intentional — the bench validates the *kit's deterministic surface*, not model behaviour.
- **Sub-decisions**:
  - **One scenario per file, one assertion bundle per scenario.** Scenarios as a flat list in `bench/scenarios/*.json` (alphabetical by filename = run order). One file per scenario is easier to grep, diff, and review than a multi-document `scenarios.json`.
  - **Each scenario runs in a fresh temp dir.** No shared state between scenarios. `setup_files` provides the initial state. The hook's writes (e.g. `.hook-state/last_quality_gate.json`) stay scoped to that temp dir, then it's deleted.
  - **`{TMPROOT}` / `{KIT_ROOT}` template substitution in string values** lets payloads reference absolute paths inside the per-scenario temp dir.
  - **Runner is `scripts/run-bench.sh`** — bash wrapper around python3, follows the same pattern as `scripts/lesson-graph.sh`. `--scenario`, `--filter`, `--verbose`, `--json` flags. Exit codes: 0 all pass / 1 some failed / 2 runner error.
  - **CI integration via `.github/workflows/validate.yml`** — a new `kitbench` job runs every PR. Failure blocks merge.
  - **`bench/` is kit-internal**, not user-facing. Users running `install.sh` don't get `bench/` — it's only meaningful for kit maintainers running tests on the kit itself. The shipped `scripts/run-bench.sh` exits 2 with a clear message when invoked outside the kit checkout (no `bench/scenarios/` present).
  - **Initial corpus of 15 scenarios** seeded from: (a) the lifecycle hook surface — one happy-path + one failure path per hook contract, and (b) every bug caught during the v1.10.0 code review, converted into a regression scenario. Notably, scenarios s02, s05, s08, s12 are all direct regression coverage of known historical bugs.
- **Consequences**:
  - New top-level `bench/` directory containing `README.md` + `scenarios/sNN-*.json` files
  - New script `scripts/run-bench.sh` (bash wrapper + python3 runner)
  - CI gains a `kitbench` job in `.github/workflows/validate.yml`
  - All 15 initial scenarios pass on the current kit (verified locally on this branch)
  - Adding a regression case is now a single-JSON-file change — no boilerplate, no test framework setup
  - Bench surfaces in `bench/README.md` as a credibility marker; future README work can reference it
  - The bench is local-only, no external services, no API keys

### ADR-009: Ship a Claude Code plugin marketplace entry (scaffold-first)
- **Date**: 2026-05-18
- **Status**: accepted
- **Note**: ADR numbering assumes the v1.11.0 batch merges in this order — #117 (bash-budget, ADR-005) → #118 (lesson graph, ADR-006) → #119 (scorecards, ADR-007) → #120 (KitBench, ADR-008) → this PR. Renumber on merge order changes.
- **Context**: The kit currently distributes via `npx @tansuasici/claude-code-kit init`, `curl install.sh | bash`, and `cargo install --git`. Missing from this list is Anthropic's [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugins) — the canonical discoverability surface for Claude Code users browsing for kits. [karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) ships as both `CLAUDE.md` *and* a marketplace plugin (`/plugin marketplace add forrestchang/andrej-karpathy-skills`), and a meaningful share of its 135K stars likely come from that surface. Without a plugin listing, the kit is invisible to that browse-and-install audience.
- **Marketplace mechanics (from official docs)**:
  - Plugin manifest at `.claude-plugin/plugin.json` (JSON, not YAML)
  - Skills must live at the plugin **root** as `skills/<name>/SKILL.md` — Claude Code does not look in `.claude/skills/`
  - Hooks must live at the plugin root as `hooks/hooks.json` — Claude Code does not consult `.claude/settings.json`'s hooks block from a plugin's perspective
  - Plugins are namespaced: a skill `hello` in plugin `claude-code-kit` becomes `/claude-code-kit:hello`
- **Options**:
  - A) **Scaffold + manifest only (this PR)** — ship `.claude-plugin/plugin.json` + README install path + this ADR. Defer the actual content packaging (skills/, hooks/, agents/) to a follow-up. Pros: ships a real, submittable manifest in v1.11.0; doesn't block the rest of the inspiration triad; no duplication. Cons: clicking install on the marketplace today would give the user metadata but no functional skills/hooks.
  - B) **Full duplication** — copy all 24 skills from `.claude/skills/` → `skills/`, convert `.claude/settings.json` hooks → `hooks/hooks.json`, copy `.claude/agents/` → `agents/`. Pros: works on first install. Cons: every kit change now requires updating two copies; either drift or a build step (deferred infrastructure work).
  - C) **Curated subset** — pick ~3 high-value skills (e.g. `debug`, `ship`, `scorecard`, `lesson-refresh`) and the 5 blocking hooks, duplicate just those. Pros: works on first install with a small surface. Cons: still dual-source-of-truth; the curation criterion becomes a question we have to defend.
  - D) **Build-time generator (`scripts/build-plugin.sh`)** — write a script that copies `.claude/skills/` → `skills/`, converts hooks, and bumps `version` from `VERSION`. Run pre-commit or pre-release. Pros: single source of truth (`.claude/`), generated plugin tree is always fresh. Cons: meaningfully more code; needs CI integration; would balloon this PR.
- **Decision**: A (scaffold-first). Rationale: the v1.11.0 batch is already six issues large, and the *blocker* for marketplace discoverability is the manifest existing in the repo with `version: 1.11.0` and a stable URL — not the contents being functional from day one. Submitting the listing happens after merge anyway (in-app form at [claude.ai/settings/plugins/submit](https://claude.ai/settings/plugins/submit)), giving us a natural moment to land the content packaging in v1.12.0 before the listing goes live. Option D is the right *long-term* shape and should be the next PR after v1.11.0 ships.
- **Sub-decisions**:
  - **`version` field set to current kit version (1.10.0 at PR-open time)** — Claude Code uses this for update tracking. Plumbed forward in v1.11.0 via release-please.
  - **`repository` and `homepage` populated** — homepage points at the web docs site so the marketplace listing has a real landing page.
  - **`license: MIT`** — matches the repo's LICENSE file. Required for community-managed plugins.
  - **No `category` field** — Anthropic's marketplace schema includes a `category` enum (development, security, productivity, etc.) but that lives in the *marketplace.json* registry entry, not in our `plugin.json`. We don't need to pick a category here.
  - **README documents both paths side by side** — keeps npx/curl as the canonical "full kit" install and marks the plugin path as lightweight / discoverable. Avoids the "which do I use?" confusion.
- **Consequences**:
  - New file `.claude-plugin/plugin.json` (JSON manifest, valid against the marketplace schema)
  - `README.md` Quick Start gains a third install path + a comparison table
  - Submission to the marketplace happens out-of-band (manual step by maintainer at `claude.ai/settings/plugins/submit`) — not part of CI
  - **Follow-up required** (v1.12.0 candidate): land Option D — a build step that produces `skills/`, `hooks/hooks.json`, and `agents/` from the `.claude/` sources. Until then, installing via `/plugin install` gives users metadata only.
  - No risk to existing distribution channels: `install.sh`, `npx`, `cargo install --git` are untouched.

### ADR-010: Adopt OpenAI harness-style `docs/` structure as an opt-in scaffold (`/harness-init`)
- **Date**: 2026-05-18
- **Status**: accepted
- **Note**: ADR numbering assumes the v1.11.0 batch merges in this order — #117 (bash-budget, ADR-005) → #118 (lesson graph, ADR-006) → #119 (scorecards, ADR-007) → #120 (KitBench, ADR-008) → #123 (plugin marketplace, ADR-009) → this PR. Renumber on merge order changes.
- **Context**: [OpenAI's harness engineering write-up](https://openai.com/index/harness-engineering/) documented their move from one growing CLAUDE.md / AGENTS.md toward a thin ~100-line CLAUDE.md that points at a structured `docs/` tree (ARCHITECTURE / DESIGN / PLANS / QUALITY_SCORE / RELIABILITY + design-docs/exec-plans/references). Their explicit claim: a single large CLAUDE.md does not scale — *"context limited, too much guidance becomes disorientation, rots fast, hard to verify"*. The kit's current shape mirrors what OpenAI moved away from.
- **Options**:
  - A) **Opt-in scaffold via a new skill** (`/harness-init`) — ship templates in `.claude/skills/harness-init/templates/`, scaffold `docs/` only when invoked, document via a new `## Harness Docs` section in `CLAUDE.md` gated on `docs/ARCHITECTURE.md` presence (same shape as the existing WIKI/ARTIFACTS sections). Pros: zero impact on users who don't want the pattern; mirrors the kit's existing opt-in module shape. Cons: adoption requires explicit user action.
  - B) **Default-on scaffold** in `install.sh` — every `install.sh` run creates `docs/`. Pros: more visible. Cons: opinionated default contradicts the kit's "everything you don't ask for, you don't get" principle; existing projects with `docs/` would conflict.
  - C) **Replace `agent_docs/` with `docs/`** — rename the kit's own structure. Pros: ideological alignment. Cons: breaking change; `agent_docs/` semantics (agent behaviour guides) don't map cleanly onto OpenAI's project-knowledge `docs/`.
  - D) **Skip — point users at OpenAI's write-up if they want it** — no kit support. Pros: zero work. Cons: misses the chance to make the pattern one command away.
- **Decision**: A (opt-in scaffold via `/harness-init`). Rationale: the kit's value is *opinionated discipline*, not *opinionated knowledge architecture*. The harness pattern is genuinely useful past a certain project size, but premature for small ones — exactly the situation that warrants opt-in. The skill ships templates so the scaffold is consistent across users; the `CLAUDE.md → Harness Docs` section is conditional on `docs/ARCHITECTURE.md` existing so it's invisible for projects that haven't scaffolded.
- **Sub-decisions**:
  - **Skill, not script.** `/harness-init` is a `SKILL.md` (Claude reads instructions and creates files) rather than a `scripts/harness-init.sh`. Rationale: the skill needs per-file idempotency decisions, which is easier to phrase as an agent task than to encode in shell. The skill files act as the *contract*; consistency comes from `templates/`.
  - **`agent_docs/` and `docs/` coexist.** `agent_docs/` stays the kit's *agent-facing* guidance (workflow, conventions, hooks). `docs/` is the project's *system-facing* knowledge (architecture, plans, reliability). No rename, no migration — they serve different purposes and the boundary is clear from the directory names.
  - **CLAUDE.md addition is gated on `docs/ARCHITECTURE.md` existence.** Matches the existing `## Design System` / `## Knowledge Wiki` / `## HTML Artifacts` pattern; a no-op for projects that haven't scaffolded.
  - **`docs/QUALITY_SCORE.md` and `docs/references/` are reserved for sibling features** — CLA-13 (`/quality-audit`) writes to QUALITY_SCORE.md; CLA-14 (`/references-sync`) populates `references/`. The seed templates mention this so users know what fills in over time.
  - **CI cross-link freshness check is deferred.** The issue's AC mentioned a CI/lint hook for `docs/` ↔ CLAUDE.md link freshness — a non-trivial markdown-link checker that doesn't fit this PR's scope.
- **Consequences**:
  - New skill at `.claude/skills/harness-init/SKILL.md`
  - 10 template files under `.claude/skills/harness-init/templates/` (README, ARCHITECTURE, DESIGN, PLANS, QUALITY_SCORE, RELIABILITY, design-docs/{index,core-beliefs}, exec-plans/tech-debt-tracker, product-specs/index)
  - `CLAUDE.md` gains a `## Harness Docs` section, conditional on `docs/ARCHITECTURE.md` (same pattern as Knowledge Wiki / HTML Artifacts)
  - `CODEBASE_MAP.md` skill listing adds the new skill
  - Zero effect on users who don't invoke `/harness-init` — the section in CLAUDE.md is inert until they scaffold
  - **Follow-up (v1.12.0 candidate)**: CI cross-link freshness check between `docs/` and `CLAUDE.md`; also an `install.sh --harness` flag that auto-scaffolds on install for users who want it from day one.

### ADR-011: Quality drift audit via `golden-principles.yaml` + separate `/doc-gardening` skill
- **Date**: 2026-05-18
- **Status**: accepted
- **Context**: OpenAI's harness-engineering writeup describes "Fridays for AI cleanup" — periodic background tasks that scan for drift from golden principles, update quality scores, and propose refactors. The pattern doesn't scale at OpenAI when run as one-off rituals; codifying the principles into a YAML and running a deterministic checker does. The kit already has `/code-quality-audit` (generic smells) and `/documentation-audit` (completeness/clarity), but no skill for **project-specific** rules that change per repo, and no skill watching for **doc-vs-code drift** as opposed to doc quality.
- **Options**:
  - A) **Two new skills + YAML schema** — `/quality-audit` reads `golden-principles.yaml` and writes `docs/QUALITY_SCORE.md`; `/doc-gardening` cross-checks docs/ against the codebase. Clean separation of concerns. Each can run on its own `/loop` schedule.
  - B) **Extend `/code-quality-audit`** — add a `golden-principles.yaml` mode to the existing skill. Less surface area but conflates two ideas (generic smells vs project-specific rules) and the report shape differs.
  - C) **One mega-skill** — combine quality drift + doc drift into `/audit-drift`. Single entry point but the YAML schema only applies to half of it, making the skill awkward to extend.
- **Decision**: A (two new skills + YAML). Rationale: the two concerns have different inputs (YAML vs filesystem), different outputs (`docs/QUALITY_SCORE.md` vs `tasks/todo.md → ## Doc Drift`), and different cadences (daily vs weekly per OpenAI's recipe). Separation also lets either skill be turned off without affecting the other.
- **Sub-decisions**:
  - **YAML schema is deliberately minimal** — `id / rule / severity / detect / fix_hint` plus optional `paths / tags / enabled`. No AST queries built in; instead, the `command:` detect type lets users shell out to their own linter/Semgrep/etc. Keeps the skill an orchestrator, not an analyzer.
  - **Severity weights are fixed** (critical=5, major=2, minor=1). Score formula: `max(0, 100 - sum(weight × matches))`. Tunable later if needed, but starting opinionated.
  - **QUALITY_SCORE.md uses managed-block markers** — `<!-- quality-audit:start -->` / `<!-- quality-audit:end -->`. Content outside the block is preserved across runs so users can hand-edit context, trend annotations, etc.
  - **Quality-audit never creates `docs/`** — that's `/harness-init`'s job. Missing `docs/` → print to stdout, never auto-scaffold. Avoids a confusing surprise when a non-harness project runs the skill.
  - **Doc-gardening is heuristic** — false positives are expected. The `.doc-gardening-ignore` glob list + `docs/archive/` suppression keep the noise floor down. Findings are leads for human review, not auto-fixes.
  - **Both skills support `mode:headless`** for `/loop` and `/schedule` integration. Headless mode never opens PRs, never writes files outside the managed block, never asks questions — appends to `tasks/todo.md` instead so humans see results in the next session.
- **Consequences**:
  - 2 new skills: `.claude/skills/quality-audit/SKILL.md`, `.claude/skills/doc-gardening/SKILL.md`
  - 1 template: `.claude/skills/quality-audit/templates/golden-principles.example.yaml` (6 example principles covering type-safety, utils, architecture boundaries, error handling)
  - `CODEBASE_MAP.md` lists both new skills
  - No code outside `.claude/skills/` — both skills are pure markdown instructions; the agent executes detection rules at runtime
  - Pairs naturally with `/harness-init` (ADR-010 in PR #124) — that skill scaffolds `docs/QUALITY_SCORE.md`; this skill maintains it
  - **NOTE on numbering**: ADR-005..010 are reserved by PRs #117..#124 (assumed merge order). If merge order changes, renumber to next free slot at merge time.

### ADR-015: Skill catalog uses a four-layer resolution order; do not adopt Spec Kit's CLI
- **Date**: 2026-05-18
- **Status**: accepted
- **Context**: CLA-15 asked whether ClaudeCodeKit should adopt [Spec Kit](https://github.com/github/spec-kit)'s extensions + presets architecture: a 4-tier priority resolution (`overrides/` > `presets/` > `extensions/` > `core/`) managed through a `specify` CLI (`specify extension add`, `specify preset add`). Spec Kit already supports Claude Code as an integration target, so a coherent answer matters: do we adopt the structure, layer on top, or stay separate?

  Today the kit ships:
  - 25 core skills under `.claude/skills/<name>/`
  - A reusable-blocks system: `.claude/skills/_shared/blocks/` + `.claude/skills/_templates/*.tmpl` + `scripts/build-skills.sh` (only 3 of 25 skills currently use it — code-quality-audit, testing-audit, dead-code-audit)
  - A project-overlay pattern for hooks (`.claude/hooks/project/`) but **not** for skills
  - A `.claude-plugin/plugin.json` that registers the kit as a Claude Code plugin marketplace entry (CLA-11, PR #123)

  The gap: there is no formal precedence between user customization, third-party additions, and kit defaults — only a hooks overlay slot. Users who want a project-tweaked skill currently hand-edit the file the installer wrote, which the next kit upgrade may stomp.

- **Options**:
  - A) **Adopt Spec Kit's directory structure verbatim** — rename `.claude/skills/_templates/` to `.claude/skills/presets/`, create `.claude/skills/extensions/` and `.claude/skills/overrides/`, document the precedence. Pros: instant familiarity for Spec Kit users; clean four-layer mental model. Cons: disruptive rename for installed projects; breaks the `.tmpl` build pipeline by name; suggests the kit will mirror Spec Kit's evolution forever.
  - B) **Adopt Spec Kit's CLI** — ship a `kit extension add <name>` / `kit preset add <name>` command that fetches from a registry. Pros: a polished UX over the directory structure. Cons: enormous scope (registry, versioning, integrity, signature checks); duplicates work the Claude Code plugin marketplace already does; pulls the kit toward "we are a package manager".
  - C) **Document the four layers using existing primitives** — formalise `.claude/skills/<name>/SKILL.md` (project override) > `.claude/extensions/<name>/SKILL.md` (community) > `.claude/skills/<name>/project/` (additive overlay) > `.claude/skills/<name>/SKILL.md` (kit core, when no Layer 1 override exists). Add `.claude/extensions/` to `.gitignore` defaults? No — projects should commit extensions. Update `scripts/validate-skills.sh` to warn on name collisions. Update `agent_docs/skills.md` with the resolution order. Pros: non-breaking; reuses existing primitives; respects the existing plugin marketplace integration. Cons: no familiar CLI; users have to `cp -r` to add an extension.
  - D) **Stay separate** — note that Spec Kit exists, do nothing. Pros: zero work. Cons: the gap stays — project-tweaked skills get stomped on upgrade; no clear place for community extensions; the relationship between kit, Spec Kit, and the plugin marketplace is muddy.

- **Decision**: C. Rationale:
  - The kit's distribution model is fundamentally different from Spec Kit's. Spec Kit is a Python CLI users install into multiple projects and re-run; the kit is a `curl | bash` installer + a `.claude-plugin/` marketplace entry. Adopting Spec Kit's CLI (Option B) duplicates the plugin marketplace's job. Adopting Spec Kit's directory names verbatim (Option A) implies forever-tracking decisions in a project we don't control. Option C captures the *conceptual* clarity (four layers, deterministic precedence, ownership boundaries) using directory names the kit already has muscle memory for.
  - **Vocabulary mapping is documented**, not enforced. `agent_docs/skills.md → Extending the Kit` shows how Spec Kit terminology maps to kit terminology so users coming from one ecosystem can recognise the other.
  - **No new CLI surface.** Adding an extension is a `cp -r` or a plugin marketplace install. The kit's `validate-skills.sh` adds a name-collision warning so accidental shadowing surfaces. That's enough.
- **Sub-decisions**:
  - **Layer 2 directory is `.claude/extensions/`** — sibling to `.claude/skills/`, not nested under it. Reason: extensions are owned by third parties; nesting them under `skills/` would imply kit ownership. The flat sibling makes ownership unambiguous.
  - **Layer 3 (project overlay) is per-skill, not global.** `.claude/skills/quality-audit/project/` holds project-specific content the kit-managed `quality-audit` skill knows to look for. This pattern was already proven by `.claude/hooks/project/`.
  - **No field-level merging.** When Layer 1 overrides Layer 4, the entire SKILL.md is replaced; there's no "merge frontmatter, append sections" magic. Reason: field-merging makes the effective skill non-obvious and breaks the "read one file to see what runs" promise.
  - **The `.tmpl` / `_shared/blocks/` system stays.** It's not a fifth layer — it's a *build-time* mechanism for the kit's own core skills (Layer 4). Renaming `_templates/` to `presets/` would suggest otherwise and was rejected.
- **Consequences**:
  - 1 docs update: `agent_docs/skills.md → ## Extending the Kit` section documenting the four layers + the mapping to Spec Kit vocabulary
  - 1 ADR (this one)
  - 2 follow-up Linear issues:
    1. **Implementation**: create `.claude/extensions/` placeholder + README in the kit repo so it ships as a discoverable slot; update `install.sh` to preserve the directory across upgrades; update `scripts/validate-skills.sh` to warn on Layer 1 vs Layer 4 name collisions.
    2. **Documentation**: add a "Spec Kit compatibility" section to the main README (and the docs site under `web/`) describing the mapping so users coming from Spec Kit don't bounce.
  - **Not now**: a registry / catalog of community extensions, a CLI for installing them, Spec Kit interop (publishing the kit's skills as Spec Kit extensions). All three are deferred until demand surfaces.
  - **NOTE on numbering**: ADR-005..014 are reserved by PRs #117..#128. If merge order shifts, renumber to next free slot.

### ADR-012: `/references-sync` skill ships curated known-sources list; refuses to auto-summarise READMEs
- **Date**: 2026-05-18
- **Status**: accepted
- **Context**: CLA-14 asked for a `/references-sync` skill that auto-generates `*-llms.txt` for project dependencies, modelled on OpenAI's `docs/references/` pattern. The user's own comment on CLA-14 clarified an important constraint: **scope is in-repo agent context, not SEO.** Google explicitly says `llms.txt` does not affect Search visibility. The skill must say so up-front so users don't deploy it expecting marketing wins.

  Two design questions emerged once the SEO scope was settled:

  1. **How does the skill know which packages have llms.txt?** Probing every dependency's homepage is slow, often 404s, and a poor first-run experience. A curated allowlist gives deterministic, fast behaviour at the cost of coverage.
  2. **What about packages without llms.txt?** Auto-summarising the README is tempting but produces stale, misleading reference docs — the same harm `/doc-gardening` is supposed to detect.
- **Options**:
  - A) **Curated `known-sources.yaml` + stub fallback** — ship a small registry (8–12 entries: Anthropic, OpenAI, Stripe, Vercel, etc.). Packages not in the registry get a manually-edited stub. Users extend with `.claude/known-sources.local.yaml`. Honest about coverage; no auto-summarisation.
  - B) **Heuristic discovery** — for each package, try `https://<homepage>/llms.txt`. Fast when it works, noisy when it doesn't. False positives are problematic — partial files, wrong content, 200 responses with marketing pages.
  - C) **Auto-summarise from README** — for any package, fetch the README and use the agent to extract an API summary. Produces real-looking content for every package — and is the most dangerous option because the agent will believe its own output.
- **Decision**: A (curated + stub). Rationale:
  - The curated list is a small, public, kit-maintained artefact. Upstream PRs from users grow it organically.
  - The stub fallback is **deliberately not autogenerated** — it forces the user to capture genuine project-specific knowledge instead of trusting an LLM summary. The kit's whole positioning is "disciplined staff engineer behaviour"; auto-summarisation contradicts that.
  - Heuristic discovery (option B) was rejected because llms.txt at `<homepage>/llms.txt` has no standardised location — too many false positives.
- **Sub-decisions**:
  - **`known-sources.yaml` is shipped with the skill, not at repo root.** Per-project overrides live in `.claude/known-sources.local.yaml`. The skill merges both at runtime.
  - **`status: verified` vs `speculative`** — kit ships entries as `speculative` until someone confirms the URL responds. PRs that flip a source to `verified` include a check date.
  - **30-day TTL on cached files** — refresh budget is non-trivial (each WebFetch costs tokens). Monthly recadence is recommended for `/loop`.
  - **Never auto-fetches transitive deps** — only direct dependencies. Transitive coverage would make `docs/references/` unmanageable.
  - **First-run CLAUDE.md update** — the skill proposes adding a `## Reference Docs` pointer section, but only if `docs/references/index.md` was just created and the section isn't already present. Idempotent on subsequent runs.
- **Consequences**:
  - 1 new skill: `.claude/skills/references-sync/SKILL.md`
  - 3 templates: `known-sources.yaml` (12 entries across npm/pypi), `package-fallback.md`, `references-index.md`
  - `CODEBASE_MAP.md` lists the new skill
  - `scripts/validate-skills.sh` adds `references-sync` to the audit-class allowlist (it follows the Default Behavior + Phase 1 Inventory conventions even though it writes files instead of producing a read-only report)
  - Pairs with `/harness-init` (PR #124 — scaffolds `docs/`) and `/doc-gardening` (PR #125 — flags stale references when packages are removed)
  - Future kit PRs can extend `known-sources.yaml` as more vendors publish llms.txt; the format is intentionally additive
  - **NOTE on numbering**: ADR-005..011 are reserved by PRs #117..#125. If merge order shifts, renumber to next free slot.

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
