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

---

## Periodic Cleanup ("Spa Day")

As rules, skills, and lessons accumulate, agent performance degrades. This is context bloat — the agent reads too much conflicting or irrelevant information before doing actual work.

### When to Clean Up

- Agent starts ignoring rules it used to follow
- Agent behavior becomes inconsistent across sessions
- Session boot requires reading 10+ files
- Skills or lessons contradict each other
- You notice the agent "forgetting" things mid-session more often

### Cleanup Checklist

Run this periodically (every 2-4 weeks or when symptoms appear):

#### 1. Audit CLAUDE.md
- [ ] Is every instruction still relevant?
- [ ] Are there rules that no longer apply to the project?
- [ ] Are there contradictions between rules?
- [ ] Is the agent_docs directory listing still accurate?

#### 2. Consolidate Lessons
- [ ] Read all entries in `tasks/lessons.md`
- [ ] Merge duplicate or similar lessons
- [ ] Remove lessons that have been encoded as rules in CLAUDE.md
- [ ] Remove lessons for bugs that were structurally fixed (no longer possible)

#### 3. Prune Skills
- [ ] List all skills: `ls .claude/skills/`
- [ ] For each skill: is the problem still relevant?
- [ ] For each skill: has the solution become standard (in docs or framework)?
- [ ] For each skill: does the YAML description still match what it does?
- [ ] Remove stale or redundant skills

#### 4. Check for Contradictions
- [ ] Do any skills contradict CLAUDE.md rules?
- [ ] Do any lessons contradict skills?
- [ ] Do any agent_docs files give conflicting advice?
- [ ] Resolve every contradiction — pick one source of truth

#### 5. Measure Context Load
Count how many files the agent reads at session boot + task start:
- **Healthy**: 3-5 files
- **Concerning**: 6-10 files
- **Critical**: 10+ files — consolidate immediately

### How to Run a Cleanup Session

Tell the agent:

```text
Read all files in agent_docs/, tasks/lessons.md, all skills in .claude/skills/,
and CLAUDE.md. Identify contradictions, stale content, and redundancies.
Present a consolidation plan. Do not make changes until I confirm.
```

This leverages the agent's ability to cross-reference content while keeping you in control of what gets removed.
