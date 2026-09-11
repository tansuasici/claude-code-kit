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

### ADR-023: Upgrade safety — the preview writes nothing, and a CLAUDE.md is the kit's only if it reads like one
- **Date**: 2026-09-11
- **Status**: accepted
- **Context**: A review of `--upgrade` and `--diff` (ADR-017, ADR-021) reproduced ten ways they lost or misreported user files (TAN-6279). The `--diff` scratch copy kept symlinks, so its upgrade wrote through a linked `.claude/hooks` into the target and the backup went away with the scratch dir. The stale report trusted `.kit-manifest`, which older installs filled with the project's own scripts and skills, and told users to delete them. A retitled pre-baseline `CLAUDE.md` was swapped for an auto-detected template, and a `CLAUDE.md` written by `/init` — its first line is `# CLAUDE.md` too — was replaced as if it were the kit's generic template. An upgrade wrote into the existing file, so another hard link to it lost the user's content, and `chmod +x` over `*.sh` took the run down whenever a broken link sat among them. Smaller ones: the upgrade didn't count files it created outside the per-file path; a relative `--local` broke `--diff`; an upgrade without a hash tool left stale baseline hashes; an existing `.kit-new` was overwritten; .NET detection looked only at the root.
- **Options** (the two rules that needed a choice):
  - A file with no entry in `.kit-baseline`: A) **Replace it, keep the previous copy in `.kit-backup/` and name both in the log** — the route an install from before the record takes. B) Treat it as the user's own: keep it, offer `<file>.kit-new`, record nothing. B was written and then backed out: the record isn't complete enough for it. A plain re-run over an older install records only the two or three files it copied, and a plain upgrade records no module files, so kit files under such a record would be frozen as "yours" and never updated again — one more `.kit-new` per release (60 of them, measured over a few releases). A `#covers` line saying which parts of the kit a record covers repairs B, but the record is written from some fifteen places in `install.sh`, and one of them forgotten brings the freeze back. A file of the user's own replaced with a backup is recoverable; a safety hook frozen at an old version is not visible at all.
  - Stale candidates: A) baseline plus manifest, as before. B) **Baseline only**; in an install with no baseline, manifest paths are shown hedged and not counted. C) Baseline only, manifest ignored — pre-baseline installs would never hear of retired kit files.
- **Decision**: A for the first, B for the second, and:
  - `--diff` copies with `cp -RL`, then deletes any link left (BSD `cp` copies a broken one as a link). The preview names every kit path that is a symlink and where `--upgrade` will write through it.
  - An install "has a baseline" when `.kit-baseline` holds at least one file entry.
  - `CLAUDE.md` on upgrade: `--template` if given, else the baseline's `#template`, else the template its first line names — and that last one only when the file carries the kit's own `## Session Boot` section, since `/init` writes a `# CLAUDE.md` heading too. When none identifies it, it's left untouched and both `--diff` and `--upgrade` say so. Auto-detection only picks the template for a missing `CLAUDE.md`. .NET detection also finds a `.sln`/`.slnx`/`.csproj` up to three levels down when no root marker matches.
  - An update writes a new file — a temp file in the same directory, then `mv` — so another hard link to the old one keeps its content and a read-only kit file is replaced instead of stopping the run. `chmod +x` over the hooks and scripts can no longer end the run when a broken `*.sh` link sits among them.
  - `--upgrade` and `--diff` need `sha256sum`, `shasum` or `python3` and stop before changing anything without one. A fresh install proceeds, warns, and writes no `.kit-baseline`, so its first upgrade takes the no-baseline path rather than reading every file as the user's.
  - A kit copy never overwrites a `.kit-new`: it goes to the first free `.kit-new.<n>`. If an identical copy is already waiting, nothing is written and the file counts as kept.
  - Every file the upgrade creates counts as added. `--local` is made absolute when parsed.
- **Consequences**:
  - A file of the user's own at a kit path — their own `scripts/validate.sh`, say — is replaced by the kit's. The previous copy stays in `.kit-backup/<stamp>/` and the log names it, but the working copy is the kit's.
  - A `CLAUDE.md` the kit never wrote is never touched, so a project that wants the kit's has to ask for it with `--template`.
  - The hedged pre-baseline list appears in `--diff` only: the first upgrade rewrites `.kit-manifest` before its summary.
  - A broken symlink at a kit path still stops a real `--upgrade`, as before; the preview shows it as an addition.
  - `test-install.sh` has a case for each; 27 of its assertions fail against the previous installer.
### ADR-022: The quality gate fails closed — locked, session-scoped state, start-time snapshots, every checkout a session touched
- **Date**: 2026-09-11 (revised 2026-09-12 after a second review)
- **Status**: accepted
- **Context**: A review of the gate (ADR-018, ADR-019) reproduced eight ways a stop got through with a failure on record (TAN-6278):
  - a session whose `cwd` moved into a git worktree read only the worktree's state;
  - a slow scope-wide pass overwrote a later run's failure and re-hashed content it never checked;
  - concurrent writers shared one temp file with no lock (1 of 12 records kept), and a torn state file loaded as empty;
  - a `python3` that exists but fails (the macOS xcode-select stub) read as "no status";
  - a finished check's leftover process held the output pipe past the limit, and the perl fallback leaked the tool it started;
  - a UnicodeEncodeError at stop read as "nothing blocks";
  - a declared command "verified" a file outside the project.

  Nearly every one was a reader or writer error swallowed by `2>/dev/null || true` and read as "nothing failed". A second review of the first fix found more:
  - the broken python3 now failed every valid `.py` edit;
  - an unwritable `.hook-state` or a full disk still lost results under `set -e`;
  - without a usable python3 only the last run counted;
  - an edit into another worktree by absolute path was never read at stop;
  - renaming or deleting a file hid a scope-wide failure;
  - a second session's SessionStart deleted the first session's failures;
  - ending a finished check's process group killed build servers (every dotnet build cold, ~1.0s → ~2.9s) and waited 3s on a TERM-ignoring leftover;
  - a SIGTERM left the check running;
  - stale re-verification had no total time bound.
- **Options**:
  - A) **Patch each case** where it was found. Small, but the next swallowed error fails open the same way.
  - B) **Fail closed at every boundary**: an error reading or writing gate state blocks, and the state itself is safe under concurrency, slow runs and parallel sessions.
- **Decision**: B.
  - **Locked, atomic state.** Every load-modify-save of `quality-gate-state.json` holds an exclusive `fcntl.flock` on `quality-gate-state.json.lock` and writes a unique `mkstemp` file renamed into place. A state that exists but can't be parsed raises; stop-gate blocks with how to reset it.
  - **Unrecordable results block.** A result that can't be recorded makes the run `error`. The file is noted in `.hook-state/quality-gate-unrecorded`, or — when nothing can be written there — in `${TMPDIR:-/tmp}/cck-gate-<key of the project>`, and quality-gate exits 2 so its stderr reaches Claude. stop-gate blocks on noted files until a record exists, and on a `.hook-state` that exists but isn't writable. A project nobody edited is never blocked.
  - **Start-time snapshots.** Runs are numbered at start (`seq`, `runs[scope].started`) with a snapshot of the scope's file hashes (`pending`). A run records nothing once a later run of its scope has started; a scope-wide pass re-covers only files unchanged since it started; the edited file keeps its start-time hash.
  - **Session scope.** Every record carries the payload's `session_id`, and stop-gate answers only for its own session's records; a record or a stop without one counts everywhere. session-start no longer deletes gate state; records older than 7 days are pruned.
  - **Every checkout the session touched.** stop-gate checks the payload's `cwd`, `CLAUDE_PROJECT_DIR`, and every worktree the session stored results in: quality-gate notes those in `CLAUDE_PROJECT_DIR/.hook-state/quality-gate-roots`. Where results are written stays as ADR-018 decided.
  - **Moved content.** A scope-wide failure whose files were all renamed or deleted blocks until the scope runs again; a per-file failure goes away with its file.
  - **No usable python3.**
    - python3 counts only if it runs (`lib/python3.sh`). Without it, quality-gate keeps a plain per-file log, `quality-gate-files.tsv`, with a content stamp (`cksum`, else the mtime). stop-gate reads it with bash alone: the latest line per file wins, and changed files are re-verified.
    - A per-file state that needs python3 to read blocks the session it holds records for.
    - A `.py` edit with neither ruff nor a working python3 is `skipped (tool-unavailable)`.
    - Helper I/O is forced to UTF-8.
  - **Time limits.**
    - The check's process group is killed on timeout, when the hook is signalled (TERM/INT/HUP), or when the hook disappears — not after a normal exit, so build servers stay warm.
    - Output goes to a file, so a leftover can't hold the hook. The perl fallback runs the check in its own group.
  - **Stop budget.**
    - Re-verification stops after `CCK_STOP_REVERIFY_BUDGET` (300s), and each re-run is capped by what is left. Claude Code kills a Stop hook at its timeout (600s by default) and a killed hook doesn't block, so the budget stays well under it.
    - Stale files not re-verified in time block.
    - Any unexpected error in stop-gate exits 2.
  - **Project scope.** `commands.json` applies only to files under the project root.
- **Consequences**:
  - A corrupt or unwritable state blocks until it is fixed or reset (delete `quality-gate-state.json` and `last_quality_gate.json`), or `SKIP_QUALITY_GATE=1` is set.
  - Session scope trusts the payload's `session_id`; hooks run without one (manual runs, doctor) see every record.
  - A subagent's edits in its own worktree block the session's stop too (ADR-018 kept them apart): the session answers for every checkout it touched, not only after merge-back.
  - Without python3 the log is per file: a scope-wide pass doesn't clear other files' failures there; they need their own check. With neither `cksum` nor `date -r`, a changed file can't be told from an unchanged one and blocks as stale.
  - What a finished check leaves running keeps running, by design. Under GNU `timeout` (Linux without python3) a signalled hook doesn't end its check before the limit.
  - KitBench s69–s93 (s89 is a guard that passes before too); s22, s51, s72–s74 and s80 were revised for the new semantics.

### ADR-021: `install.sh --diff` previews by running the real upgrade on a scratch copy
- **Date**: 2026-09-11
- **Status**: accepted
- **Context**: `--diff` had its own comparison code, separate from `--upgrade`. It compared directories at their top level only, so `hooks/lib` and nested skill files were invisible. It reported user-owned `tasks/` and `CODEBASE_MAP.md` as "modified" though the upgrade never touches them, and it couldn't tell an update from a kept edit or a conflict. Its "up to date" meant only "no new files". It said nothing about stale kit files or hook registrations, and it ignored `--local`, so it couldn't be tested. (TAN-6277)
- **Options**:
  - A) **Fix the separate comparison** to mirror the upgrade's rules. Two implementations of the same decisions, bound to drift.
  - B) **A dry-run flag threaded through the installer** — every write guarded. Exact, but it touches every copy site and is easy to break.
  - C) **Run the target version's own `--upgrade` on a scratch copy** of the project's kit-managed files, then compare the copy with the project.
- **Decision**: C. The preview is exactly what the upgrade does — same code, same decisions — and nothing in the project changes. The findings the upgrade can't fix on its own are shared by `--diff` and the `--upgrade` summary:
  - **stale** — files the install record says the kit put there, which the kit no longer ships;
  - **unregistered** — standard kit hooks missing from `.claude/settings.json`;
  - **dangling** — registrations whose script doesn't exist.

  `.claude/settings.json` is never modified.
- **Consequences**:
  - `--diff` needs python3 and copies the kit-managed paths plus root marker files to a temp dir (seconds, small).
  - It honors `--local`, `--version`, `--profile`, `--template`, `--wiki` and `--html`, exactly as `--upgrade` would.
  - `test-install.sh` checks that the upgrade after a preview changes exactly what the preview named.
- **Amended 2026-09-11 (TAN-6279, ADR-023)**: the scratch copy follows symlinks and then drops any link left, so the scratch upgrade can't write outside it; the preview names kit paths that are symlinks. "Stale" now needs a `.kit-baseline` entry. The upgrade counts every file it creates, so the preview's "to add" equals its "added".

### ADR-020: commands.json — an absent key auto-detects, "" turns a check off, anything unknown is an error
- **Date**: 2026-09-11
- **Status**: accepted
- **Context**: `.claude/commands.json` is the single source of truth for the quality gate, `/ship` and the qa-reviewer, but it had no schema. A typo such as `"typcheck"` was silently ignored — the declared check never ran and the gate guessed a different one. `""` and an absent key both meant "fall back to guessing", so a project couldn't say "we have no lint"; whatever the gate guessed then counted as the project's check. There was no way to set the per-edit time limit, the fast/full split was implicit, and `doctor.sh` only warned about a broken file.
- **Options**:
  - A) **Stay lenient** — ignore unknown keys. Keeps odd files working; keeps typos invisible.
  - B) **Strict, stdlib-only validation** in `lib/project-commands.sh`, shared by the gate, stop-gate and doctor — known keys plus `"//"` comments and the legacy `commands` wrapper; `""` means "off".
  - C) **A JSON Schema file with a validator.** Standard, but it adds a dependency for six keys.
- **Decision**: B.
  - Keys: `typecheck`, `lint` (fast — the per-edit gate), `test`, `build`, `smoke` (full — `/ship` and the qa-reviewer, never per edit), `timeout` (seconds for the per-edit check; `CCK_QUALITY_GATE_TIMEOUT` wins).
  - Absent → auto-detect. `""` → the check is off: the gate records `skipped (disabled)` — NOT verified, never passed, nothing guessed — and `/ship` / the qa-reviewer report the step as not applicable.
  - An unknown key, a non-string command, or a non-positive `timeout` is a config `error`: the gate blocks and `doctor.sh` fails, naming the problem.
- **Consequences**:
  - A file with keys the kit doesn't read (say `"format"`) now blocks code edits until they're removed or turned into `"//"` comments; the error message says so.
  - KitBench s66–s68; `test-install.sh` covers doctor on a mistyped and a valid file.
- **Amended 2026-09-11 (TAN-6278)**: the file is read as `utf-8-sig`, so a BOM is accepted; a non-finite `timeout` (`NaN`, `Infinity`, `1e400`) is a config error like a non-positive one (KitBench s78, s79).
- **Amended 2026-09-11 (TAN-6280)**: for TypeScript and C# the gate reads `typecheck`, then `lint`. `""` on one hands the edit to the other — to auto-detection when the other is absent — and only an edit whose applicable checks are all `""` is recorded as `skipped (disabled)`. The code always worked this way (it errs toward running a check); "nothing guessed" above overstated it for a single `""`.

### ADR-019: Quality-gate results are per file, scoped and hash-checked, with explicit statuses
- **Date**: 2026-09-11
- **Status**: accepted
- **Context**: The gate kept one record — the last run — and `stop-gate.sh` blocked only when it said `failed`. So a pass on `b.py` closed a failure on `a.py`; a file no check covers (`.rb`, `.cs`, a `.ts` without tsconfig) exited silently and left an older pass standing for unchecked code; a pass stayed valid after the file changed; a missing declared command (exit 127) read as a code failure, and a malformed `commands.json` was treated as "nothing declared", silently switching to a different check. Its "FAILED" message went to stderr at exit 0, which the hooks docs confirm only reaches the debug log — Claude never saw it. (TAN-6272)
- **Options**:
  - A) **Keep one record, add fields.** Small, but the overwrite problem is structural.
  - B) **One record per edited file, keyed by the check scope that covered it, with the file's content hash.** A scope-wide pass re-covers the files in its scope.
  - C) **Re-run every check at stop.** Always current, but slow at every turn end and duplicates the per-edit gate.
- **Decision**: B, in `lib/gate-state.sh`, with `.hook-state/quality-gate-state.json` (schema v2).
  - Verified = the scope's latest run passed **and** the file's sha256 is unchanged.
  - Statuses: `passed` · `failed` · `timeout` · `error` (exit 126/127, invalid `commands.json`) · `skipped` + reason (`unsupported-language`, `tool-unavailable`, `no-config`). `failed`, `timeout` and `error` block.
  - Stale files (changed after their check, or a check that never finished) are re-verified by `stop-gate.sh` through `quality-gate.sh` — one file per scope, at most 3 — rather than trusted or blocked blindly.
  - A skipped code file never counts as passed: Claude is told once, via PostToolUse `additionalContext`, that it is NOT verified; it is listed at stop without blocking. Docs, config and markup files, and files without an extension, aren't gated. `.sh` / `.bash` get `bash -n`.
  - `last_quality_gate.json` stays as a summary (latest run plus overall verdict and file lists) for `session-end.sh` and older readers; `stop-gate.sh` falls back to it only when no v2 state exists.
- **Consequences**:
  - A file stays blocked until its own check (or its scope's) passes; unrelated activity can no longer clear it.
  - Only Edit/Write/NotebookEdit edits are tracked; a file changed purely through Bash that Claude never edited is outside the gate, as before.
  - Stop can take up to three check runs longer when files went stale.
  - KitBench s54–s61; s54–s58, s60 and s61 fail against the previous hooks.
- **Amended 2026-09-11 (TAN-6278)**: the state is written under a lock and read fail-closed; runs are numbered with start-time hash snapshots so a late pass can't cover content it didn't check — see ADR-022.

### ADR-018: Hook results are keyed by git worktree; checks run under a process-group time limit
- **Date**: 2026-09-11
- **Status**: accepted
- **Context**: `CLAUDE_PROJECT_DIR` stays at the directory the session started in, even when Claude or an isolated subagent works in a git worktree; the hook payload's `cwd` follows. `quality-gate.sh` anchored its verdict to `CLAUDE_PROJECT_DIR`, so a subagent's failure in its worktree blocked the main checkout's stop — or its pass cleared a real failure there — and declared checks ran against the main checkout's code, not the worktree's. Every root walk-up tested `-d .git`, which is false in a worktree, where `.git` is a file. Checks also ran unbounded wherever GNU `timeout` is missing (stock macOS), and GNU `timeout` signals only the direct child: a hanging declared check took 30.3s and was then recorded as `passed`. (TAN-6270)
- **Options**:
  - A) **Key state by `agent_id`** (subagent vs main session). Cons: a main session that enters a worktree still mixes results; it doesn't change which tree the check runs against.
  - B) **Key state by git worktree** — a result for a file in *another worktree of the same repository* (same git common dir) goes to that worktree's `.hook-state/`; `stop-gate.sh` reads the state for the payload's `cwd`.
  - C) **Status quo**, relying only on the merge-back re-verify in `agent_docs/worktrees.md`.
- **Decision**: B, in a shared `lib/roots.sh` that also separates the package root (where a check runs) from the project root (where its result is stored).
  - Only same-repository worktrees move. A nested independent repo or a submodule keeps the project's state, where `stop-gate.sh` reads it.
  - Session-level metrics (`bash-budget.json`) stay in `CLAUDE_PROJECT_DIR/.hook-state/`, where `session-start.sh` resets and `session-end.sh` reads them.
  - Time limit: `lib/run-with-timeout.sh` starts the check in its own process group and on timeout sends the group SIGTERM, then SIGKILL, and exits 124. Fallbacks: GNU `timeout -k`, a perl alarm, and — only with none available — an unbounded run with a warning. A timeout is recorded as a new status, `timeout`, which blocks like `failed`. `CCK_QUALITY_GATE_TIMEOUT` sets the limit (default 30s).
- **Consequences**:
  - The main session's stop no longer sees a subagent worktree's gate result; the merge-back re-verify is what checks it. Scorecard metrics for edits made inside a worktree land in that worktree.
  - KitBench gains `steps`, `setup_commands`, `cwd`, `max_seconds` and `no_process`, plus s51 (worktree isolation), s52 (fix unblocks stop) and s53 (timeout kills the check). s51 and s53 fail against the previous hooks.
- **Amended 2026-09-11 (TAN-6278)**: a session's stop checks every checkout it touched — its `cwd`, `CLAUDE_PROJECT_DIR`, and worktrees it stored results in — so a subagent's worktree result now blocks the session's stop too; see ADR-022.

### ADR-017: `--upgrade` updates kit-managed files against a per-file install baseline
- **Date**: 2026-09-11
- **Status**: accepted
- **Context**: `install.sh --upgrade` copied a kit file only when it was missing, while bumping `VERSION`. Measured 1.21.0 → 1.21.1: 17 kit-managed files stayed stale — 9 hooks including every SIGPIPE-fixed safety hook, 4 scripts, `CLAUDE.md`, skill files — and the log said only "No new files". That contradicted `--help` and the README ("kit-managed files are updated by `--upgrade`"), and every later fix would have missed existing installs the same way. (TAN-6269)
- **Options**:
  - A) **Overwrite every kit file.** Simple; silently destroys local edits to kit files.
  - B) **Stay add-only and document it.** Honest, but leaves every install on stale safety hooks.
  - C) **Three-way against a per-file baseline** — record the hash of what the kit installed at each path; on upgrade update untouched files, keep edited ones, and write the kit's version beside a file both sides changed.
- **Decision**: C.
  - New sidecar `.kit-baseline` (`sha256<TAB>path` lines plus a `#template` line), written on install and upgrade and listed in `.kit-manifest`, so uninstall removes it. `.kit-manifest` keeps its path-only format — `uninstall.sh` and `sync-manifest.sh` read it.
  - Per file: missing → added · equal to kit → unchanged · equal to baseline → updated · edited and kit unchanged → kept · edited and kit changed → kept, kit copy written to `<file>.kit-new` (conflict).
  - Installs from before the baseline existed can't tell an edit from an older kit file: changed files are replaced and the previous copies saved to `.kit-backup/<UTC stamp>/` (ignores itself in git).
  - User-owned paths stay seed-only: `tasks/`, `CODEBASE_MAP.md`, the overlays, `artifacts/`. `settings.json` is still not merged; its baseline is recorded for the later merge work.
  - `CLAUDE.md` keeps the template it was installed from (baseline `#template`, else its first-line heading), so auto-detection on today's tree can't swap it for another template.
  - Hashing uses `sha256sum`, then `shasum -a 256`, then `python3`. With none available every differing file takes the pre-baseline path (backup + replace).
- **Consequences**:
  - The upgrade log ends with `updated · added · unchanged · kept · conflicts`; a quiet log can no longer hide what changed.
  - A conflict is reported once: the baseline records the version offered, so later upgrades keep the file quietly until the kit changes it again.
  - `test-install.sh` covers each case plus a pre-baseline install; the same tests fail 10× against the previous installer.
  - `--diff` reporting of leftover files and missing or dangling settings registrations is left to a follow-up.
- **Amended 2026-09-11 (TAN-6279, ADR-023)**: a file with no entry always takes the backup-and-replace path, whatever the record holds, and the log names the file and its backup. A kit copy never overwrites a `.kit-new` (it goes to `.kit-new.<n>`). An existing `CLAUDE.md` is never given an auto-detected template, and counts as the kit's only when it carries the kit's own sections; otherwise it's left untouched. An update writes a new file (temp + `mv`), so another hard link to a kit file keeps its content. With no hash tool `--upgrade` now stops before changing anything — "every differing file takes the pre-baseline path" above no longer holds.

### ADR-016: protect-changes scopes auth + build-config blocking by intent and profile
- **Date**: 2026-05-25
- **Status**: accepted
- **Context**: `protect-changes.sh` runs in the standard (default) profile and blocked every edit under any `*/auth/*` directory plus all build configs (tsconfig, next.config, tailwind.config, vite, webpack, Dockerfile, …). On a typical frontend that meant frequent `BLOCKED` prompts on presentational components (e.g. `components/auth/LoginForm.tsx`) and on routinely-edited config files — training users to set `CLAUDE_APPROVED=1` globally (which defeats the gate) or uninstall. (CLA-48)
- **Options**:
  - A) **Status quo** — keep blanket blocking. Pros: maximal caution. Cons: false-positive fatigue erodes the gate's credibility; users bypass it wholesale.
  - B) **Drop auth + build-config protection entirely.** Pros: zero friction. Cons: loses genuine protection on two areas where a staff engineer most wants a pause.
  - C) **Scope by intent + profile** — keep auth-logic, dependency, migration, and CI blocking always; exclude presentational UI from the auth match; make build-config blocking opt-in per profile.
- **Decision**: C.
  - **Auth:** skip paths under `*/components/*` (UI, not auth logic). Backend auth logic (`src/auth/`, `lib/auth/`, `middleware/auth*`, `*/security/*`, `*/permissions/*`) still blocks.
  - **Build configs:** hard-block only when `CCK_PROTECT_BUILD_CONFIGS=1`. The strict profile sets it via `settings.json → env`; the standard profile emits a non-blocking heads-up instead.
  - Dependency manifests, migrations/schema, and CI workflows block unconditionally in every profile — unchanged.
- **Consequences**:
  - `protect-changes.sh` gains a `*/components/*` skip and the env gate; the header documents `CCK_PROTECT_BUILD_CONFIGS`.
  - The strict profile's settings add `"env": { "CCK_PROTECT_BUILD_CONFIGS": "1" }`. (Originally an embedded `generate_strict_settings()` heredoc in `install.sh`; extracted in TAN-4689 to the committed `.claude/settings.strict.json`, generated from `settings.json` + the strict delta via `scripts/gen-strict-settings.sh` and drift-checked in CI.)
  - KitBench gains s23 (strict blocks build config), s24 (standard warns), s25 (UI component allowed); s06 (backend auth still blocks) unchanged.
  - README hooks table marks build-config blocking as strict-only.

### ADR-015: Skill catalog formalised as a four-layer resolution order using existing primitives
- **Date**: 2026-05-18
- **Status**: accepted
- **Context**: The kit had grown three overlapping but uncoordinated mechanisms for skill customization, plus one external distribution channel, with no documented precedence between them:

  1. `.claude/skills/<name>/SKILL.md` — the kit installs these; users sometimes hand-edit them, and a kit upgrade may stomp those edits.
  1. `.claude/skills/_shared/blocks/` + `.claude/skills/_templates/*.tmpl` + `scripts/build-skills.sh` — a build-time block-substitution system that only 3 of 25 core skills use today (code-quality-audit, testing-audit, dead-code-audit).
  1. `.claude/hooks/project/` — a per-system project-overlay slot for hooks; no analogous slot exists for skills.
  1. `.claude-plugin/plugin.json` — the external channel. Registers the kit as a Claude Code plugin marketplace entry (CLA-11, PR #123). Community contributions ride this channel today but have no kit-local file location to land in.

  Two gaps emerged: (a) there is no formal precedence between user customization, third-party additions, and kit defaults; (b) there is no kit-local directory for third-party skills installed via the plugin marketplace or copied in by hand. The ADR closes both.

- **Options**:
  - A) **Status quo** — note the mechanisms exist, do nothing. Pros: zero work. Cons: project-tweaked skills get stomped on upgrade; no clear place for community extensions; new contributors have to read the install script to discover the precedence.
  - B) **Rename existing directories to enforce a hierarchy** — promote `_templates/` to a top-level `presets/`, create top-level `extensions/` and `overrides/` directories, document the precedence in the rename. Pros: tidy, top-down naming. Cons: disruptive rename for every installed project; breaks the `.tmpl` build pipeline by name; conflates build-time and runtime concerns.
  - C) **Ship a package-manager CLI** — `kit extension add <name>` / `kit preset add <name>` fetches from a registry. Pros: polished UX. Cons: enormous scope (registry, versioning, integrity, signature checks); duplicates what the Claude Code plugin marketplace already does; pulls the kit toward "we are a package manager".
  - D) **Document the four layers using existing primitives** — formalise `.claude/skills/<name>/SKILL.md` (project override) > `.claude/extensions/<name>/SKILL.md` (community, new sibling directory) > `.claude/skills/<name>/project/` (additive overlay) > `.claude/skills/<name>/SKILL.md` (kit core, when no Layer 1 override exists). Add `.claude/extensions/` as a new kit-managed slot. Update `scripts/validate-skills.sh` to warn on name collisions. Update `agent_docs/skills.md` with the resolution order. Pros: non-breaking; reuses existing primitives; respects the existing plugin marketplace integration. Cons: no familiar CLI; users have to `cp -r` to add an extension (or install a plugin).

- **Decision**: D. Rationale:
  - The kit's distribution model is `curl | bash` + the Claude Code plugin marketplace. Option C duplicates the marketplace's job. Option B is disruptive for every installed project and conflates build-time templates with runtime layers. Option A leaves the gap open. Option D captures the *conceptual* clarity (four layers, deterministic precedence, ownership boundaries) using directory names the kit already has muscle memory for, and adds only one new directory (`.claude/extensions/`).
  - **No new CLI surface.** Adding an extension is a `cp -r` or a plugin marketplace install. The kit's `validate-skills.sh` adds a name-collision warning so accidental shadowing surfaces. That's enough.
- **Sub-decisions**:
  - **Layer 2 directory is `.claude/extensions/`** — sibling to `.claude/skills/`, not nested under it. Reason: extensions are owned by third parties; nesting them under `skills/` would imply kit ownership. The flat sibling makes ownership unambiguous.
  - **Layer 3 (project overlay) is per-skill, not global.** `.claude/skills/quality-audit/project/` holds project-specific content the kit-managed `quality-audit` skill knows to look for. This pattern was already proven by `.claude/hooks/project/`.
  - **No field-level merging.** When Layer 1 overrides Layer 4, the entire SKILL.md is replaced; there's no "merge frontmatter, append sections" magic. Reason: field-merging makes the effective skill non-obvious and breaks the "read one file to see what runs" promise.
  - **The `.tmpl` / `_shared/blocks/` system stays.** It's not a fifth layer — it's a *build-time* mechanism for the kit's own core skills (Layer 4). Renaming `_templates/` to `presets/` would suggest otherwise and was rejected.
- **Consequences**:
  - 1 docs update: `agent_docs/skills.md → ## Extending the Kit` section documenting the four layers
  - 1 ADR (this one)
  - 1 follow-up Linear issue (**CLA-22**, Improvement, Todo): create `.claude/extensions/` placeholder + README in the kit repo so it ships as a discoverable slot; update `install.sh` to preserve the directory across upgrades; update `scripts/validate-skills.sh` to warn on Layer 1 vs Layer 4 name collisions.
  - **Not now**: a registry / catalog of community extensions, a CLI for installing them. Both are deferred until demand surfaces.
  - **NOTE on numbering**: ADR-005..014 are reserved by PRs #117..#128. If merge order shifts, renumber to next free slot.

### ADR-013: `/tasks-to-linear` is one-way, dedupes by exact title, encodes blocked-by as a description blockquote
- **Date**: 2026-05-18
- **Status**: accepted
- **Context**: CLA-16 asked for a skill that pushes the agent's TaskList to Linear as discrete issues — turning the in-session plan into durable project-tracker entries without a manual round trip. Three contract questions had to be settled before writing the skill, because they shape every other detail:

  1. **Direction.** One-way (TaskList → Linear) or bidirectional (also pull Linear state back into TaskList)?
  2. **Dedupe.** How does the second run of the skill avoid recreating the same issue?
  3. **Relations.** Linear supports `blockedBy`/`blocks`/`relatedTo`, but the MCPs available in the ClaudeCodeKit workspace today do not expose those fields on create or edit. How is the dependency edge represented?

- **Options**:
  - **Direction**
    - A) One-way (TaskList → Linear), no reverse sync
    - B) Bidirectional with a tracked `linear_id` per task
  - **Dedupe**
    - C) Exact title match within the configured team
    - D) Track `linear_id` in task metadata and look up by ID
    - E) Hash of `title + first 200 chars of description`
  - **Relations**
    - F) Skip — drop the edge, since neither MCP exposes it
    - G) Encode as a Markdown blockquote prepended to the issue description (`> **Blocked by:** [CLA-XX](url) — reason.`)
    - H) Use a custom Linear label per relation (e.g. `blocked-by:CLA-12`)
- **Decision**: A + C + G.
  - **A (one-way)** — Bidirectional sync is a different skill with different invariants (state reconciliation, conflict resolution, ordering). Bundling it would balloon the contract. A future `/linear-to-tasks` skill can close the loop without renegotiating this one.
  - **C (title match)** — D is correct in theory but requires writing into TaskList metadata, which the agent's task tool does not expose for arbitrary keys today. E is more robust against renames but unfriendly to debug ("why was this skipped?"). C is the simplest contract a human can verify by reading the report. Renames are documented as a known v1 limitation.
  - **G (blockquote)** — F drops information the user explicitly cares about. H clutters the label vocabulary and gives no visual cue in the issue itself. G shows the dependency at the top of every blocked issue, makes the edge visible everywhere in the Linear UI, and is automatically replaced once an MCP gains the relation field (the skill diff is local).
- **Sub-decisions**:
  - **State is applied via post-create bulk update.** Linear's `create` endpoint does not accept a state argument; the skill creates issues, then runs one `linear_bulk_update_issues` call to move them to the configured state (Todo by default per ADR-relevant memory entry).
  - **No per-task AI labelling in v1.** A single `default_labels` set applies to every issue in a run. Per-task labelling injects model judgment under the dedupe contract, makes runs non-deterministic, and obscures the report. Revisit if users request it.
  - **Memory entries override `.claude/linear.config.yaml`.** `feedback_linear_workspace.md` (workspace scope), `feedback_linear_issue_state.md` (Todo default), and `reference_linear_mcp_limitations.md` (relation workaround) are read at runtime and treated as overrides. The skill reports the conflict when config and memory disagree.
- **Consequences**:
  - 1 new skill: `.claude/skills/tasks-to-linear/SKILL.md`
  - 2 templates: `linear.config.example.yaml`, `report.md.tmpl`
  - `CODEBASE_MAP.md` lists the new skill
  - When MCPs gain `blockedBy` on `create_issue`, Phase 3 in the SKILL.md swaps the blockquote write for a relation set. Existing issues with blockquotes are left as-is — no migration script.
  - **NOTE on numbering**: ADR-005..012 are reserved by PRs #117..#126. If merge order shifts, renumber to next free slot.

### ADR-014: `/constitution` is interactive-first, additive-only, library-backed (no rule invention)
- **Date**: 2026-05-18
- **Status**: accepted
- **Context**: CLA-17 asked for a "constitution" skill that produces a project-tailored `golden-principles.yaml` — the "Golden Principles" pattern from OpenAI's harness-engineering article applied to the kit's audit pipeline. `/quality-audit` (CLA-13, ADR-011) reads the file; this new skill writes it. Three contract questions had to be settled, because they determine whether the audit pipeline downstream is trustworthy:

  1. **Authoring stance.** Interactive (dialogue per principle) or non-interactive (codebase-only inference)?
  2. **Re-run behaviour.** What happens when the file already exists?
  3. **Where do proposed `detect` rules come from?** Synthesised from codebase patterns, or drawn from a curated library?

- **Options**:
  - **Authoring stance**
    - A) Interactive-first (default), headless as an explicit `mode:headless` escape hatch
    - B) Non-interactive by default (infer everything), interactive only on flag
  - **Re-run behaviour**
    - C) Additive merge — propose only new categories, never edit existing entries
    - D) Replace — regenerate the file on each run, dropping hand-edited principles
    - E) Interactive replace — show diff, ask which entries to keep
  - **`detect` rule source**
    - F) Curated `principles-library.yaml` per language, lightly adapted to the detected stack
    - G) Synthesised from codebase scan — "I see this pattern, here's a `detect` rule for it"
    - H) Hybrid — library for known categories, synthesis for novel ones
- **Decision**: A + C + F.
  - **A (interactive-first)** — Following the principle from `office-hours` and the Core Rule pattern in CLA-13/14/16: the agent must never write a rule the user hasn't seen. Quality rules drive audit-class skills downstream; silent invention propagates errors at scale. Headless mode exists for CI bootstrapping but accepts everything the library proposes — no judgment is delegated.
  - **C (additive merge)** — D would let the skill clobber hand-tuned principles, which is the worst possible failure mode for a file users will iterate on. E sounds good but creates a coupling problem: the user has to re-evaluate every existing entry on every run, turning a 30-second additive operation into a 10-minute review. C aligns with the "do one thing" principle — this skill *adds*; refining is a hand-edit job.
  - **F (curated library)** — G is tempting but identical in shape to the failure mode ADR-012 (the `/references-sync` curated-vs-heuristic-vs-summarisation decision) rejected for the same reason: synthesised `detect` patterns are brittle and fire on the wrong lines. H sounds balanced but introduces the synthesis failure mode through the back door. F gives the skill a stable, kit-maintained surface to draw from; users extend with `.claude/principles-library.local.yaml` (per-project) or upstream PRs to grow the shared library.
- **Sub-decisions**:
  - **Schema source of truth is `.claude/skills/quality-audit/templates/golden-principles.example.yaml`.** If the schema changes there, `/constitution`'s output must follow. The skill's docstring explicitly references that path; a future CI lint can reject schema drift between the two skills.
  - **Default file path is `.claude/golden-principles.yaml`**, not the repo root. `/quality-audit` resolves both, but `.claude/` is the kit-managed surface and avoids cluttering the project root. Users who prefer root can pass `path:./golden-principles.yaml`.
  - **5-question intake** (in `templates/intake-questions.md`) shapes *severity emphasis* in Phase 3, not the principle set itself. Selected principles still come from the library; the intake just tunes which ones surface and how harshly.
  - **CLAUDE.md pointer addition is opt-in.** On a brand-new file, the skill proposes adding a `## Quality Principles` section to CLAUDE.md — only with explicit user approval, never in headless mode. Following the same kit-managed-file discipline as `/harness-init`.
- **Consequences**:
  - 1 new skill: `.claude/skills/constitution/SKILL.md`
  - 2 templates: `templates/principles-library.yaml` (3 languages × 4–6 categories), `templates/intake-questions.md` (5 questions + severity-mapping)
  - `CODEBASE_MAP.md` lists the new skill
  - **Skill family is now closed**: `/harness-init` (CLA-12 — scaffold `docs/`) → `/constitution` (CLA-17 — write `golden-principles.yaml`) → `/quality-audit` (CLA-13 — measure drift) → `/doc-gardening` (CLA-13 — flag stale docs) → `/references-sync` (CLA-14 — populate `docs/references/`) → `/tasks-to-linear` (CLA-16 — mirror plans to tracker). Each link in the chain has one job; future improvements stay localised.
  - **NOTE on numbering**: ADR-005..013 are reserved by PRs #117..#127. If merge order shifts, renumber to next free slot.

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
