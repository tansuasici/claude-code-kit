---
name: retro
description: Weekly retrospective with session analytics, LOC metrics, pattern detection, and persistent history
user-invocable: true
---

# Retro

## When to Use

Invoke with `/retro` when:

- End of a work sprint or week
- Want to understand development velocity and patterns
- Team standup or retrospective meeting prep
- Assessing productivity trends over time
- After a difficult period to understand what went wrong

## Process

### Phase 1: Session Detection

Analyze git history to identify work sessions:

1. **Read commit log** — `git log --all --format='%H %aI %an %s' --since='1 week ago'`
2. **Detect sessions** by grouping commits with &lt;45 min gaps between them
3. **Classify sessions**:
   - **Deep** (50+ min) — sustained focused work
   - **Medium** (20-50 min) — moderate work blocks
   - **Micro** (&lt;20 min) — quick fixes, reviews, hotfixes
4. **Per author** if multiple contributors

### Phase 2: Metrics

Calculate development metrics:

**Volume**
- Lines added / removed / net (from `git diff --stat`)
- Files changed
- Commits count
- PRs merged (via `gh pr list --state merged` if available)

**Velocity**
- LOC per hour (lines changed ÷ session hours)
- Commits per session
- Average session duration

**Patterns**
- Most active files (change hotspots)
- Most active directories (where work concentrates)
- Commit type distribution (feat/fix/refactor/test/docs)
- Time-of-day distribution (morning/afternoon/evening/night)

### Phase 3: Qualitative Analysis

Review the work content:

1. **Read commit messages** — summarize what was accomplished
2. **Check tasks/todo.md** — what was planned vs. what was done
3. **Check tasks/lessons.md** — what corrections were made
4. **Check tasks/decisions.md** — what architectural decisions were recorded
5. **Identify blockers** — long gaps between sessions, reverted commits, repeated attempts

### Phase 4: Insights

Generate actionable insights:

- **What went well** — completed features, clean implementations, good test coverage
- **What was hard** — bugs that took multiple sessions, scope creep, repeated corrections
- **What to improve** — patterns to adopt, patterns to drop, process changes
- **Focus areas** — where the team spent most time (is that where they should?)

### Phase 5: History (Optional)

If `tasks/retros/` directory exists, save the retrospective:

1. Generate filename: `tasks/retros/retro-YYYY-MM-DD.md`
2. Save the full report
3. Compare with previous retros to identify trends

## Output Format

```markdown
# Retrospective — Week of YYYY-MM-DD

## Summary
[1-2 sentences: what was the focus this week?]

## Session Analysis
| # | Date | Duration | Type | Author | Key Work |
|---|------|----------|------|--------|----------|
| 1 | Mon 10:30 | 2h15m | Deep | alice | Auth system implementation |
| 2 | Mon 15:00 | 35m | Medium | alice | Fix login redirect |
| 3 | Tue 09:00 | 3h | Deep | bob | Search feature |

**Totals**: N sessions, Nh total, N deep / N medium / N micro

## Metrics
| Metric | This Week | Trend |
|--------|-----------|-------|
| Lines changed | +1,234 / -456 | — |
| Commits | 23 | — |
| Files touched | 18 | — |
| LOC/hour | ~150 | — |

## Commit Distribution
- feat: N (X%)
- fix: N (X%)
- refactor: N (X%)
- test: N (X%)
- docs: N (X%)

## What Went Well
- [Accomplishment]

## What Was Hard
- [Challenge + time spent]

## Insights
- [Actionable observation]

## Focus Areas
[Where time was spent vs. where it should be spent]

## Action Items
- [ ] [Specific improvement for next week]
```

## Notes

- Session detection uses 45-min gaps as the default threshold — adjust if your workflow differs
- Metrics are directional, not precise — git stats don't capture thinking time, meetings, or research
- If no git history exists for the period, report that and suggest what to track
- Compare with previous retros (if saved) to identify trends
- This is a reflective tool, not a surveillance tool — focus on patterns and improvements
