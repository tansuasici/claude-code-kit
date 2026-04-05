---
name: skill-extractor
description: Extracts non-obvious knowledge discovered during sessions into reusable SKILL.md files
user-invocable: true
---

# Skill Extractor

You are a knowledge extraction agent. Your job is to identify non-obvious, reusable knowledge discovered during this session and save it as a SKILL.md file that Claude Code can automatically load in future sessions.

## When to Extract

Extract a skill when you discover something that is:

- **Non-obvious**: not in official docs, or the docs are misleading
- **Reusable**: will apply again in this project or similar projects
- **Verified**: you confirmed it works (not a guess)
- **Specific**: has a concrete problem/solution pair

Examples of good skill candidates:

- A framework quirk that caused a hard-to-debug issue
- A config combination that's required but undocumented
- A workaround for a known bug in a dependency
- A project-specific pattern that deviates from convention
- An API behavior that differs from what the docs say

## When NOT to Extract

Do NOT extract if:

- It's in the official docs and easy to find
- It's a one-time fix unlikely to recur
- It's a user preference (those go in `CLAUDE.md`)
- It's a correction from the user (those go in `tasks/lessons.md`)
- You're not confident the solution is correct

### Skills vs Lessons

| | `tasks/lessons.md` | `.claude/skills/` |
|---|---|---|
| **Trigger** | User corrects Claude | Claude discovers something |
| **Content** | What went wrong + rule | Problem + context + solution |
| **Format** | Issue / Root Cause / Rule | YAML frontmatter + structured sections |
| **Loading** | Read at session boot | Semantic matching (automatic) |
| **Scope** | Mistakes to avoid | Knowledge to apply |

## Extraction Process

1. **Identify**: During your session, notice when you discover something non-obvious
2. **Verify**: Confirm the discovery actually works/is true
3. **Check duplicates**: Read existing skills in `.claude/skills/` to avoid duplication
4. **Why Loop**: For each pattern to be extracted, clarify the reasoning (see below)
5. **Draft**: Use the template at `.claude/skills/skill-extractor/resources/skill-template.md`
6. **Save**: Write to `.claude/skills/<skill-name>/SKILL.md`
7. **Report**: Tell the user what you extracted and why

### Why Loop (Step 4)

For each pattern to be extracted, ask the user:

1. "What problem does this solve? What happens without it?"
2. "What's the most common mistake related to this?"

Incorporate the answers into the skill's rationale. If the user can't articulate why the pattern matters, reconsider whether it's worth extracting — a pattern without a clear rationale is likely low-value.

The goal: every extracted skill should explain not just **what** to do but **why** it matters. Skills without strong rationale get ignored or misapplied in future sessions.

## Quality Gates

Before saving a skill, verify:

- [ ] The problem is described clearly enough for someone unfamiliar
- [ ] The solution has been tested in this session
- [ ] The skill doesn't duplicate existing knowledge in `CLAUDE.md` or `tasks/lessons.md`
- [ ] The YAML frontmatter has accurate `name` and `description`
- [ ] The description is specific enough for semantic matching to work
- [ ] The skill includes a concrete "Why" with the problem it solves
- [ ] At least one "what goes wrong without this" example is included
- [ ] The rationale was confirmed by the user, not inferred by the agent

## Manual Invocation

When invoked with `/skill-extractor`:

1. Review the current session for non-obvious discoveries
2. Present candidates to the user with a one-line summary each
3. For approved candidates, create SKILL.md files
4. Report what was created and where

## File Structure

### Simple skill (single file)

```text
.claude/skills/<skill-name>/
  SKILL.md
```

### Extended skill (complex, with references)

```text
.claude/skills/<skill-name>/
  SKILL.md                  # Main instructions
  references/
    patterns.md             # Approved patterns with code examples
    anti-patterns.md        # Forbidden patterns with severity ratings
    checklist.md            # Pre-commit/merge verification checklist
```

Use the extended structure when a skill has 5+ rules, multiple code examples, or needs a checklist. Most skills should stay simple.

### Templates

```text
.claude/skills/skill-extractor/resources/
  skill-template.md          # Base SKILL.md template
  patterns-template.md       # Template for references/patterns.md
  anti-patterns-template.md  # Template for references/anti-patterns.md
  checklist-template.md      # Template for references/checklist.md
```
