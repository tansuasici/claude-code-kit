# docs/

Structured knowledge base for this project. Read on-demand instead of loading everything at session start.

## Layout

| Path | Purpose |
|---|---|
| `ARCHITECTURE.md` | System architecture: services, boundaries, data flow |
| `DESIGN.md` | UI/UX design system (project-specific; supplements the kit's `DESIGN.md` template) |
| `PLANS.md` | Current and active engineering plans — pointer to `exec-plans/active/` |
| `QUALITY_SCORE.md` | Rolling code-quality score (auto-updated by `/quality-audit`) |
| `RELIABILITY.md` | SLOs, incident log, on-call runbooks |
| `design-docs/` | Stable design opinions — read when making decisions that touch architecture |
| `exec-plans/active/` | Current initiatives (one folder per major plan) |
| `exec-plans/completed/` | Shipped plans (archive) |
| `exec-plans/tech-debt-tracker.md` | Standing list of known tech debt |
| `generated/` | Auto-generated artefacts (db-schema, openapi, etc.) — consider gitignoring |
| `product-specs/` | Product/feature specs from product team |
| `references/*-llms.txt` | 3rd-party library references (populated by `/references-sync`) |

## How to use

- **Add a new doc** to the relevant subfolder. Each subfolder has an `index.md` — append a one-line entry.
- **Update an existing doc** when the underlying behavior changes. Treat doc-staleness as a bug.
- **Auto-generated docs** in `generated/` are not edited by hand — regenerate them from source.

## How agents use this

`CLAUDE.md` references this folder via the `## Harness Docs` section. The agent reads only the relevant doc on-demand — it does not load all of `docs/` at session start.
