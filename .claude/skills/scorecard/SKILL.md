---
name: scorecard
description: Aggregate recent session scorecards from reports/session-audit.log and produce a readable per-session + windowed-summary report. Distinct from `/retro` (process review) and `/pulse` (outcome timeline) — scorecard is pure numbers, fed by the SessionEnd hook.
user-invocable: true
---

# Scorecard

## Core Rule

Render facts that the SessionEnd hook already recorded. Never invent metrics — if a field is missing in the log, surface that, do not synthesize.

## Kit Context

Before starting this skill, ensure you have completed session boot:
1. Read `CODEBASE_MAP.md` for project understanding
2. Read `CLAUDE.project.md` if it exists for project-specific rules
3. Confirm `.claude/hooks/session-end.sh` is wired and the SessionEnd profile is active — otherwise the log will be empty

If these haven't been read in this session, read them now before proceeding.

## When to Use

Invoke with `/scorecard` when:

- You want a quick view of the last N sessions (default: 7 days, override with `--window 7d` / `--window 30d` / `--window 14d`)
- You want to see which blocking hooks fire most often (signal that the prompt rules need tightening)
- You want to track quality-gate failure rate as a moving signal
- You want to compare sessions before vs. after a kit upgrade

Not for:
- Process review or sentiment retrospective — that is `/retro`
- Outcome timeline ("what shipped, what broke") — that is `/pulse`
- One-off code metrics — those belong in `project-health-report`

## Scope Rules

- Reads `reports/session-audit.log` only — no other source of truth
- Parses both v1 (`schema_version` missing or `1`) and v2 records
- Filters by window if provided; default to the last 7 days
- Never modifies files; output is a single markdown report

## Process

### Phase 1: Inventory

1. Read `reports/session-audit.log` (one JSONL record per session)
2. Parse each line as JSON; skip lines that fail to parse and surface the count
3. Filter by window: include records whose `timestamp` is within the requested span
4. Group by `schema_version`:
   - v1 records carry only `last_quality_gate` + identifiers
   - v2 records carry the full `metrics` object

### Phase 2: Aggregation

Compute these aggregates over the windowed set of v2 records (v1 records contribute only to "sessions counted" and "last_quality_gate distribution"):

| Aggregate | How |
|---|---|
| **Sessions counted** | N total in window |
| **Quality-gate pass rate** | `1 − sum(metrics.quality_gate.failures) / sum(metrics.quality_gate.runs)` (skip sessions with `runs == 0`) |
| **Skip-gate usage** | Count of sessions where `metrics.quality_gate.skip_gate_used` is true |
| **Blocks fired (per hook)** | Sum of `metrics.blocks_fired[hook]` across sessions, sorted desc |
| **Edits total** | Sum of `metrics.edits` |
| **Lessons added** | Sum of `metrics.lessons_added` |
| **Decisions added** | Sum of `metrics.decisions_added` |
| **Bash output (estimated tokens)** | Sum of `metrics.bash_token_estimate`; if all are zero, surface that the bash-budget hook may not be installed |
| **Compactions** | Sum of `metrics.compactions_observed` |
| **Median session duration** | Median of `metrics.session_duration_seconds` (skip null/zero) |

### Phase 3: Render

Output exactly one report. Keep it scannable. The shape is:

```markdown
# Scorecard — last <window>

**Sessions counted:** <N>  (<v2_count> with full metrics, <v1_count> legacy v1 records)

## Quality-gate

- Runs: <total>
- Failures: <total>  ( **pass rate <p>%** )
- Skip-gate used in <n> session(s)
- Most recent: <last_status> (<timestamp>)

## Blocks fired (cumulative)

| Hook | Count |
|---|---:|
| protect-files | 12 |
| protect-changes | 4 |
| stop-gate | 2 |
| branch-protect | 0 |
| block-dangerous-commands | 0 |

## Activity

- Edits: <total>
- Lessons added: <total>
- Decisions added: <total>
- Bash output (estimated tokens): <total>  *(0 if bash-budget hook not installed)*
- Compactions observed: <total>
- Median session duration: <minutes>

## Per-session detail (most recent first)

| Date | Pass? | Edits | Blocks | Duration |
|---|---|---:|---:|---:|
| 2026-05-18 | ✓ | 12 | 0 | 18m |
| 2026-05-17 | ✗ | 8 | 2 | 32m |
...
```

If the log is empty: print exactly `No SessionEnd records found at reports/session-audit.log. The SessionEnd hook may not be wired into .claude/settings.json, or no session has ended yet.`

If only v1 records exist: render a reduced report ("Quality-gate" and "Per-session detail" only — explain that the rest needs schema_version 2 from a kit that includes the scorecards hooks).

### Phase 4: Helpful follow-ups (optional, only when relevant)

After the table, add a single-paragraph "What this says" callout only when one of these is true:

- **Quality-gate pass rate < 70%** → suggest reviewing the failing tool's last failures (point at `.hook-state/last_quality_gate.json` and `stderr_tail`)
- **Skip-gate used in >1 session** → suggest documenting the bypass reasons in `tasks/decisions.md`
- **One hook accounts for >70% of blocks** → suggest tightening prompt guidance around that domain or relaxing the hook if it's noisy

Do not add follow-ups when nothing is notable. Silence is fine.

## Arguments

| Flag | Default | Effect |
|---|---|---|
| `--window <span>` | `7d` | Time window: `<N>d` for days, `<N>w` for weeks, `<N>m` for months, or `all` |
| `--json` | unset | Emit the aggregates as a single JSON object (no markdown). Useful for `/loop` or further piping. |
| `--per-session` | shown | Include the per-session detail table. Pass `--no-per-session` to hide it. |

## Run Mode

This skill supports interactive (default) and headless modes — see the canonical contract in `.claude/skills/_shared/blocks/mode-detection.md`.

Headless detection: presence of `mode:headless` in arguments.

| Decision point | Interactive | Headless |
|---|---|---|
| **Follow-up callouts** | Show when thresholds tripped | Skip — log to stdout the threshold flags only |
| **Per-session detail** | Show by default | Skip — keep output compact |
| **Output format** | Markdown table | Markdown table (same) or `--json` if requested |

## Notes

- The scorecard intentionally does NOT include the failure messages or stderr from `.hook-state/last_quality_gate.json`. Use `/debug` or read the state file directly when you need the body of a failure.
- `metrics.compactions_observed` is best-effort — the kit does not own the transcript format, so over-counts or under-counts of compaction events are possible. Treat as a trend signal, not an exact count.
- `metrics.lessons_added` / `metrics.decisions_added` are mtime-based, so editing an existing lesson during the session counts as "added". This is intentional: the goal is "did the lesson archive evolve this session?", not strict file creation.
- v1 records remain in the log untouched. Upgrading the kit doesn't rewrite history.
