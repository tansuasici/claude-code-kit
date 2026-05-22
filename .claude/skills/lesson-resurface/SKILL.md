---
name: lesson-resurface
description: Surface archived or superseded lessons whose canonical topic tags match the current task — returns pointers (paths only), never lesson bodies. Used to recover dormant context without bloating Tier 1 boot or polluting Top Rules.
user-invocable: true
---

# Lesson Resurface

## Core Rule

Given a short task summary, return a ranked list of _pointers_ to lessons under `tasks/lessons/` (including `_archive/`) whose `applies_to` topic tags overlap with the task. Return paths only — never load, read, or paraphrase lesson bodies into context. The agent decides whether to `Read` each pointer.

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

## Process

### Phase 1: Extract topics from the task summary

1. Read the user argument. If no argument, read the active task header in `tasks/todo.md` → `## In Progress` → first `###`.
2. Reduce the summary to 1–4 canonical topic tags. The vocabulary is whatever `applies_to` values appear across `tasks/lessons/*.md`. Run this once to discover the current vocabulary:

   ```bash
   grep -h '^applies_to:' tasks/lessons/*.md tasks/lessons/_archive/*.md 2>/dev/null \
     | sed 's/applies_to: *\[//; s/\].*//; s/,/\n/g' \
     | tr -d ' '"'"'' | sort -u | grep -v '^$'
   ```

3. Match the task summary against that vocabulary using substring + word-stem matches. Common topics: `scope-discipline`, `plan-first`, `verification`, `tooling`, `protected-changes`, `dependencies`, `auth`, `migrations`, `testing`, `hooks`, `subagents`, `deploy`, `context-hygiene`, `model-vs-code`.
4. If the task summary maps to zero canonical topics, return "No matching topics found in `applies_to` vocabulary; no lessons to resurface." and stop.

### Phase 2: Score lessons

1. List `tasks/lessons/*.md` and `tasks/lessons/_archive/*.md` (if the archive exists). Skip `_TEMPLATE.md` and `_index.md`.
2. For each file, read **only the frontmatter** — do not load the body.
3. Score:
   - `+3` per topic in `applies_to` that matches an extracted task topic
   - `+1` per free-form `tags` entry that matches a task topic
   - `−2` if `status: archived`
   - `−1` if `status: superseded`
   - `+1` if `confidence: high`
4. Drop lessons with score ≤ 0.

### Phase 3: Resolve supersession chains

For each matched lesson with `status: superseded`:

1. Find the active lesson whose `supersedes:` list contains this slug.
2. If the successor is already in the match list, drop the older one.
3. If the successor is not in the match list, replace the older one with the successor (so the user sees the _current_ rule, not the deprecated one).

This step ensures the agent never wastes time reading a deprecated lesson when a newer one already exists.

### Phase 4: Emit pointers

Return a compact, pointer-only listing. Max 5 entries; if more match, mention the count and stop at 5.

```text
Matched lessons for topics [<extracted topics>]:

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

## Output Format

Always:

- Show paths (max 5)
- Show `applies_to`, `status`, `confidence`, and `title` from frontmatter — these are tiny and useful for the agent's decision to Read
- Never include `## Issue`, `## Root Cause`, `## Rule`, or `## References` text — those are the body; surfacing them is the agent's decision

Never:

- Print the full lesson body
- Load lesson bodies into the conversation context
- Summarize what a lesson says (the title is the summary; for more, the agent reads the file)
- Modify any file (this skill is read-only)

## Smoke Test

Self-check before relying on results:

1. Pick a known-archived lesson (`status: archived` in its frontmatter)
2. Construct a task summary that includes one of its `applies_to` topics
3. Run `/lesson-resurface "<that summary>"`
4. Confirm the archived lesson appears in the pointer list
5. Confirm the body of the lesson is NOT in your context (search the conversation for distinctive phrases from the lesson body — should find none)

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
