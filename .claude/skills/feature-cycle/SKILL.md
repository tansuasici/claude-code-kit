---
name: feature-cycle
description: End-to-end orchestrator chaining spec → plan → implement → verify → review → ship from a local spec — the whole CLAUDE.md lifecycle as one command. Use to drive a complete feature from a ready spec. To validate what to build first use /office-hours.
user-invocable: true
---

# Feature Cycle

## Core Rule

Chain the kit's existing phases — never reimplement them. `/feature-cycle` is an orchestrator: it invokes `shape-spec`, the `planner` agent, the quality gate, `review-pipeline`, and `ship` in order, carrying context between them through `.hook-state/agent-handoff.md`. If a phase fails its gate, **halt** and surface the failure — never silently skip a phase.

## Kit Context

Before starting this skill, ensure you have completed session boot:

1. Read `CODEBASE_MAP.md` for project understanding
2. Read `CLAUDE.project.md` if it exists for project-specific rules
3. Read `tasks/lessons/_index.md` for accumulated corrections (Top Rules + index)

If any of these haven't been read in this session, read them now before proceeding.

## When to Use

Invoke with `/feature-cycle <spec-ref>` when:

- You have a shaped spec (a `tasks/specs/<slug>/` folder, a `tasks/todo.md` entry, or a one-line description) and want the full Plan → Implement → Verify → Review → Ship lifecycle run as one command
- You want the orchestration to live in the command, not in your head — each phase hands off to the next with shared context

Not for:

- Exploratory or ambiguous work that needs clarification first — run `/office-hours` to shape it, then feed the result here
- A one-line fix you can do directly — the chain's overhead isn't worth it
- Multi-issue / epic-level orchestration — run the cycle once per feature

## Inputs

`/feature-cycle <arg>`, where `<arg>` resolves in order:

1. A path to a `tasks/specs/<slug>/` folder (from `shape-spec`) → use it as the spec
2. A `tasks/todo.md` task title or anchor → use that task's plan
3. Free text → treat as the feature description; the cycle scaffolds a spec via `shape-spec`

No tracker is required or assumed. Pulling the spec from an external issue tracker (Linear / GitHub Issues / Jira) is an optional `.claude/extensions/` adapter, deliberately out of core.

## Process

Each phase reads `.hook-state/agent-handoff.md` on entry and overwrites it with a ≤5-line summary on exit, so the next phase starts with the previous phase's context (see `agent_docs/subagents.md → Runtime Handoff`). Sub-agent invocations are logged to telemetry automatically (`agent-invocations.jsonl`).

### Phase 1: Resolve input

Resolve `<arg>` to a spec (see Inputs). If it is free text and no spec exists, scaffold one with `shape-spec`. Restate the goal in 1–2 sentences and confirm it is concrete enough to plan; if not, stop and point the user at `/office-hours`.

### Phase 2: Plan

Spawn the `planner` sub-agent with the spec. The plan lands in `tasks/todo.md` (per the planner's contract). Do not implement yet.

### Phase 3: Implement

Execute the plan. Touch only the files the plan names; match existing style. If the plan turns out wrong mid-flight, halt and re-plan (per CLAUDE.md "if something goes sideways").

### Phase 4: Verify

Run the verification gate — typecheck, lint, tests. `quality-gate.sh` fires after every edit; run the full suite here too. **Halt on failure; no silent skip.** Quantify silent failures (processed / failed / skipped with reasons).

### Phase 5: Review

Run `/review-pipeline` over the diff. Address Cross-Audit and Critical findings before shipping.

### Phase 6: Ship

Run `/ship` (tests, CHANGELOG, branch, PR). Stop at the PR — a human approves the merge.

### Halting

If any phase fails its gate, stop the cycle, write the failure + resume point to `.hook-state/agent-handoff.md`, and surface it. The handoff file is enough to continue from the last completed phase in a later session.

## Output Format

Emit one progress line per phase and a final summary:

```text
/feature-cycle <spec>
  ✓ Phase 1 Resolve   — spec: tasks/specs/2026-…/
  ✓ Phase 2 Plan      — 4 steps in tasks/todo.md (planner)
  ✓ Phase 3 Implement — 3 files touched
  ✓ Phase 4 Verify    — typecheck / lint / tests green
  ✓ Phase 5 Review    — review-pipeline: 0 critical, 1 major (addressed)
  ✓ Phase 6 Ship      — PR #NN opened
```

On halt, mark the failed phase `✗`, print the reason, and note that `.hook-state/agent-handoff.md` holds the resume point.

## Run Mode

This skill supports interactive (default) and headless modes — see the canonical contract in `.claude/skills/_shared/blocks/mode-detection.md`.

Headless detection: presence of `mode:headless` in arguments.

| Decision point | Interactive | Headless |
|---|---|---|
| **Ambiguous spec** | Ask, or route to `/office-hours` | Fail fast: "spec not concrete enough to plan" |
| **Phase gate failure** | Surface + ask how to proceed | Halt, write handoff, exit non-zero |
| **Ship** | Open PR; human merges | Open PR; never auto-merge |

## Notes

- **Orchestrates; does not reimplement.** Quality depends on the underlying skills/agents (`shape-spec`, `planner`, `review-pipeline`, `ship`). Fix them there, not here.
- **Resumable.** The handoff file carries context between phases; if interrupted, a later session continues from the last completed phase.
- **Tracker-agnostic.** Core takes a local spec. Pulling from / updating an external tracker is an optional `.claude/extensions/` adapter, deliberately out of core — the kit ships no tracker dependency.
- Built on the agent-handoff (CLA-37) and agent-telemetry (CLA-38) layers.
