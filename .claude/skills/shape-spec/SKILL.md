---
name: shape-spec
description: Creates a timestamped feature spec folder with structured plan, decisions, and references for multi-session features
user-invocable: true
---

# Shape Spec

## When to Use

Invoke with `/shape-spec` when:

- Planning a feature that will span multiple sessions
- Decisions and context should be preserved beyond the current session
- The feature requires significant research or tradeoff analysis
- You want structured handoff context for another session or developer

## Process

### Phase 1: Name and Scope

1. Ask: "What feature are we speccing?" — get a short name
2. Create the spec folder: `tasks/specs/<date>-<name>/`
3. Confirm scope boundaries — what's in, what's out

### Phase 2: Shape the Plan

Gather structured information through conversation:

1. **Goal** — What does "done" look like?
2. **Context** — Why is this needed now? What triggered it?
3. **Approach** — What's the implementation strategy?
4. **Files to touch** — Which files need changes?
5. **Open questions** — What needs clarification?
6. **Risks** — What could go wrong?

Write findings to `plan.md` in the spec folder.

### Phase 3: Capture Decisions

For each decision made during planning:

1. What was decided?
2. What alternatives were considered?
3. Why was this option chosen?

Write to `shape.md` in the spec folder.

### Phase 4: Gather References

Collect pointers to relevant context:

- Similar code in the codebase
- Related documentation
- Relevant skills that apply
- External references (docs, issues, examples)

Write to `references.md` in the spec folder.

## Output Format

```text
tasks/specs/<date>-<feature-name>/
  plan.md          # Implementation plan
  shape.md         # Decisions and context
  references.md    # Pointers to relevant code, docs, skills
```

### plan.md template

```markdown
# Feature: <name>

## Goal
<what does "done" look like>

## Context
<why this is needed>

## Approach
1. ...
2. ...

## Files to Touch
- `path/to/file` — what changes

## Open Questions
- ...

## Risks
- ...
```

### shape.md template

```markdown
# Decisions: <feature name>

## Decision 1: <title>
**Chosen**: <what was decided>
**Alternatives**: <what else was considered>
**Rationale**: <why this option>

## Decision 2: <title>
...
```

### references.md template

```markdown
# References: <feature name>

## Codebase
- `path/to/similar/code` — <why it's relevant>

## Skills
- `/skill-name` — <what it checks>

## External
- <link or reference> — <what it covers>
```

## Notes

- Spec folders are optional — simple tasks should use `tasks/todo.md` directly
- Keep spec folders lightweight — they're planning artifacts, not documentation
- Spec folders survive sessions — new sessions read them for context
- Reference active spec folders from `tasks/todo.md` instead of duplicating the plan
