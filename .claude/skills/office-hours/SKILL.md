---
name: office-hours
description: Pre-coding product validation using forcing functions — clarify what to build and why before writing any code
user-invocable: true
---

# Office Hours

## When to Use

Invoke with `/office-hours` when:

- Starting a new feature and want to validate the approach before coding
- Unclear requirements — need to sharpen the problem statement
- Multiple possible solutions and need to pick one deliberately
- Want to prevent building the wrong thing fast
- Before creating a technical plan or writing a contract

## Process

### Phase 1: Problem Statement

Force a clear articulation of the problem:

1. **What problem are we solving?** — One sentence, no jargon
2. **Who has this problem?** — Specific user type, not "users"
3. **How do they solve it today?** — Current workaround or pain point
4. **How will we know it's solved?** — Observable outcome, not a feature list
5. **What happens if we don't solve it?** — Impact of inaction

Ask the user each question individually. Do not proceed until all 5 are answered clearly. If an answer is vague, push back with a specific follow-up.

### Phase 2: Solution Validation

Challenge the proposed solution:

1. **Is this the simplest solution?** — What's the minimum that solves the problem?
2. **What are we NOT building?** — Explicit scope exclusions
3. **What assumptions are we making?** — List them, then question each one
4. **What's the riskiest assumption?** — The one that, if wrong, makes everything else moot
5. **How can we test the riskiest assumption first?** — Smallest possible experiment

### Phase 3: User Story / Spec

Generate a lightweight spec from the validated answers:

```markdown
## Feature: [Name]

### Problem
[1 sentence from Phase 1]

### User
[Specific user type]

### Success Criteria
- [ ] [Observable outcome 1]
- [ ] [Observable outcome 2]

### Scope
**In scope:**
- [Feature aspect 1]
- [Feature aspect 2]

**Out of scope:**
- [Excluded aspect 1]
- [Excluded aspect 2]

### Assumptions
1. [Assumption] — Risk: Low/Medium/High
2. [Assumption] — Risk: Low/Medium/High

### Open Questions
- [Anything still unclear]
```

### Phase 4: Decision

Present the spec to the user and ask:

- "Does this accurately describe what we're building?"
- "Are there any missing success criteria?"
- "Should we proceed to planning, or refine further?"

Only after explicit user approval, suggest next steps:
- `/architecture-review` for complex features
- Use the planner agent for implementation planning
- Jump straight to implementation if the scope is small and clear

## Output Format

```markdown
# Office Hours — [Feature Name]

## Problem Statement
**What**: [problem]
**Who**: [user type]
**Current state**: [how they solve it today]
**Success metric**: [how we know it's solved]
**Cost of inaction**: [what happens if we don't]

## Solution
**Approach**: [chosen solution]
**Simplest version**: [MVP description]
**Explicitly excluded**: [what we're NOT building]

## Assumptions & Risks
| # | Assumption | Risk | Validation |
|---|-----------|------|------------|
| 1 | Users want X | Medium | Can test with Y |

## Spec
[Generated spec from Phase 3]

## Recommendation
[Proceed to planning / Needs refinement / Spike first]
```

## Notes

- This is a thinking tool, not a documentation tool — the goal is clarity, not paperwork
- Push back on vague answers — "improve the user experience" is not a problem statement
- The one-question-at-a-time pattern is deliberate — it forces focused thinking
- If the user already has a clear spec, this skill may be unnecessary — say so
- Output feeds directly into the planner agent or `/architecture-review`
