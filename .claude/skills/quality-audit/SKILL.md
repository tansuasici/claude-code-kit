---
name: quality-audit
description: Audit the codebase against the project's golden-principles.yaml — runs deterministic detection rules and updates docs/QUALITY_SCORE.md. Use to enforce project-specific principles. For a generic smell pass with no rules file use /code-quality-audit.
user-invocable: true
---

# Quality Audit

## Core Rule

Only report drift that a `golden-principles.yaml` rule can detect deterministically. Never invent rules during the audit — if it's not in the YAML, it doesn't appear in the report.

## Kit Context

Before starting this skill, ensure you have completed session boot:
1. Read `CODEBASE_MAP.md` for project understanding
2. Read `CLAUDE.project.md` if it exists for project-specific rules
3. Read `tasks/lessons/_index.md` for accumulated corrections (Top Rules + index)

If any of these haven't been read in this session, read them now before proceeding.

## When to Use

Invoke with `/quality-audit` when:

- The project has (or should have) a `golden-principles.yaml` and you want to measure drift
- Onboarding to a project and want to see where the codebase deviates from documented principles
- Running as a scheduled background task (`/loop daily /quality-audit`) to track quality trends
- Preparing for a refactoring sprint — turn drift findings into a backlog

## Default Behavior

When the user asks to audit, scan, review, or "give me a report" for golden-principles drift, produce the full quality-audit report automatically using the Process and Output Format sections below. Do not require the user to specify fields.

Only modify files when the user explicitly requests implement / fix / apply / refactor. By default, this skill is **report-only** (with one exception: it updates `docs/QUALITY_SCORE.md` because that file is the report's destination).

## Inputs

The skill looks for `golden-principles.yaml` in this order:

1. `golden-principles.yaml` (repo root)
2. `.claude/golden-principles.yaml`

If neither exists, the skill emits a stub and a one-paragraph guide pointing at `.claude/skills/quality-audit/templates/golden-principles.example.yaml`. It does not invent rules.

## Schema: golden-principles.yaml

```yaml
# golden-principles.yaml — deterministic, machine-checkable project rules
# Each principle must have an id, rule, severity, detect, and fix_hint.
# Optional: tags, paths, enabled.

version: 1

principles:
  - id: prefer-shared-utils
    rule: "Hand-rolled helpers should be replaced with shared util packages"
    severity: major            # critical | major | minor
    detect:
      type: grep               # grep | rg | command
      pattern: "function (debounce|throttle|deepClone)\\b"
      paths:                   # optional — defaults to repo root excluding vendor/build dirs
        - "src/**/*.ts"
        - "src/**/*.tsx"
    fix_hint: "Use @workspace/utils/{debounce,throttle,deepClone} instead."
    tags: [refactor, utils]
    enabled: true

  - id: no-yolo-data
    rule: "Don't traverse data structures without validation at the boundary"
    severity: critical
    detect:
      type: rg
      pattern: "JSON\\.parse\\("
      paths: ["src/**/*.ts"]
    fix_hint: "Wrap with Zod schema parse() — see src/schemas/."
    tags: [type-safety, boundary]

  - id: no-direct-db-in-route
    rule: "Route handlers must not import database clients directly"
    severity: critical
    detect:
      type: command
      command: "rg -l 'from .prisma|from .drizzle' src/app/api/ | head -20"
      # 'command' shells out exactly as written. Output lines = matches.
    fix_hint: "Move queries to src/repositories/ and inject through a service."
```

**Detection types:**

- `grep` — `grep -RnE "<pattern>" <paths>`. Portable, slowest.
- `rg` — `rg --column -e "<pattern>" <paths>`. Fast, requires ripgrep. Falls back to grep if `rg` is absent.
- `command` — shell out exactly as written. Each output line is one match. Use sparingly — harder to audit.

**Severity → weight (for the score):**

| Severity | Weight |
|----------|--------|
| critical | 5 per match |
| major | 2 per match |
| minor | 1 per match |

**Score formula:** `score = max(0, 100 - sum(weight × matches))`. Clamped to `[0, 100]`. Reported alongside per-principle counts so a single noisy rule doesn't hide the picture.

## Process

### Phase 1: Inventory (first-pass leads)

This pass produces **candidates**, not findings. Treat counts as leads for deeper inspection in later phases. Do not report Phase 1 raw output as the final result.

1. Resolve `golden-principles.yaml` (root → `.claude/`). If missing, emit the stub guide and stop.
2. Parse the YAML. Skip principles with `enabled: false`.
3. Validate each principle has `id`, `rule`, `severity`, `detect`, `fix_hint`. Skip malformed entries with a warning line in the report.
4. For each enabled principle, run its `detect` rule and collect raw matches. **These are candidates, not confirmed violations.**

### Phase 2: Triage

For each principle's candidates:

1. **Suppress false positives.** Skip matches inside comments, test fixtures (`**/*.test.*`, `**/__fixtures__/**`), and any path matching the principle's own implementation (use `.quality-audit-ignore` glob list if present).
2. **De-duplicate** by file:line.
3. Keep top 25 matches per principle (full count is preserved in the metrics row).

### Phase 3: Score & Report

1. Compute the score using the formula above.
2. Group findings by severity → critical / major / minor.
3. For each finding, include: `file:line`, the matched snippet (trimmed to 80 chars), and the principle's `fix_hint`.

### Phase 4: Write `docs/QUALITY_SCORE.md`

If `docs/` does not exist, skip the file write and print the report to stdout. Do NOT create `docs/` from this skill — that's `/harness-init`'s job.

If `docs/QUALITY_SCORE.md` exists:

1. Preserve any section above the `<!-- quality-audit:start -->` marker.
2. Replace content between `<!-- quality-audit:start -->` and `<!-- quality-audit:end -->` with the new report.
3. If markers are absent, append the report and add markers around it.

This keeps the file safe to edit by hand outside the managed block.

## Output Format

```markdown
# Quality Score

<!-- quality-audit:start -->
_Last run: 2026-05-18T14:23:00Z — quality-audit v1_

## Summary

| Metric | Value |
|--------|-------|
| Score | 87 / 100 |
| Principles enabled | 6 |
| Principles violated | 3 |
| Critical findings | 1 |
| Major findings | 4 |
| Minor findings | 7 |

## Findings

### Critical

#### `no-yolo-data` — Don't traverse data structures without validation at the boundary

| # | Location | Match | Fix |
|---|----------|-------|-----|
| 1 | `src/app/api/orders/route.ts:42` | `JSON.parse(body)` | Wrap with Zod schema parse() — see src/schemas/. |

### Major

#### `prefer-shared-utils` — Hand-rolled helpers should be replaced with shared util packages

| # | Location | Match | Fix |
|---|----------|-------|-----|
| 1 | `src/lib/format.ts:12` | `function debounce(fn, ms)` | Use @workspace/utils/{debounce,...} instead. |

### Minor

_None._

## Trend

| Run | Score | Δ |
|-----|-------|---|
| 2026-05-18 | 87 | — |
| 2026-05-11 | 85 | +2 |
| 2026-05-04 | 82 | +3 |

_(Trend is only emitted when previous runs are present in the managed block.)_

<!-- quality-audit:end -->
```

## Run Mode

| Decision point | Interactive default | Headless default (`mode:headless`) |
|---|---|---|
| Missing `golden-principles.yaml` | Print stub guide, ask user if they want a starter copied in | Print stub guide and exit code 0 — never write files unprompted |
| `docs/` missing | Print to stdout, ask before creating | Print to stdout, exit 0 (never create `docs/`) |
| Confirm refactor PR | Ask | Never open PRs in headless mode — drift report only |

See `.claude/skills/_shared/blocks/mode-detection.md`.

## Loop / Schedule Integration

The skill is designed for unattended runs:

```text
/loop daily /quality-audit mode:headless
/schedule weekly /quality-audit mode:headless
```

When fired by a loop or schedule, the report is appended to `docs/QUALITY_SCORE.md`'s managed block and (if score drops by more than 5 points week-over-week) a follow-up task is added to `tasks/todo.md → ## Drift Alerts` — the human handles the refactor decision.

## Templates

A starter `golden-principles.yaml` ships at `.claude/skills/quality-audit/templates/golden-principles.example.yaml`. Copy it to the repo root and tailor for your stack.

## Notes

- This skill is **complementary** to `/code-quality-audit`. The latter checks generic code smells (long functions, swallowed errors). `/quality-audit` enforces *your* project's rules.
- If a principle becomes universally adopted (zero matches for 3+ runs), consider removing it — the YAML is a living document, not a graveyard.
- The detection layer is intentionally simple (grep/rg/command). For AST-level checks, write a custom `command:` that shells out to your project's existing linter (ESLint custom rule, Semgrep, etc.) — this skill is the orchestrator, not the analyzer.
