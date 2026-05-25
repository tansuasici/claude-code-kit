---
name: constitution
description: Author or extend the project's golden-principles.yaml — interactively for new repos, or by inferring + confirming candidates from existing code. Pairs with /quality-audit which reads the file.
user-invocable: true
---

# Constitution

## Core Rule

Never write a principle the user hasn't seen. Each entry in `golden-principles.yaml` lands only after the user accepts the proposed `rule`, `severity`, and `detect` together — silent insertion (even of "obvious" rules) breaks the audit contract downstream.

## Kit Context

Before starting this skill, ensure you have completed session boot:

1. Read `CODEBASE_MAP.md` for project understanding
2. Read `CLAUDE.project.md` if it exists for project-specific rules
3. Read `tasks/lessons/_index.md` for accumulated corrections (Top Rules + index)

If any of these haven't been read in this session, read them now before proceeding.

## When to Use

Invoke with `/constitution` when:

- A new project doesn't have `golden-principles.yaml` yet and you want one
- An existing project has a sparse principles file and you want to fill in gaps from category recommendations
- You ran `/quality-audit` and got the "no principles file found" stub — this skill is what the stub points at
- Onboarding to a project and want to capture its de-facto rules as explicit, machine-checkable ones

Not for:

- Editing arbitrary principles (use a text editor — this skill is for *adding* and *bootstrapping*)
- Running the principles against the codebase — that's `/quality-audit`'s job
- Generating coding standards prose — `golden-principles.yaml` is for *deterministic, grep-checkable* rules; verbose conventions belong in `agent_docs/conventions.md` or `docs/design-docs/core-beliefs.md`

## Default Behavior

When the user asks to "set up principles", "create a constitution", "bootstrap quality rules", or invokes `/constitution`, run the full Process below — read the codebase, propose principles by category, walk the user through accept/reject for each, and write the file. Default mode is **interactive**; the dialogue is the value.

This skill writes a single file (`.claude/golden-principles.yaml` by default; repo-root `golden-principles.yaml` if explicitly requested). It does not modify code, settings, or any other file. CLAUDE.md is touched **only** when the file is newly created and a `## Quality Principles` pointer section is missing — and only with explicit user approval.

## Inputs

The skill detects:

- Whether `golden-principles.yaml` already exists (root → `.claude/`) — controls merge vs. fresh-create behaviour
- The primary language (`package.json` → JS/TS, `pyproject.toml`/`requirements.txt` → Python, `go.mod` → Go, `Cargo.toml` → Rust) — selects category candidates from the library
- The presence of common architecture signals (Prisma/Drizzle imports, FastAPI/Django routes, monorepo workspace layout, test framework choice) — informs which categories to surface

No CLI flags are required. Optional positional argument: a path override (`/constitution path:./golden-principles.yaml`).

## Schema

This skill writes the same schema that `/quality-audit` reads. The canonical reference lives at `.claude/skills/quality-audit/templates/golden-principles.example.yaml`. Every principle must include:

| Field | Type | Notes |
|---|---|---|
| `id` | kebab-case string | Unique within the file |
| `rule` | one-line string | Human-readable, what's enforced |
| `severity` | `critical` / `major` / `minor` | Weights: 5 / 2 / 1 |
| `detect` | object | `type: grep \| rg \| command`, plus `pattern` or `command`, optional `paths` |
| `fix_hint` | one-line string | What the developer should do |
| `tags` | string list | Optional, free-form |
| `paths` | glob list | Optional, scopes detection |
| `enabled` | boolean | Optional, default `true` |

If the schema in `/quality-audit`'s template ever changes, this skill must follow — ADR-014 names that template as the source of truth.

## Process

### Phase 1: Inventory (first-pass leads)

This pass produces **candidates**, not findings. Read the repo to decide which principle categories to surface; do not propose individual principles yet.

1. Detect existing `golden-principles.yaml` (root first, then `.claude/`). Load and parse if present — `ids` already used go on the "already covered" list.
2. Detect the primary language from package manifests at repo root. Multi-language repos pick the most prominent (most dependencies / largest source tree).
3. Scan for architecture signals (limit one `rg` per signal, capped at 5 results each):
   - DB clients (`prisma`, `drizzle`, `sequelize`, `sqlalchemy`, `gorm`, etc.)
   - HTTP framework signals (`next/server`, `express`, `fastapi`, `flask`, `gin`, etc.)
   - Test framework (`vitest`, `jest`, `pytest`, `go test`, `cargo test`)
   - Type-safety markers (TS strict mode, mypy, pylint, golangci-lint configs)
4. From the principles library (`templates/principles-library.yaml`), select categories where the language matches AND at least one architecture signal applies AND no existing principle in the file already covers that category.
5. Emit a short inventory block listing: detected language, signals found, categories proposed.

### Phase 2: Intake (interactive only)

Skipped in headless mode — see Run Mode.

If the file is **brand-new**, ask the 5 intake questions from `templates/intake-questions.md`. Answers shape which categories are emphasised (e.g. "test-first" answer → testing category gets a higher proposal severity).

If the file already exists and Phase 1 found 0 uncovered categories, exit with "Already covered — no new categories to propose. Edit the existing file directly to refine rules." Do not invent rules to look busy.

### Phase 3: Propose & Confirm

For each selected category, propose **2–3 candidate principles** from the library, lightly adapted to the detected stack. Walk the user through each one individually:

1. Show the proposed `id`, `rule`, `severity`, `detect.pattern`, `fix_hint`, and the file paths the rule would scan.
2. Ask: `accept | edit | skip`.
3. If `edit`, walk through which fields to change (severity, pattern, paths, fix_hint). Keep editing until the user says `accept`.
4. If `skip`, log the skip in the run summary and move on. Skipped principles are not written.
5. After all proposals for a category are handled, ask: "Add a custom principle for this category?" If yes, walk through the 6 fields from scratch.

Never write to disk until all proposals across all categories have been confirmed (or skipped). The user must see the full set before it lands.

### Phase 4: Write

1. If the file is new:
   - Default path: `.claude/golden-principles.yaml`. If the user passed `path:`, honour it.
   - Write the file with a 4-line header (kit version, generated date, schema reference, edit-by-hand note).
2. If the file exists:
   - Merge: append accepted principles below the last existing entry. Preserve all comments, blank lines, and ordering of existing content.
   - If a proposed `id` collides with an existing one (shouldn't happen if Phase 1 was honest, but guard anyway), prepend `<existing-id>-v2` and surface the rename in the report.
3. If `docs/QUALITY_SCORE.md` exists, leave it alone — `/quality-audit` rewrites the managed block on its next run.
4. If `CLAUDE.md` doesn't have a `## Quality Principles` section and the file was newly created, propose adding the pointer. Apply only on explicit user confirmation.

### Phase 5: Report

Emit the Output Format report below. Suggest running `/quality-audit` next so the user sees the first drift measurement against the new principles.

## Output Format

```markdown
# Constitution run report

_Run: 2026-05-18T22:30:00Z — constitution v1_

## Summary

| Metric | Value |
|--------|-------|
| File | `.claude/golden-principles.yaml` (new) |
| Detected language | TypeScript (Next.js) |
| Architecture signals | Prisma, Next.js App Router, Vitest |
| Categories proposed | 4 (type-safety, shared-utils, architecture, testing) |
| Principles accepted | 6 |
| Principles edited | 2 |
| Principles skipped | 3 |
| Custom principles added | 1 |
| Existing principles preserved | 0 |

## Accepted

| id | severity | category |
|---|---|---|
| no-yolo-json-parse | critical | type-safety |
| no-any-in-public-api | major | type-safety |
| prefer-shared-utils | major | shared-utils |
| no-direct-db-in-route | critical | architecture |
| no-untyped-fetch | major | type-safety |
| route-handlers-export-method | major | architecture |

## Skipped (per user request)

- `no-default-exports` (naming) — user prefers default exports
- `no-cross-feature-imports` (architecture) — codebase already enforces this via tsconfig paths
- `prefer-async-await` (style) — codebase mixes promises and async/await intentionally

## CLAUDE.md

Added `## Quality Principles` pointer section (user approved).

## Next

- Run `/quality-audit` to measure current drift against the new principles
- Edit `.claude/golden-principles.yaml` by hand to refine `detect` patterns once you see the first drift report
- Schedule `/loop weekly /quality-audit` once the principles stabilise
```

## Run Mode

| Decision point | Interactive default | Headless default (`mode:headless`) |
|---|---|---|
| File already exists, 0 uncovered categories | Print message, exit 0 | Print message, exit 0 |
| Per-principle accept/edit/skip | Ask for each | Auto-accept everything the library proposes for matched categories — no editing, no custom additions |
| "Add a custom principle for this category?" | Ask | Always skip |
| Brand-new file: 5 intake questions | Ask all 5 | Skip the questionnaire; use library defaults for the detected language |
| `CLAUDE.md` pointer section | Ask before writing | Skip the pointer addition; never touch CLAUDE.md in headless |
| Conflicting `id` on merge | Ask the user how to rename | Auto-rename to `<id>-v2`, log the rename |

See `.claude/skills/_shared/blocks/mode-detection.md`.

Headless mode is for **bootstrapping unattended** — e.g. a CI smoke test that wants a baseline file. The user is expected to review the result and edit before it sees real use.

## Templates

- `templates/principles-library.yaml` — category-keyed starter principles per language. The skill draws candidates from here; users extend with `.claude/principles-library.local.yaml` (gitignored) for org-specific additions.
- `templates/intake-questions.md` — the 5-question script for new-file intake. Each question maps to a category emphasis (which proposed severities get bumped or which categories get proposed first).

## Notes

- **Pairs with `/quality-audit`.** That skill reads the file this skill writes. Schema source of truth: `.claude/skills/quality-audit/templates/golden-principles.example.yaml` (referenced from ADR-011 and ADR-014).
- **Pairs with `/harness-init`.** `/harness-init` scaffolds the `docs/` tree (including the placeholder `docs/QUALITY_SCORE.md`); `/constitution` populates the rule set that `/quality-audit` will use to update that score on the next run.
- **Additive, never destructive.** Re-running on an existing file only proposes new categories. It never edits, removes, or reorders existing entries. Refining is a hand-edit job — this skill is for *adding*.
- **Library, not invention.** Proposed principles come from `templates/principles-library.yaml` and are lightly adapted. The skill does not synthesise novel `detect` patterns from the codebase; it pattern-matches against known categories. Reason: a brittle `detect` rule that fires on the wrong lines is worse than no rule.
- **Default file location is `.claude/`.** `/quality-audit` resolves root first, then `.claude/`. Putting the file in `.claude/` keeps the project root clean and signals that the rule set is part of the kit-managed surface. Users who prefer the root can pass `path:./golden-principles.yaml`.
