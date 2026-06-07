---
name: doc-gardening
description: Cross-check docs/ against current code — flag stale file paths, broken cross-references, removed APIs, and outdated examples. Use when docs may have drifted after code changes. For doc completeness and quality use /documentation-audit instead.
user-invocable: true
---

# Doc Gardening

## Core Rule

Flag drift, never silently rewrite. A doc may be intentionally aspirational; the human decides whether to update the doc or the code. This skill produces a punch list — the human applies the fix.

## Kit Context

Before starting this skill, ensure you have completed session boot:
1. Read `CODEBASE_MAP.md` for project understanding
2. Read `CLAUDE.project.md` if it exists for project-specific rules
3. Read `tasks/lessons/_index.md` for accumulated corrections (Top Rules + index)

If any of these haven't been read in this session, read them now before proceeding.

## When to Use

Invoke with `/doc-gardening` when:

- The codebase has shifted (rename, refactor, feature removal) and you suspect docs lag behind
- After a major release, to sweep `docs/` and `README.md` for stale references
- As a scheduled background task (`/loop weekly /doc-gardening`) to keep drift bounded
- Before publishing a release or onboarding a new contributor

## Default Behavior

When the user asks to audit, scan, review, or "give me a report" for doc drift, produce the full doc-gardening report automatically using the Process and Output Format sections below. Do not require the user to specify fields.

Only modify files when the user explicitly requests implement / fix / apply / refactor. By default, this skill is **report-only**.

## Scope

This skill covers:

- `docs/` (all `*.md` files)
- `README.md` at repo root
- `CODEBASE_MAP.md` at repo root
- `tasks/lessons/_index.md` (only the Top Rules section — checks if rule references still exist)
- `agent_docs/*.md` (kit-only) — checks the per-doc directory listing in `CLAUDE.md`

It does NOT cover:

- Inline code comments (use `/documentation-audit` for that)
- Git history, changelogs, or release notes (intentionally retrospective)
- Files under `docs/archive/` or `docs/legacy/` (assume intentional)

## Process

### Phase 1: Inventory (first-pass leads)

This pass produces **candidates**, not findings. Treat counts as leads for deeper inspection in later phases. Do not report Phase 1 raw output as the final result.

1. List all markdown files in scope.
2. For each, extract: file path references, code symbols in backticks, fenced code blocks with import/require lines, cross-doc links (`[...](...)`).
3. Hold the lists; do not classify yet.

### Phase 2: Drift Detection

For each extracted reference, classify into one of these categories:

**File path references** (e.g., `src/lib/foo.ts`, `.claude/hooks/bar.sh`)
- ✅ Exists at the referenced path → OK
- ❌ Does not exist → **stale path** (HIGH)
- ⚠️ Exists but was renamed/moved (path different than current `git log --follow`) → **moved** (MEDIUM)

**Symbols in backticks** that look like functions/classes (e.g., `useAuth()`, `validatePayload`)
- For each, grep the codebase for definition. If 0 hits → **missing symbol** (MEDIUM). If ≥1 hit → OK.
- This is intentionally lossy — backticks can hold non-code things. Phase 3 triage filters false positives.

**Cross-doc links** (relative `[...](path)` links)
- ❌ Target does not exist → **broken link** (HIGH)
- ⚠️ Target exists but anchor (`#section`) does not match any heading in the target → **broken anchor** (LOW)

**Fenced code blocks with import paths**
- For each `import ... from "..."` or `require("...")`, resolve the path against repo. Missing → **stale example** (MEDIUM).

**Versions in prose** (regex: `v\d+\.\d+\.\d+`)
- Compare against the latest version in the repo (`package.json` → `version`, or `CHANGELOG.md` first heading).
- If the doc cites a version older than the latest by 2+ minor versions → **stale version** (LOW). Skip changelog entries themselves.

### Phase 3: Triage

For each candidate finding:

1. **Suppress** if the file is in `docs/archive/`, `docs/legacy/`, or matches `.doc-gardening-ignore` glob list.
2. **Suppress** if the markdown line is inside a triple-fence comment (` ``` ` to ` ``` `) tagged as `text` or `example` — those are intentional samples.
3. **De-duplicate** by `(file, line, kind)`.

### Phase 4: Report

Group findings by severity (HIGH > MEDIUM > LOW), then by source doc.

## Output Format

```markdown
# Doc Gardening Report

_Last run: 2026-05-18T14:23:00Z — doc-gardening v1_

## Summary

| Metric | Value |
|--------|-------|
| Docs scanned | 24 |
| Findings | 11 |
| HIGH | 2 |
| MEDIUM | 6 |
| LOW | 3 |

## HIGH — Likely broken

### `docs/getting-started.md`

| # | Line | Kind | Reference | Suggestion |
|---|------|------|-----------|------------|
| 1 | 42 | stale path | `src/lib/auth-old.ts` | File removed in 1.10.0. Update to `src/lib/auth.ts` or remove section. |
| 2 | 87 | broken link | `[Architecture](./arch.md)` | Target missing. Did you mean `docs/architecture.md`? |

## MEDIUM — Worth a closer look

### `README.md`

| # | Line | Kind | Reference | Suggestion |
|---|------|------|-----------|------------|
| 1 | 12 | moved | `bin/cli.js` | Was renamed to `bin/index.js` in commit a1b2c3d. |

### `docs/api.md`

| # | Line | Kind | Reference | Suggestion |
|---|------|------|-----------|------------|
| 1 | 33 | missing symbol | `validatePayload()` | No definition found. Renamed to `parsePayload()`? |
| 2 | 68 | stale example | `import { LegacyClient } from '../sdk'` | Module removed. Update example. |

## LOW — Cosmetic

### `docs/changelog.md`

| # | Line | Kind | Reference | Suggestion |
|---|------|------|-----------|------------|
| 1 | 5 | broken anchor | `[#core-rule](./rules.md#core-rule)` | Section was renamed to `## The Core Rule`. |

## Suggested actions

- `docs/getting-started.md` has the most drift — review next.
- 4 findings reference paths that moved during the auth refactor (commits a1b2c3d..d4e5f6a) — bulk-fix candidate.
- Consider adding `docs/legacy/v0/` to `.doc-gardening-ignore` if those files are intentionally frozen.
```

## Run Mode

| Decision point | Interactive default | Headless default (`mode:headless`) |
|---|---|---|
| Auto-fix obvious renames | Ask | Never — report only |
| Add finding to `tasks/todo.md` | Ask | Always append to `tasks/todo.md → ## Doc Drift` |
| Open follow-up PR | Ask | Never |

See `.claude/skills/_shared/blocks/mode-detection.md`.

## Loop / Schedule Integration

```text
/loop weekly /doc-gardening mode:headless
/schedule monthly /doc-gardening mode:headless
```

In headless mode, findings are appended to `tasks/todo.md → ## Doc Drift` so the next human session sees them.

## Notes

- This skill is **complementary** to `/documentation-audit`. The latter assesses *completeness and clarity*; this skill watches for *drift between docs and code*.
- The detection is intentionally heuristic — false positives are expected. The triage phase suppresses obvious ones; the rest are leads for human review.
- If a kind of finding has 10+ false positives across runs, propose adding it to `.doc-gardening-ignore` rather than tweaking the detector.
- Doc-gardening complements `/quality-audit` — together they form the "Friday cleanup" recipe inspired by OpenAI's harness engineering pattern.
