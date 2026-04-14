---
name: wiki-briefing
description: Morning briefing from the knowledge wiki — recent activity, new sources, open actions, and key updates
user-invocable: true
---

# Wiki Briefing

## When to Use

Invoke with `/wiki-briefing` when:

- Starting a new session and want to know what changed
- Morning routine — quick overview of wiki state
- After a break — catch up on recent ingests and changes
- Want a summary of open items and recent activity

## Process

### Phase 1: Recent Activity

1. Read `wiki/log.md` — extract the last 5-10 entries
2. Summarize: what was ingested, queried, or linted recently
3. Note the date of last activity — flag if wiki has been idle

### Phase 2: New Sources

1. List files in `raw-sources/` with modification dates
2. Identify any files added since the last log entry
3. If unprocessed sources exist, flag them for ingest

### Phase 3: Wiki State

1. Read `wiki/index.md` — count total sources and wiki pages
2. Check if `wiki/lint-report.md` exists and has unresolved issues
3. Note any pages updated in the last 7 days

### Phase 4: Open Actions (if applicable)

1. Search wiki pages for action items, TODOs, or open questions
2. Check for pages marked with `status: draft` or `status: review` in frontmatter
3. Surface any items tagged with today's date or past-due dates

## Output Format

```markdown
### Wiki Briefing — YYYY-MM-DD

**Wiki size**: {N} sources ingested, {N} wiki pages

**Recent activity** (last 7 days):
- [date] Ingested: "Article Title" → wiki/summaries/article.md
- [date] Query: "Question asked" → wiki/analyses/answer.md
- [date] Lint: 3 issues found (2 resolved)

**Unprocessed sources** ({N}):
- raw-sources/new-article.md (added YYYY-MM-DD)
- raw-sources/transcript.md (added YYYY-MM-DD)
→ Run `/wiki-ingest` to process these

**Open items**:
- Draft page: wiki/concepts/draft-concept.md
- Open question in wiki/entities/some-entity.md: "Need to verify X"

**Health**:
- Last lint: YYYY-MM-DD ({N} days ago)
- Unresolved issues: {N}
→ Run `/wiki-lint` for a fresh check
```

If the wiki is empty or not yet initialized:
```markdown
### Wiki Briefing — YYYY-MM-DD

Your wiki is empty. To get started:
1. Add source files to `raw-sources/` (articles, notes, transcripts)
2. Run `/wiki-ingest` to process them into the wiki
3. Ask questions — Claude will search the wiki and save valuable answers
```

## Rules

1. Keep the briefing concise — this is a morning glance, not a deep report
2. Always check for unprocessed sources — this is the most actionable item
3. If last lint was > 7 days ago, suggest running `/wiki-lint`
4. Don't read every wiki page — use index.md and log.md for the overview
5. If wiki doesn't exist yet, guide the user to get started
