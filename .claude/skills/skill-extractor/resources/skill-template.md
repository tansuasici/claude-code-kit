---
name: <kebab-case-name>
description: <one-line description for semantic matching>
user-invocable: false
---

# <Skill Title>

## Problem

<!-- What goes wrong or is confusing? Be specific. -->

## Why This Matters

<!-- What happens without this knowledge? What's the cost of getting it wrong? -->
<!-- This section must be filled before extraction is complete. -->

## Context

<!-- When does this happen? What stack/version/config triggers it? -->

- Stack:
- Version:
- Conditions:

## Solution

<!-- Step-by-step fix or correct approach. -->

1. ...
2. ...
3. ...

## Verification

<!-- How to confirm the solution works. -->

```bash
# Command or check that proves correctness
```

## Notes

<!-- Gotchas, edge cases, or related issues. -->

## References

<!-- Links, issue numbers, or file paths that back this up. -->

---

## Extended Structure (Optional)

For complex skills that need more detail, create a folder structure:

```text
.claude/skills/<skill-name>/
├── SKILL.md                  # Main instructions (this file)
├── references/               # Optional — for complex skills
│   ├── patterns.md           # Approved patterns with code examples
│   ├── anti-patterns.md      # Forbidden patterns with severity ratings
│   └── checklist.md          # Pre-commit/merge verification checklist
```

See the templates below for each optional file.
