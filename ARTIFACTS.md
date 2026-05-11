# ARTIFACTS.md — HTML Artifact Conventions

This file configures Claude to produce HTML artifacts — not markdown — for specs,
reports, PR explainers, design prototypes, and custom editors. When this file
exists, Claude follows the directory layout, naming, and patterns below.

Background: HTML carries far more signal than markdown (tables, CSS, SVG,
interactions, copy-as-prompt buttons) and is easier to share. With 1MB context
windows the extra tokens are noise. Markdown stays for files you edit by hand;
HTML takes over for files you only read.

---

## When HTML, when Markdown

Prefer **HTML** when one or more is true:

- Output will exceed ~100 lines (nobody reads a long markdown plan)
- The reader is someone other than you (sharing matters)
- The content benefits from layout, color, diagrams, side-by-side comparison
- Two-way interaction would help (sliders, knobs, "copy filled prompt" buttons)
- You want SVG flowcharts, not ASCII

Keep **markdown** for: `tasks/lessons.md`, `tasks/decisions.md`, `tasks/todo.md`,
`tasks/handoff-*.md`, ADRs, short notes — anything edited by hand or grepped.

---

## Directory

```text
artifacts/
  index.html            # Catalog — links to every artifact, kept current
  design-system.html    # Reference tokens (colors, type, spacing) — Claude mirrors this
  YYYY-MM-DD-<slug>.html  # Generated artifacts
```

---

## Conventions

- File names: date prefix + kebab-case slug → `2026-05-11-onboarding-spec.html`
- Every artifact mirrors `design-system.html`'s tokens (read it before generating)
- After creating an artifact, append a row to `index.html` with title, date, type, link
- **Standalone files** — embed CSS and JS inline. No external deps, no build step.
  An artifact must work when uploaded to S3 and opened by a colleague.
- Use inline SVG for diagrams, never ASCII

---

## Artifact Types

| Type          | Use for                                       | Key elements                                       |
|---------------|-----------------------------------------------|----------------------------------------------------|
| `spec`        | Implementation plan, design exploration       | Mockups, code snippets, tradeoff tables, N-up grid |
| `pr-explain`  | PR or code review writeup                     | Diff blocks, inline annotations, severity colors   |
| `report`      | Research, weekly recap, incident, deep-dive   | SVG diagrams, sections, summary box                |
| `design`      | Component prototype, animation tuning         | Sliders/knobs, live preview, copy-params button    |
| `editor`      | Throwaway data editor (triage, config, prompt)| Copy-as-JSON / Copy-as-prompt export button        |

---

## Two-way Interaction

When an artifact accepts input, it **must** include an export button so the
user's work returns to Claude Code as paste-able text:

| Artifact          | Required button                                |
|-------------------|------------------------------------------------|
| Editor (any kind) | `Copy as JSON` or `Copy as markdown`           |
| Design tuner      | `Copy params` (JSON blob of slider values)     |
| Prompt playground | `Copy filled prompt`                           |
| Triage/reorder    | `Copy as ordered list`                         |

Implementation: a single button → `navigator.clipboard.writeText(JSON.stringify(state))`.
No frameworks needed.

---

## Sharing

To share externally: upload the file to S3/CDN and send the link. Since every
artifact is standalone, no build pipeline is required.

For local viewing: `open artifacts/<file>.html` (macOS) opens it in the default
browser. Claude can run this for you.

---

## Anti-patterns

- **No generic `/html` skill** — let the prompt's intent drive the artifact type
- **No multi-file artifacts** — one file, one purpose, one open-in-browser action
- **No build tooling** — no React, no bundlers, no npm install
- **No reusing a 500-line boilerplate** — start from the prompt, not a template
- **No omitting `design-system.html`** — artifacts will drift in style otherwise
- **No mixing tasks/ into artifacts/** — tasks/ stays markdown (edited by hand)

---

## Index Maintenance

After creating any artifact, update `artifacts/index.html`:

1. Add a row to the catalog table: date | type | title | link | one-line purpose
2. Keep newest entries at the top
3. If an artifact is superseded by a newer version, mark the old row as
   superseded (don't delete — history matters)

If `index.html` is missing or stale, regenerate it from the `artifacts/*.html`
files on disk (read each file's `<title>` and `<meta name="artifact-*">` tags).

---

## Artifact Metadata

Every artifact should declare itself in `<head>`:

```html
<title>Onboarding Screen Spec — 2026-05-11</title>
<meta name="artifact-type" content="spec">
<meta name="artifact-date" content="2026-05-11">
<meta name="artifact-purpose" content="Compare 6 onboarding layouts">
```

This makes `index.html` regeneration trivial.
