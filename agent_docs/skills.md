# Skills Guide

## What Are Skills?

Skills are `.claude/skills/<name>/SKILL.md` files that Claude Code loads automatically via semantic matching. When a task matches a skill's description, Claude gets the skill's knowledge injected into context — no manual loading needed.

## Skills vs Lessons

| | `tasks/lessons.md` | `.claude/skills/` |
|---|---|---|
| **Trigger** | User corrects Claude | Claude discovers something non-obvious |
| **Content** | What went wrong + rule to follow | Problem + context + verified solution |
| **Format** | Issue / Root Cause / Rule | YAML frontmatter + structured sections |
| **Loading** | Read manually at session boot | Automatic via semantic matching |
| **Scope** | Mistakes to avoid | Knowledge to apply proactively |
| **Lifetime** | Grows per-project | Grows per-project, can be shared |

**Both systems complement each other.** Lessons prevent repeated mistakes. Skills proactively surface relevant knowledge.

## The Skill Extractor

The kit includes a built-in `skill-extractor` skill at `.claude/skills/skill-extractor/SKILL.md`. It:

- Can be invoked manually with `/skill-extractor`
- Activates automatically via semantic matching when discovery-worthy knowledge appears
- Uses a structured template for consistent skill formatting
- Has quality gates to prevent low-value extractions

## Enabling the Reminder Hook

An optional `UserPromptSubmit` hook reminds Claude to consider skill extraction at each prompt. It's **not enabled by default** (same as `auto-lint` and `auto-format`).

To enable, add to `.claude/settings.json` under the `hooks` key:

```json
"UserPromptSubmit": [
  {
    "hooks": [
      {
        "type": "command",
        "command": ".claude/hooks/skill-extract-reminder.sh"
      }
    ]
  }
]
```

## Writing Good Skills

### Do Extract

- Framework quirks that caused hard-to-debug issues
- Config combinations that are required but undocumented
- Workarounds for known dependency bugs
- Project patterns that deviate from convention
- API behaviors that differ from documentation

### Don't Extract

- Anything easily found in official docs
- One-time fixes unlikely to recur
- User preferences (put in `CLAUDE.md`)
- User corrections (put in `tasks/lessons.md`)
- Unverified guesses

### Quality Checklist

- [ ] Problem is clear to someone unfamiliar with the context
- [ ] Solution has been verified in this session
- [ ] Doesn't duplicate `CLAUDE.md` rules or existing lessons
- [ ] YAML `description` is specific enough for semantic matching
- [ ] Includes verification steps

## Skill Lifecycle

1. **Discovery** — Claude encounters something non-obvious during a session
2. **Verification** — The discovery is confirmed to be correct
3. **Extraction** — Written as a SKILL.md using the template
4. **Loading** — Automatically picked up by Claude Code's semantic matching
5. **Maintenance** — Update or remove skills as the project evolves

### Maintenance Tips

- Review `.claude/skills/` periodically — delete stale skills
- If a skill's solution becomes the documented approach, remove it
- If a skill applies to multiple projects, consider extracting it to `~/.claude/skills/` (user-level)
