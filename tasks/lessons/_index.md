# Lessons Learned — Index

This directory holds one lesson per file. Each lesson is a structured record of something that went wrong, why, and the rule to follow going forward.

- **Add a lesson:** copy `_TEMPLATE.md` to `tasks/lessons/<YYYY-MM-DD>-<slug>.md` and fill it in.
- **Surface critical rules:** set `top_rule: true` in the frontmatter, then add a one-line entry under `## Top Rules` below. Top Rules are loaded at every session start.
- **Refresh:** run `/lesson-refresh` periodically to keep/update/archive lessons that have drifted (see `agent_docs/workflow.md`).

---

## Top Rules

<!-- Promote your most important, recurring lessons here (max 10 lines).        -->
<!-- This section is loaded at every session start for token efficiency.        -->
<!-- Individual lesson files are loaded on-demand when relevant.                -->

<!-- Format: - **[Rule]** ([slug]) — one line that's actionable on its own -->

---

## All Lessons

<!-- Newest first. Auto-grows as you add lessons. Each entry: date, title, slug. -->

<!-- - 2026-05-12 — Edited wrong tsconfig — [2026-05-12-tsconfig-wrong-edit](2026-05-12-tsconfig-wrong-edit.md) -->

---

## Format Reference

Each lesson file uses YAML frontmatter + the structure in `_TEMPLATE.md`:

| Field | Purpose |
|---|---|
| `title` | One-line summary, shown in index |
| `created` / `updated` | ISO dates (YYYY-MM-DD) |
| `tags` | Free-form list for grep/filter |
| `problem_type` | `tool` \| `process` \| `bug` \| `knowledge` |
| `source` | `correction` (user fixed agent) \| `review` (caught in code review) \| `discovery` (agent self-noticed) |
| `confidence` | `high` \| `medium` \| `low` — how sure are you the rule generalizes |
| `top_rule` | `true` if it should surface in this index's Top Rules |
| `status` | `active` \| `archived` \| `superseded` |
| `related` | Slugs of related lessons |

Body sections: **Issue** → **Root Cause** → **Rule** → optional **Verification** → optional **References**.

---

## Lifecycle

| Stage | Trigger | Action |
|---|---|---|
| Capture | User correction, review finding, or own discovery | Copy `_TEMPLATE.md`, fill in, save as `<YYYY-MM-DD>-<slug>.md` |
| Promote | A lesson repeats or proves critical | Set `top_rule: true`, add one-line entry above |
| Encode | A lesson becomes a hook, lint rule, or CLAUDE.md rule | Set `status: superseded`, note where it lives now in References |
| Archive | A lesson no longer applies (code changed, dep removed) | Set `status: archived` |
| Refresh | Periodic (`/lesson-refresh` skill) | Re-evaluate all `active` lessons |

The goal is a **small** set of `top_rule: true` lessons that the agent sees at boot, with the rest available on-demand.
