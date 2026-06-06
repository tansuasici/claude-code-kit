---
name: lesson-resurface
description: Surface archived or superseded lessons whose topic tags match the current task — returns pointers (paths only), never bodies. Use when a task touches an area past sessions may have covered, to recover dormant context without bloating boot.
user-invocable: true
---

# Lesson Resurface

## Core Rule

Given a short task summary, return a ranked list of _pointers_ to lessons under `tasks/lessons/` (including `_archive/`) whose `applies_to` topic tags overlap with the task. Return paths only — never load, read, or paraphrase lesson bodies into context. The agent decides whether to `Read` each pointer.

## Process

The deterministic loop (vocabulary discovery, scoring, supersession resolution, output formatting) lives in `scripts/lesson-resurface.sh`. The skill is a thin pass-through:

```bash
scripts/lesson-resurface.sh "<task summary>"
```

Or, if invoking without a CLI argument, set the env var:

```bash
LESSON_QUERY="<task summary>" scripts/lesson-resurface.sh
```

Read the helper's stdout. It already emits the exact output format described under `## Output Format` below. **Do not** invent a different format — the helper is the source of truth.

## Kit Context

Before running this skill, ensure session boot is done:

1. Read `CODEBASE_MAP.md`
2. Read `CLAUDE.project.md` if it exists
3. Read `tasks/lessons/_index.md` Top Rules section (already injected by `session-start.sh`)

This skill is the **dormant-layer complement** to Top Rules:

- Top Rules = active layer, auto-injected at session start
- Recently Added / By Topic = active discoverable layer in `_index.md`
- `/lesson-resurface` = surfaces lessons outside those layers — archived or superseded — when the current task touches a topic they covered

## When to Use

Invoke with `/lesson-resurface "<task summary>"` when:

- Starting a new task on an area you suspect a prior session has touched
- A `tasks/handoff-*.md` resumption mentions a topic that may have an archived lesson (auth, migrations, deps, a specific module name)
- The active Top Rules feel insufficient and you want broader history before committing to an approach
- After Goal-Driven Reframing (in `agent_docs/workflow.md`), the restated goal mentions a topic vocabulary that overlaps with `applies_to` tags

Not for:

- Loading every lesson — boot already surfaces Top Rules; bulk loading defeats the purpose
- Reading lesson bodies in this skill — output is pointer-only
- Replacing `/lesson-refresh` — that skill handles lifecycle (keep/update/archive); this skill handles recall
- Cross-project search — operates within one repo's `tasks/lessons/` tree

## What the helper does (for reference)

1. **Discovers** the canonical `applies_to` vocabulary by scanning frontmatter across `tasks/lessons/*.md` + `tasks/lessons/_archive/*.md`.
2. **Substring-matches** the task summary (lowercased) against the vocabulary. If zero topics match, exits with "No matching topics" and stops.
3. **Scores** each lesson:
   - `+3` per topic in `applies_to` that matches an extracted task topic
   - `+1` per free-form `tags` entry that matches
   - `−2` if `status: archived`
   - `−1` if `status: superseded`
   - `+1` if `confidence: high`
   - Drops lessons with score ≤ 0
4. **Resolves supersession** — if a matched lesson is `status: superseded` and an active lesson supersedes it AND that active lesson is already in the match list, drops the older one. The agent never reads deprecated rules unintentionally.
5. **Emits** the top-5 pointers in the format below.

Frontmatter parsing reads only the YAML block between the first pair of `---` markers — body content is never loaded.

## Output Format

The helper emits this exact shape (do not reformat downstream):

```text
Matched lessons for topics [<comma-separated topics>]:

1. tasks/lessons/_archive/2025-12-01-deps-version-mismatch.md
   applies_to: [dependencies, plan-first]
   status: archived | confidence: high
   title: Conflicting peer-dep versions blocked the build

2. tasks/lessons/2026-03-04-auth-token-rotation.md
   applies_to: [auth, hooks]
   status: active | confidence: medium
   title: Rotating tokens without invalidating sessions

… 2 more matched (not shown).

These are pointers, not content. Read any that look relevant before proceeding; the bodies were intentionally NOT loaded.
```

If nothing matches above threshold:

```text
No archived/superseded lessons match topics [<topics>]. Proceed with the Top Rules already in context.
```

If the query itself doesn't intersect the vocabulary:

```text
No matching topics found in applies_to vocabulary; no lessons to resurface.
```

## Rules

Always:

- Run `scripts/lesson-resurface.sh` for the deterministic loop — never re-implement scoring in the agent's reasoning
- Pass the helper's output through verbatim (the format is the contract)
- Show `applies_to`, `status`, `confidence`, and `title` from frontmatter — these are tiny and useful for the agent's decision to Read
- Never include `## Issue`, `## Root Cause`, `## Rule`, or `## References` text — those are the body; surfacing them is the agent's decision

Never:

- Print full lesson bodies (the helper deliberately doesn't load them)
- Load lesson bodies into the conversation context
- Summarize what a lesson says (the title is the summary; for more, the agent reads the file)
- Modify any file (this skill is read-only)

## Smoke Test

Self-check before relying on results:

```bash
# 1. Confirm the helper returns the kit's example lesson on a known topic
./scripts/lesson-resurface.sh "scope-discipline"
# Expect: 1 result pointing at tasks/lessons/2026-04-15-example-tsconfig.md

# 2. Confirm a vocabulary miss is silent
./scripts/lesson-resurface.sh "unrelated nonsense words"
# Expect: "No matching topics found in applies_to vocabulary..."

# 3. Confirm env-var invocation works
LESSON_QUERY="tooling" ./scripts/lesson-resurface.sh
# Expect: same result as (1) — both topics in the lesson's applies_to
```

Regression coverage lives in `bench/scenarios/s17-lesson-resurface-smoke.json`.

## Pairs With

- **Goal-Driven Task Reframing** (`agent_docs/workflow.md`) — extract canonical topics from the restated goal before running this skill
- **`/lesson-refresh`** — lifecycle (archive/promote/encode/supersede); this skill is the recall counterpart
- **CLAUDE.md → Self-Improvement Loop** — the active Top Rules layer; this skill surfaces the dormant complement
- **`scripts/lesson-graph.sh`** — generates the `_index.md` auto-sections; this skill consumes the same `applies_to` typed-relation graph

## Out of Scope

- Vector / embedding search — topic-tag matching is intentionally simple and deterministic
- Auto-loading bodies on a confidence threshold — that's a different design (would defeat the "pointer-only" rule)
- Cross-repo search — kit operates within one project's `tasks/lessons/`
- Writing new lessons — that's the lesson template + user correction flow
