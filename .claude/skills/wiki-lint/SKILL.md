---
name: wiki-lint
description: Health-check the knowledge wiki — find contradictions, orphans, missing pages, and stale content
user-invocable: true
---

# Wiki Lint

## When to Use

Invoke with `/wiki-lint` when:

- Wiki has grown and you want a health check
- You suspect stale or contradictory content
- Running a periodic (weekly) maintenance pass
- Preparing the wiki for a new research phase

## Process

### Phase 1: Inventory

1. Read `WIKI.md` for vault conventions
2. Read `wiki/index.md` for the catalog
3. Glob all files in `wiki/` recursively
4. Compare: files on disk vs. entries in index.md

### Phase 2: Structural Checks

1. **Orphan pages** — wiki pages with zero inbound `[[wikilinks]]` from other pages
2. **Missing pages** — `[[wikilinks]]` that point to files that don't exist
3. **Broken links** — wikilinks to pages that were renamed or removed
4. **Index drift** — pages that exist on disk but aren't listed in index.md (or vice versa)
5. **Empty pages** — pages with frontmatter but no meaningful content

### Phase 3: Content Checks

1. **Contradictions** — pages that make conflicting claims about the same topic
   - Compare entity pages against each other and against summaries
   - Flag with exact quotes and source citations
2. **Stale claims** — check if newer sources in `raw-sources/` supersede claims in the wiki
   - Compare file dates: source newer than wiki page that references it
3. **Hub gaps** — concepts or entities mentioned in 3+ pages but lacking a dedicated page
4. **Thin pages** — pages with less than 3 sentences of actual content (excluding frontmatter)

### Phase 4: Report

Write `wiki/lint-report.md`:

```markdown
---
title: Wiki Lint Report
type: analysis
created: YYYY-MM-DD
---

# Wiki Lint Report — YYYY-MM-DD

## Summary
- Pages scanned: N
- Issues found: N
- Critical: N | Warning: N | Info: N

## Critical Issues

### Contradictions
| Page A | Page B | Conflict | Sources |
|--------|--------|----------|---------|
| [[page-a]] | [[page-b]] | Disagree on X | source1.md vs source2.md |

### Missing Pages
- [[missing-page]] — referenced by: page-a.md, page-b.md

## Warnings

### Orphan Pages
- [[orphan-page]] — no inbound links, consider linking or removing

### Stale Content
- [[stale-page]] — last updated YYYY-MM-DD, newer source exists

## Suggestions

### Hub Gaps
- "concept-name" mentioned in N pages but has no dedicated page
  - Referenced in: [[page-a]], [[page-b]], [[page-c]]

### Index Drift
- Files not in index: page-x.md, page-y.md
- Index entries without files: old-page.md
```

### Phase 5: Log

Append to `wiki/log.md`:
```
## [YYYY-MM-DD] lint | Health check
- Report: wiki/lint-report.md
- Issues: N critical, N warnings, N suggestions
```

## Output Format

Print a summary to the user:

```markdown
### Wiki Health Report

**Scanned**: {N} pages across {N} directories
**Issues**: {N} critical, {N} warnings, {N} suggestions

**Critical**:
- 2 contradictions found (see lint-report.md)
- 3 missing pages (wikilinks to non-existent files)

**Top suggestions**:
- Create page for "concept-x" (mentioned in 5 pages)
- Update "entity-y" (newer source available)

Full report: wiki/lint-report.md
```

## Rules

1. Never modify wiki pages during lint — report only
2. Always write the full report to `wiki/lint-report.md`
3. Always append to `wiki/log.md`
4. Distinguish severity: critical (contradictions, broken links) > warning (stale, orphan) > info (suggestions)
5. Include actionable fixes — don't just list problems
6. If the wiki is small (< 10 pages), skip structural checks and focus on content
