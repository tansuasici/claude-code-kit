---
name: tasks-to-linear
description: Sync the agent's TaskList into Linear issues — one issue per task, idempotent by title, defaults to Todo. Use when you've planned with TaskCreate and want each task tracked in Linear.
user-invocable: true
---

# Tasks → Linear

## Core Rule

One Linear issue per task — match by title within the configured team, never create duplicates. Existing issues are reported as "skipped", never silently overwritten.

## Kit Context

Before starting this skill, ensure you have completed session boot:

1. Read `CODEBASE_MAP.md` for project understanding
2. Read `CLAUDE.project.md` if it exists for project-specific rules
3. Read `tasks/lessons/_index.md` for accumulated corrections (Top Rules + index)

If any of these haven't been read in this session, read them now before proceeding.

## When to Use

Invoke with `/tasks-to-linear` when:

- You've used `TaskCreate` to plan multi-step work and want each task tracked in Linear for the team
- A planning skill (e.g. `/shape-spec`, `/office-hours`, `/planner` subagent) produced a task list you want to externalise
- Onboarding work that already lives in the TaskList into a project tracker
- As the final step of `/loop` or `/schedule` runs that produce actionable findings (e.g. `/quality-audit` drift → Linear backlog)

Not for:

- Single ad-hoc tasks — open them directly in Linear UI, the round trip isn't worth a skill
- Tasks under 60 seconds of work — keep them in TaskList only
- Two-way sync — this skill is **one-way**: TaskList → Linear, never the reverse

## Default Behavior

When the user asks to "push tasks to linear", "sync the plan", "open issues for this", or invokes `/tasks-to-linear`, produce the full sync workflow automatically using the Process and Output Format sections below. Do not ask the user to specify which tasks — the skill reads the active TaskList itself.

This skill **writes external state** by design — it creates Linear issues. Idempotency (title-based dedupe) is the safety net, not user confirmation per task.

## Inputs

### TaskList (always)

The skill reads the **current** TaskList. Tasks with status `completed` or `deleted` are skipped — only `pending` and `in_progress` make it to Linear. Use the agent's TaskList tooling to read the full list including `blocks`, `blockedBy`, descriptions, and metadata.

### `.claude/linear.config.yaml` (optional)

If present at the repo root, this file pre-commits the routing decisions. Example:

```yaml
# .claude/linear.config.yaml — defaults for /tasks-to-linear
version: 1

# Which team to write to. Resolved by key (e.g. "CLA") or name.
team: CLA

# Optional project / milestone for newly created issues.
project: null
milestone: null

# Default state for new issues. Must be a state name in the target team.
default_state: Todo

# Label(s) applied to every new issue. Names are case-sensitive.
default_labels:
  - Feature

# Map TaskList metadata.label → Linear label name. Optional override per task.
label_map:
  bug: Bug
  feature: Feature
  improvement: Improvement

# Title prefix for issues created by this skill (helps the dedupe scan).
# Leave empty to match raw task subjects.
title_prefix: ""

# Dedupe scope:
#   team       — search the whole team for matching titles (default)
#   project    — restrict the search to `project` above
#   none       — never dedupe; always create. NOT recommended.
dedupe: team
```

If the file is missing, the skill falls back to interactive prompts in interactive mode and to documented defaults in headless mode (see Run Mode).

### Memory hints

The skill honours these memory entries when present:

- `feedback_linear_workspace.md` → forces the team scope. If config disagrees, the memory wins and the skill reports the conflict.
- `feedback_linear_issue_state.md` → forces `default_state` (typically `Todo`).
- `reference_linear_mcp_limitations.md` → reminds the skill to express `blockedBy` as an inline blockquote rather than via a relation field (no MCP exposes the relation today).

## Required Tools

Before any write, confirm these MCP tools are available:

- `linear_search_issues` (idempotency check)
- `linear_create_issue` (write path)
- `linear_get_teams` (team / state / label resolution)
- `linear_edit_issue` or `linear_bulk_update_issues` (post-create state change to Todo)

If the Linear MCP is not connected, exit with this message:

> Linear MCP unavailable. Connect a Linear MCP server (see `.mcp.json`) and rerun. No issues were created.

## Process

### Phase 1: Inventory (first-pass leads)

This pass produces **candidates**, not findings. Treat the TaskList as the source of truth and validate routing before writing anything.

1. Read the active TaskList. Filter to tasks with status `pending` or `in_progress`. Preserve `blocks` / `blockedBy` edges between tasks.
2. Resolve the target team:
   - If config exists → use `team` from config
   - Else if `feedback_linear_workspace.md` memory exists → use that workspace
   - Else (interactive) → list available teams via `linear_get_teams` and ask the user to pick
   - Else (headless) → exit non-zero with "no team configured"
3. Resolve the target state UUID:
   - Default: state named `Todo` in the target team
   - Verify it exists via `linear_get_teams`; if not, error out with the available state names
4. Resolve the label UUIDs for `default_labels` against the team's labels. Skip unknown labels with a warning row in the report.
5. Build the candidate set — one entry per filtered task, with `title`, `description`, `priority`, `labels`, `blockedBy` (resolved to other task subjects).

### Phase 2: Dedupe

For each candidate:

1. Run `linear_search_issues` with `teamIds: [<team>]` and a `query` set to the task's title.
2. From the results, look for an **exact title match** (case-sensitive). If found, mark the candidate as `skipped` and capture the existing issue's identifier + URL.
3. De-duplicate within the candidate set itself (same title appearing twice in the TaskList → keep the first, mark the rest as `skipped_intra_batch`).

After Phase 2 the candidate set is split into:

- `to_create` — title not present in Linear
- `skipped` — duplicates in Linear or within the batch

### Phase 3: Create

For each `to_create` candidate, in TaskList order (so blockers are created before the issues they block):

1. Build the description from the task description, plus a `**Blocked by:**` blockquote at the top if the task has `blockedBy` edges that point at other tasks already created in this run. Use the format from [[reference-linear-mcp-limitations]]:
   ```markdown
   > **Blocked by:** [CLA-XX](url) — short reason from the dependency edge.

   ---

   (the original task description goes here verbatim)
   ```
   For tasks blocked by tasks not in this batch (e.g. already-completed or deleted), omit the blockquote.
2. Call `linear_create_issue` with:
   - `title`: optional `title_prefix` + task subject
   - `description`: built above
   - `teamId`: resolved team UUID
   - `labelIds`: resolved label UUIDs (skip silently if none)
   - `priority`: from task metadata if present, else `0` (no priority)
3. Capture the returned issue ID + identifier + URL.
4. After all issues are created, run `linear_bulk_update_issues` once with the resolved Todo `stateId` and the list of issue UUIDs created in this run. (Linear's create endpoint doesn't accept a state arg; this batch update is the documented Todo-default workaround per [[feedback-linear-issue-state]].)

If any single `create` call fails, log the failure and continue with the next candidate. Do not abort the whole batch.

### Phase 4: Report

Emit the Output Format report (see below). Then, for each created issue, leave the corresponding TaskList task **unchanged** — this skill does not mark tasks as in_progress or completed. The TaskList remains the working surface; Linear is the durable mirror.

## Output Format

```markdown
# Tasks → Linear sync report

_Run: 2026-05-18T22:30:00Z — tasks-to-linear v1_

## Summary

| Metric | Value |
|--------|-------|
| Tasks scanned | 8 |
| Tasks eligible (pending / in_progress) | 6 |
| Issues created | 4 |
| Skipped (already in Linear) | 1 |
| Skipped (intra-batch dupe) | 1 |
| Failed | 0 |
| Target team | ClaudeCodeKit (CLA) |
| Default state | Todo |
| Default labels | Feature |

## Created

| Task # | Linear | Title |
|--------|--------|-------|
| 4 | [CLA-18](https://linear.app/claudecodekit/issue/CLA-18/...) | Wire the audit hook to PostToolUse |
| 5 | [CLA-19](https://linear.app/claudecodekit/issue/CLA-19/...) | Add ADR-014 for the audit cadence |
| 6 | [CLA-20](https://linear.app/claudecodekit/issue/CLA-20/...) | Backfill manifest entries for `.kit-state/` |
| 7 | [CLA-21](https://linear.app/claudecodekit/issue/CLA-21/...) | Update `CODEBASE_MAP.md` |

## Skipped

| Task # | Reason | Existing |
|--------|--------|----------|
| 2 | duplicate title in Linear | [CLA-12](https://linear.app/claudecodekit/issue/CLA-12) |
| 3 | duplicate title in this batch | (same subject as task 2) |

## Failed

_None._

## Notes

- 1 task carried a `blockedBy` edge to another task in this batch — expressed as an inline blockquote at the top of CLA-19's description.
- Default state applied via post-create bulk update (Linear's create endpoint does not accept a state argument).
```

## Run Mode

| Decision point | Interactive default | Headless default (`mode:headless`) |
|---|---|---|
| Missing `.claude/linear.config.yaml` | Walk the user through team / project / labels and offer to save the file | Exit non-zero with "no config and headless mode — set up `.claude/linear.config.yaml`" |
| Multiple teams returned and no memory hint | Ask the user to choose | Exit non-zero |
| Unknown label name | Warn, skip the label, continue | Warn in the report, skip the label, continue |
| Linear MCP not connected | Print the connection hint, exit 0 (no destructive side effects) | Print the connection hint, exit 1 |
| Task subject is empty / placeholder (`"TODO"`, `"."`) | Skip with a warning in the report | Skip with a warning |
| Dedupe finds a matching title with different description | Report as `skipped`; do not update the existing issue | Same — never update existing issues from this skill |

See `.claude/skills/_shared/blocks/mode-detection.md`.

## Loop / Schedule Integration

Useful pairings:

```text
/quality-audit mode:headless          # produces drift candidates in tasks/todo.md → Drift Alerts
/tasks-to-linear mode:headless        # syncs those candidates to Linear once the human triages

/shape-spec <feature>                  # produces a structured task list
/tasks-to-linear                       # immediately mirror the plan to the project tracker
```

For a recurring "drift → tracker" pipeline:

```text
/loop weekly /quality-audit mode:headless
# Triage tasks/todo.md → Drift Alerts manually, then:
/tasks-to-linear mode:headless
```

The skill does **not** auto-run after `/quality-audit` — drift findings need a human triage step before they become tracker entries.

## Templates

- `templates/linear.config.example.yaml` — copy to `.claude/linear.config.yaml` and tailor.
- `templates/report.md.tmpl` — the snapshot format used to write a copy of each run report to `tasks/reports/tasks-to-linear-<timestamp>.md` (optional; only written when the user passes `--save-report`).

## Notes

- **One-way by design.** This skill writes TaskList → Linear and never the reverse. A future `/linear-to-tasks` skill would close that loop; today, the agent or the human pulls Linear state by hand.
- **Title-based dedupe is fragile.** A task renamed between two runs will be created twice. Rename either the task or the existing Linear issue before re-running, or accept the duplicate and close it in the Linear UI. A future iteration may track a `linear_id` field in TaskList metadata to make this robust.
- **`blockedBy` is encoded as a blockquote, not a relation.** Neither Linear MCP currently exposes the relation field for ClaudeCodeKit's workspace — see [[reference-linear-mcp-limitations]] for the up-to-date workaround. When the MCP gains the field, swap the blockquote write for a `relatedTo`/`blockedBy` set during Phase 3.
- **Defaults respect memory.** The skill reads `feedback_linear_workspace.md`, `feedback_linear_issue_state.md`, and `reference_linear_mcp_limitations.md` when present and treats them as overrides on `.claude/linear.config.yaml`.
- **No auto-labelling.** v1 applies `default_labels` uniformly. Per-task AI labelling is intentionally deferred — it injects judgment under the dedupe contract and makes the run non-deterministic.
- **Pairs with `/shape-spec`.** That skill scaffolds a feature spec folder including a task list; this skill pushes the list to the tracker. Use them back-to-back when starting a multi-session feature.
