---
name: wiki-ingest
description: Ingest a new source into the knowledge wiki — read, summarize, cross-reference, and update index
user-invocable: true
---

# Wiki Ingest

## When to Use

Invoke with `/wiki-ingest` when:

- A new file has been added to `raw-sources/`
- You want to process an article, transcript, PDF, or notes into the wiki
- You're batch-ingesting multiple sources
- You've clipped a web article with Obsidian Web Clipper

## Process

### Phase 1: Discover

1. Read `WIKI.md` for vault conventions and directory structure
2. Read `wiki/index.md` for current wiki state
3. Identify the new source(s) in `raw-sources/`
   - If user specifies a file, use that
   - If user says "process new sources", find files not yet listed in index.md

### Phase 2: Read & Extract

For each new source:

1. Read the source file completely
2. Identify:
   - Key takeaways (3-5 bullets)
   - Entities mentioned (people, tools, organizations, projects)
   - Concepts discussed (ideas, frameworks, patterns)
   - Claims that might contradict or reinforce existing wiki content
   - Metadata: author, date, URL, type

### Phase 3: Write Summary

1. Create `wiki/summaries/{source-name}.md` with frontmatter:
   ```yaml
   ---
   title: Source Title
   type: summary
   sources: [original-filename.md]
   created: YYYY-MM-DD
   updated: YYYY-MM-DD
   tags: [relevant, tags]
   ---
   ```
2. Include: key takeaways, detailed summary, notable quotes (attributed), source metadata

### Phase 4: Cross-Reference

1. **Entities**: For each entity mentioned:
   - If `wiki/entities/{name}.md` exists → update with new information, cite the source
   - If entity appears in 2+ sources but has no page → create one
2. **Concepts**: For each concept:
   - If `wiki/concepts/{name}.md` exists → update, note agreements/contradictions
   - If concept is significant and new → create a page
3. Use `[[wikilinks]]` in all pages for cross-references

### Phase 5: Update Index & Log

1. Add entry to `wiki/index.md` under the appropriate section
2. Append to `wiki/log.md`:
   ```markdown
   ## [YYYY-MM-DD] ingest | Source Title
   - Summary: wiki/summaries/source-name.md
   - Updated: [list of modified pages]
   - New pages: [list of created pages]
   ```

## Output Format

Report to user:

```markdown
### Ingest Complete: {Source Title}

**Summary**: wiki/summaries/{name}.md
**Key takeaways**:
- Bullet 1
- Bullet 2
- Bullet 3

**Files touched** ({N} total):
- Created: wiki/summaries/source-name.md
- Updated: wiki/entities/entity-a.md, wiki/concepts/concept-b.md
- Created: wiki/entities/new-entity.md

**Connections found**:
- Links to [[existing-concept]] — reinforces claim about X
- Contradicts [[other-page]] on Y — flagged in both pages
```

## Rules

1. Never modify files in `raw-sources/` — they are immutable
2. Always update `wiki/index.md` after any change
3. Always append to `wiki/log.md`
4. Every wiki claim must cite its source
5. Flag contradictions explicitly — do not silently resolve
6. Prefer updating existing pages over creating new ones
7. Ask the user before creating pages for minor/ambiguous entities
8. If ingesting multiple sources, process one at a time and report each
