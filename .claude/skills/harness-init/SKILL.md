---
name: harness-init
description: Scaffold an OpenAI-style `docs/` harness structure (design-docs/, exec-plans/, references/, ARCHITECTURE.md, DESIGN.md, PLANS.md, QUALITY_SCORE.md, RELIABILITY.md). Use when adopting the harness pattern: a thin CLAUDE.md that points at a structured docs/ tree instead of one growing CLAUDE.md.
user-invocable: true
---

# Harness Init

## Core Rule

Scaffold the `docs/` structure additively — never overwrite an existing file. Every directory and file is created only if missing.

## Kit Context

Before starting this skill, ensure you have completed session boot:

1. Read `CODEBASE_MAP.md` for project understanding
2. Read `CLAUDE.project.md` if it exists for project-specific rules
3. Read `tasks/lessons/_index.md` for accumulated corrections

If any of these haven't been read in this session, read them now before proceeding.

## When to Use

Invoke with `/harness-init` when:

- A project has outgrown a single CLAUDE.md and you want to switch to a `docs/` harness layout (per [OpenAI's harness engineering pattern](https://openai.com/index/harness-engineering/))
- You're starting a new project and want the harness scaffold from day one
- You're migrating from a `.claude/`-only setup and want a more durable knowledge base alongside the agent rules

Not for:

- Fresh kit installs where you haven't decided yet — just run the default `install.sh`; the harness pattern is opt-in
- Projects where `docs/` already exists with a different convention — manually merge instead of running this skill

## Scope Rules

- **Idempotent**: every file/directory is created only if missing. Existing content is never touched.
- Operates only on `docs/` and its children, plus an optional one-line section addition to `CLAUDE.md` (only if the project's CLAUDE.md doesn't already reference `docs/`)
- Never modifies files under `tasks/`, `agent_docs/`, or `.claude/`

## Process

### Phase 1: Inventory

1. Check whether `docs/` already exists at the project root
2. Check whether `CLAUDE.md` references `docs/` (grep for "Harness Docs" or "docs/ARCHITECTURE.md")
3. List which of the target files already exist (so the report is honest about what was new vs. preserved)

### Phase 2: Scaffold

Create the following structure. **For every entry, check if it exists first; skip if present.** Use the seed content from `.claude/skills/harness-init/templates/` when available, otherwise inline the minimal stub shown below.

```text
docs/
├── README.md                  # Top-level index — what's in docs/ and how to navigate it
├── ARCHITECTURE.md            # System architecture: services, boundaries, data flow
├── DESIGN.md                  # UI/UX design tokens, principles, links to design system
├── PLANS.md                   # Current product/eng plans — pointer to exec-plans/active/
├── QUALITY_SCORE.md           # Rolling code-quality score (auto-updated by /quality-audit when CLA-13 lands)
├── RELIABILITY.md             # SLOs, incidents, on-call runbooks
├── design-docs/
│   ├── index.md               # List of design docs in this folder
│   └── core-beliefs.md        # Stable opinions about the system (rarely change)
├── exec-plans/
│   ├── active/                # In-flight plans, one folder or file per initiative
│   │   └── .gitkeep
│   ├── completed/             # Shipped plans (archive)
│   │   └── .gitkeep
│   └── tech-debt-tracker.md   # Standing list of known debt
├── generated/                 # Auto-generated docs (db-schema, openapi, etc.). Add to .gitignore if desired.
│   └── .gitkeep
├── product-specs/
│   └── index.md               # Index of product specs
└── references/                # 3rd-party library refs in *-llms.txt format (see /references-sync skill, CLA-14)
    └── .gitkeep
```

### Phase 3: CLAUDE.md pointer

If `CLAUDE.md` doesn't already contain a "Harness Docs" section, propose adding one near the bottom (after `## HTML Artifacts` if that section exists, otherwise after `## Knowledge Wiki` or `## Design System`):

```markdown
## Harness Docs

If `docs/ARCHITECTURE.md` exists, the project uses the harness pattern: CLAUDE.md is a thin index and the structured knowledge lives in `docs/`. Read the relevant doc on-demand:

- `docs/ARCHITECTURE.md` — system architecture, boundaries, data flow
- `docs/DESIGN.md` — UI/UX design system (this overlay supplements the kit's top-level DESIGN.md template)
- `docs/PLANS.md` + `docs/exec-plans/active/` — current and active initiatives
- `docs/QUALITY_SCORE.md` — rolling code-quality status
- `docs/RELIABILITY.md` — SLOs, incidents, on-call
- `docs/design-docs/core-beliefs.md` — stable opinions about the system
- `docs/references/*-llms.txt` — 3rd-party library references (see `/references-sync`)
```

**Apply this addition only after explicit user confirmation.** Editing CLAUDE.md is a kit-managed change; the agent must not silently rewrite it.

### Phase 4: Report

Print a compact summary:

```text
Harness scaffold report
=======================
Created   (12)  docs/, docs/ARCHITECTURE.md, docs/DESIGN.md, ...
Preserved (2)   docs/PLANS.md (existed), docs/README.md (existed)
CLAUDE.md       proposed addition (pending user confirmation)

Next:
  - Fill in docs/ARCHITECTURE.md with your system's actual architecture (the template is just a skeleton)
  - Move any pre-existing planning docs into docs/exec-plans/active/
  - Run /references-sync (when CLA-14 lands) to populate docs/references/
```

## Run Mode

This skill supports interactive (default) and headless modes — see `.claude/skills/_shared/blocks/mode-detection.md`.

Headless detection: presence of `mode:headless` in arguments.

| Decision point | Interactive | Headless |
|---|---|---|
| **CLAUDE.md modification** | Propose, ask y/n | Skip — the addition is queued in `tasks/todo.md > ## Harness CLAUDE.md addition` for human review |
| **Conflict on a file** | Ask whether to skip or merge | Always skip (idempotent contract) |
| **Output** | Full summary + next-steps callout | Compact report only |

## Notes

- The scaffold is intentionally opinionated — it mirrors OpenAI's published harness layout (ARCHITECTURE/DESIGN/PLANS/QUALITY_SCORE/RELIABILITY + design-docs/exec-plans/references). If your project's conventions differ, treat this as a starting point and rename/restructure post-scaffold.
- `docs/generated/` is intended for auto-produced artefacts (db-schema dumps, OpenAPI specs, etc.). If you treat it as throwaway, add `docs/generated/` to your project's `.gitignore`. The skill does NOT touch `.gitignore`.
- `docs/references/*-llms.txt` is populated by the `/references-sync` skill (CLA-14). Until that ships, the directory stays empty (only `.gitkeep`).
- `docs/QUALITY_SCORE.md` is updated by the `/quality-audit` skill (CLA-13). Until that ships, it stays as the seed template.
