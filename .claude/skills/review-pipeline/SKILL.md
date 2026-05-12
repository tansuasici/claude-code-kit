---
name: review-pipeline
description: Run multiple audits in parallel over a PR-scope diff, dedupe across auditors, and produce a confidence-gated report. Distinct from /project-health-report (whole-project, breadth-first).
user-invocable: true
---

# Review Pipeline

## Kit Context

Before starting this skill, ensure you have completed session boot:
1. Read `CODEBASE_MAP.md` for project understanding
2. Read `CLAUDE.project.md` if it exists for project-specific rules
3. Read `tasks/lessons/_index.md` for accumulated corrections (Top Rules + index)

If any of these haven't been read in this session, read them now before proceeding.

## When to Use

Invoke with `/review-pipeline` when:

- A PR is ready and you want a multi-lens check before requesting human review
- A multi-session feature has landed on a branch and you want to catch regressions
- You're investigating a flaky area and want several auditors to weigh in
- You suspect issues but don't know which audit applies — let the pipeline pick

Not for:

- Trivial single-file edits — invoke the relevant audit directly
- Project-wide periodic health checks — use `/project-health-report` instead
- Full architectural assessments — use `/architecture-review` or `/deepening-review`

## Scope Rules

- Read-only — produces a report, never modifies code
- Operates within the detected scope (recent changes by default)
- Logs unrelated issues found during analysis under `tasks/todo.md > ## Not Now`
- Does not duplicate findings already in CLAUDE.md or `tasks/lessons/`

## Process

### Phase 1: Resolve Scope

Pick the smallest scope that captures the change:

1. **If the user passed paths or globs** — use those literally
2. **Else if the working tree has uncommitted changes** — use `git diff --name-only HEAD`
3. **Else if on a feature branch** — use `git diff --name-only $(git merge-base HEAD origin/main)...HEAD` (fall back to `main` if `origin/main` is absent)
4. **Else** — ask the user which path or commit range to review; do not silently default to the whole repo

Filter the file list:

- Drop generated paths (`node_modules/`, `dist/`, `build/`, `.next/`, `__pycache__/`, `vendor/`)
- Drop lockfiles unless `dependency-audit` is selected
- If the resulting list is empty, stop and report "no in-scope changes detected"

Save the resolved scope as a bulleted list — every parallel auditor gets the same list.

### Phase 2: Select Audits

Always select these core audits:

- `code-quality-audit` — smells, error handling, maintainability
- `testing-audit` — coverage gaps, test quality

Conditionally add based on file patterns in the resolved scope:

| Pattern in scope | Add audit |
|---|---|
| `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.html` | `accessibility-audit` |
| Service / handler / query / loop heavy code (≥1 file) | `performance-audit` |
| `package.json`, `pyproject.toml`, `requirements*.txt`, `Cargo.toml`, `go.mod` | `dependency-audit` |
| Module-level or full-folder change (≥5 files in one dir) | `dead-code-audit` |
| `README*`, `docs/`, public API surface changes | `documentation-audit` |
| Auth, session, token, crypto, request validation paths | `security-reviewer` (agent, not skill) |
| Multi-module structural change | `architecture-review` |

Cap at **5 parallel audits by default** to keep token spend bounded. If more are eligible, pick the 5 with the strongest fit to the scope and list the skipped ones in the report's "Skipped audits" section with a one-line rationale.

If the user passed an explicit list (e.g., `/review-pipeline testing,security`), honor it literally and skip selection logic.

### Phase 3: Run Audits in Parallel

For each selected audit, dispatch one Task in a **single message containing all tool calls** so they run concurrently. Pattern per Task:

```text
Task(
  description: "<audit-name> on <short scope label>",
  subagent_type: "general-purpose",
  prompt: """
    You are running the <audit-name> audit on a scoped set of files.

    Step 1 — Read the skill file at `.claude/skills/<audit-name>/SKILL.md` and follow
    its Process section. Do not invoke other audits; do not analyze files outside
    the scope below.

    Step 2 — Scope (files to analyze):
    <one bulleted file path per line>

    Step 3 — Return findings as a JSON array with this exact shape, nothing else:
    [
      {
        "file": "src/x.ts",
        "line": 42,
        "category": "smell|error-handling|test-gap|...",
        "severity": "critical|major|minor",
        "confidence": "high|medium|low",
        "message": "one-line summary",
        "suggested_fix": "one-line fix or null"
      },
      ...
    ]

    Do not include prose around the JSON. If you find nothing, return [].
  """
)
```

Wait for all Tasks to complete before continuing. If any single Task errors out, record the failure under "Skipped audits" and continue with the rest — never abort the whole pipeline because one auditor failed.

### Phase 4: Dedupe + Confidence Gating

Merge findings using this algorithm:

1. **Parse each auditor's JSON** into a flat array, tagging each finding with `audit: <auditor-name>`.

2. **Group findings** by the tuple `(normalized_file, line_bucket, category)` where:
   - `normalized_file` = repo-relative path with leading `./` stripped
   - `line_bucket` = `floor(line / 5) * 5` — collapses findings within 5 lines of each other
   - `category` = the auditor's category string, lowercased

3. **Within each group:**
   - Merge messages: keep the longest, most specific one as primary; append distinct shorter ones as bullets under "Also noted"
   - Compute `provenance` = sorted unique list of `audit` tags in the group
   - **Bump confidence:** if `|provenance| ≥ 2`, set group confidence to `high` regardless of individual confidences
   - **Max severity wins:** group severity = highest of (critical > major > minor)

4. **Confidence gate** (drop low-signal noise):
   - Keep group if `|provenance| ≥ 2` — multiple auditors agreed
   - Else keep group if `confidence = high` and `severity ∈ {critical, major}`
   - Else keep group if `confidence = high` and the message names a concrete file:line (not a category-only observation)
   - Else **drop** — single low/medium-confidence finding is noise

5. **Sort** by (severity desc, |provenance| desc, file asc).

### Phase 5: Assemble the Report

Produce one markdown report and offer to save it. Do not fix issues; only report.

Optional save target: `tasks/reviews/<YYYY-MM-DD>-<scope-slug>.md`. Ask the user before writing if any review file already exists for the same scope today; otherwise just create it and tell them the path.

## Output Format

```markdown
# Review Pipeline Report

**Scope:** <N files | git range | path glob>
**Audits run:** <comma-separated names> · <X> in parallel
**Audits skipped:** <comma-separated, or "none">
**Findings:** <C critical, M major, N minor> after dedupe (<R> raw)

---

## Cross-Audit Findings (≥2 auditors agreed)

> Highest signal — these are flagged by multiple lenses, treat as high confidence.

| # | Severity | File:Line | Category | Auditors | Issue |
|---|----------|-----------|----------|----------|-------|
| 1 | critical | src/auth.ts:42 | error-handling | quality, testing | ... |

## Single-Audit Findings — Critical

| # | File:Line | Audit | Issue | Suggested Fix |
|---|-----------|-------|-------|---------------|

## Single-Audit Findings — Major

| # | File:Line | Audit | Issue | Suggested Fix |
|---|-----------|-------|-------|---------------|

## Single-Audit Findings — Minor

> Folded by default. Expand only if reviewing thoroughly.

<details>
<summary>N minor findings</summary>

| # | File:Line | Audit | Issue |
|---|-----------|-------|-------|

</details>

## Skipped Audits

| Audit | Reason |
|-------|--------|
| dependency-audit | no dep file in scope |
| performance-audit | parallel cap reached; lower fit than selected 5 |

## Suggested Next Action

1. Address all Cross-Audit Findings first — they have the strongest signal
2. Triage Critical single-audit findings
3. Consider whether any Major findings warrant a follow-up task in `tasks/todo.md`
4. If patterns recur across PRs, promote them to `tasks/lessons/` or a hook
```

## Report Guidelines

- File paths with line numbers (`file.ts:42`) for every finding — never bare filenames
- "Also noted" bullets under a primary finding when auditors phrased the same issue differently
- The Cross-Audit table is the **headline** — readers scan it first
- Skipped audits get one row each — never silently omit
- Minor findings collapsed into a `<details>` block to keep the report scannable

## Run Mode

This skill supports interactive (default) and headless modes — see the canonical contract in `.claude/skills/_shared/blocks/mode-detection.md`.

Headless detection: presence of `mode:headless` in arguments. Other tokens after the flag are treated as explicit audit list (e.g., `mode:headless audits:testing,security`).

| Decision point | Interactive default | Headless default |
|---|---|---|
| **Empty scope** (no changes detected and no path given) | Ask the user which path or range | **Fail** with "no in-scope changes detected; pass a path explicitly". Never silently scan the whole repo. |
| **Scope >100 files** | Ask the user to narrow | Auto-narrow to the top-50 files by churn (`git log --name-only` count in the diff range). Note the truncation in the report. |
| **Audit selection** | Apply Phase 2 heuristics and inform user of selection | Apply the same heuristics; honor explicit `audits:<list>` arg if present |
| **Save report path collision** (a review for same scope/date already exists) | Ask before overwriting | Append `-2`, `-3`, etc. — never overwrite |
| **Save vs print only** | Offer to save | Always save to `tasks/reviews/<YYYY-MM-DD>-<scope-slug>.md` and print the path |

Headless review-pipeline is suitable for: scheduled PR sweeps (`/loop /review-pipeline mode:headless`), CI-side pre-merge gates, and skill-to-skill orchestration where the parent skill chose the scope.

## Notes

- **This skill orchestrates; it does not analyze.** Quality of the report depends on the underlying audit skills.
- **Default cap is 5 parallel audits** to bound token spend. Override with explicit selection if you need more.
- **Confidence bump is asymmetric**: agreement promotes to `high`, but disagreement does not demote. Two auditors disagreeing on severity → take the higher severity.
- **The line bucket of 5** is a heuristic for "same issue, different line counted". If you need stricter matching (exact line), say so when invoking; if you need looser (same function), increase the bucket.
- **Don't run on the whole repo by default.** If scope resolution returns >100 files, ask the user to narrow.
- **Save the report only when useful.** Quick checks during development don't need a saved file — interactive feedback is the point.
