# WIKI.md — Knowledge Wiki Schema

This file configures Claude as a wiki maintainer for your Obsidian vault.
When this file exists, Claude follows the ingest, query, and lint workflows below.

---

## Architecture

Three layers, strict separation:

| Layer | Path | Owner | Mutability |
|-------|------|-------|------------|
| Raw sources | `raw-sources/` | Human | Immutable — Claude reads, never modifies |
| Wiki | `wiki/` | Claude | Claude creates, updates, maintains |
| Schema | `WIKI.md` (this file) | Both | Co-evolved over time |

---

## Directory Structure

```text
raw-sources/              # Drop articles, PDFs, transcripts, notes here
  assets/                 # Downloaded images and attachments

wiki/                     # Claude-maintained knowledge base
  index.md                # Content catalog — Claude reads first on every query
  log.md                  # Chronological activity log (append-only)
  summaries/              # One page per ingested source
  entities/               # People, tools, organizations, projects
  concepts/               # Ideas, patterns, frameworks, topics
```

---

## Page Conventions

Every wiki page uses YAML frontmatter:

```yaml
---
title: Page Title
type: summary | entity | concept | comparison | analysis
sources: [filename1.md, filename2.md]
created: 2026-04-14
updated: 2026-04-14
tags: [tag1, tag2]
---
```

- Use `[[wikilinks]]` for internal cross-references
- File names: kebab-case (`machine-learning.md`, `openai.md`)
- One concept per page — split if a page covers multiple distinct ideas
- Link liberally — every mention of a known entity or concept should be a wikilink

---

## Operations

### Ingest

When a new source appears in `raw-sources/`:

1. Read the source completely
2. Create `wiki/summaries/{source-name}.md` with:
   - Key takeaways (3-5 bullets)
   - Detailed summary
   - Source metadata (author, date, URL if available)
3. Update `wiki/index.md` — add entry with link and one-line description
4. For each entity mentioned:
   - If entity page exists → update with new information, note the source
   - If entity is mentioned 2+ times across sources but has no page → create one
5. For each concept mentioned:
   - If concept page exists → update, note agreements/contradictions with existing content
   - If concept is new and significant → create a page
6. Append to `wiki/log.md`:
   ```markdown
   ## [YYYY-MM-DD] ingest | Source Title
   - Summary: wiki/summaries/source-name.md
   - Updated: list of touched pages
   - New pages: list of created pages
   ```
7. Report every file touched

### Query

When answering a question from the wiki:

1. Read `wiki/index.md` to find relevant pages
2. Read the relevant wiki pages (not raw sources — the wiki is pre-synthesized)
3. Synthesize an answer with `[[wikilink]]` citations
4. If the answer produces a valuable artifact (comparison table, analysis, timeline):
   - Save it as a new wiki page (type: comparison | analysis)
   - Update index.md
   - Append to log.md

### Lint

Periodic health check of the wiki:

1. Read every file in `wiki/`
2. Check for:
   - **Contradictions** — pages that disagree on facts
   - **Orphan pages** — no inbound wikilinks from other pages
   - **Missing pages** — wikilinks that point to non-existent pages
   - **Stale claims** — information superseded by newer sources
   - **Hub gaps** — concepts mentioned 3+ times but lacking a dedicated page
   - **Broken links** — wikilinks to pages that were renamed or removed
3. Write report to `wiki/lint-report.md`
4. Suggest specific fixes for each issue found
5. Append to `wiki/log.md`

---

## Index Format

`wiki/index.md` structure:

```markdown
# Wiki Index

Last updated: YYYY-MM-DD
Sources: N | Wiki pages: N

## Summaries
- [[source-name]] — One-line description (YYYY-MM-DD)

## Entities
- [[entity-name]] — Type, brief description

## Concepts
- [[concept-name]] — Brief description

## Analyses
- [[analysis-name]] — What it compares/analyzes
```

---

## Log Format

`wiki/log.md` — append-only, newest at bottom:

```markdown
# Wiki Log

## [YYYY-MM-DD] ingest | Article Title
- Summary: wiki/summaries/article-title.md
- Updated: wiki/entities/some-entity.md, wiki/concepts/some-concept.md
- New pages: wiki/entities/new-entity.md

## [YYYY-MM-DD] query | Question asked
- Answer saved: wiki/analyses/comparison-name.md

## [YYYY-MM-DD] lint | Health check
- Report: wiki/lint-report.md
- Issues found: 3 contradictions, 2 orphans, 5 missing pages
```

---

## Rules

1. **Never modify raw sources** — they are immutable ground truth
2. **Always update index.md** after any wiki change
3. **Always append to log.md** after any operation
4. **Cite sources** — every claim in the wiki should trace back to a raw source
5. **Flag contradictions** — don't silently resolve them, note both claims and their sources
6. **Prefer updating over creating** — enrich existing pages before making new ones
7. **Keep summaries concise** — the wiki is a synthesis, not a copy of the source
