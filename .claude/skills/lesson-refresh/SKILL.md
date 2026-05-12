---
name: lesson-refresh
description: Periodic refresh of tasks/lessons/ — decide keep/update/promote/encode/archive per lesson based on relevance, recency, and whether the rule was already encoded elsewhere. Headless-capable.
user-invocable: true
---

# Lesson Refresh

## Kit Context

Before starting this skill, ensure you have completed session boot:
1. Read `CODEBASE_MAP.md` for project understanding
2. Read `CLAUDE.project.md` if it exists for project-specific rules
3. Read `tasks/lessons/_index.md` for accumulated corrections (Top Rules + index)

If any of these haven't been read in this session, read them now before proceeding.

## When to Use

Invoke with `/lesson-refresh` when:

- It's been ≥2 weeks since the last refresh (or never)
- The Top Rules index has grown beyond ~10 items
- You've shipped a major refactor that may have invalidated old lessons
- The session-boot context feels noisy (compaction kicking in too often)
- You want to promote a recurring lesson into a hook or CLAUDE.md rule

Not for:

- Adding new lessons — those come from user corrections during regular sessions
- Editing a single lesson — just open the file
- Project-wide cleanup — that's the broader "Spa Day" ritual in `agent_docs/skills.md`

## Scope Rules

- Operates only on files in `tasks/lessons/`
- Reads CLAUDE.md, CLAUDE.project.md, `.claude/hooks/`, and code surface as evidence — never modifies them
- Modifies lesson frontmatter (`status`, `updated`, `top_rule`) and `_index.md` Top Rules
- Moves archived lessons to `tasks/lessons/_archive/` (creates if missing)
- Never deletes lesson files — only sets `status: archived` and moves them

## Process

### Phase 1: Inventory

1. List all `tasks/lessons/*.md` files except `_index.md` and `_TEMPLATE.md`
2. For each, read frontmatter and body
3. Group by `status`: `active`, `archived`, `superseded`
4. Skip non-active lessons unless `--include-archived` is in arguments (rare; for audits)

### Phase 2: Evidence Gathering

For each active lesson, gather signals to inform the verdict:

| Signal | How to check | What it means |
|---|---|---|
| **Code surface unchanged** | Grep for the file/function the lesson names; does it still exist? | If the path is gone, the lesson may be moot |
| **Encoded as hook** | Scan `.claude/hooks/` for a rule matching the lesson's Rule line | Lesson may be redundant — agent can't violate the rule anymore |
| **Encoded in CLAUDE.md** | Search CLAUDE.md and CLAUDE.project.md for the rule | Lesson is encoded as a top-level rule; duplication |
| **Encoded in skill** | Search `.claude/skills/*/SKILL.md` for the same rule | Lesson covered by a discoverable skill |
| **Recurrence** | Search `tasks/lessons/` for sibling lessons with overlapping tags or text | Indicates a pattern worth promoting |
| **Age** | `created` field vs today | Stale lessons (>180 days, untouched) need a closer look |
| **Update count** | If `updated > created` by a wide margin | Lesson is still actively relevant |

Capture the signal set per lesson — do not act yet.

### Phase 3: Verdict

For each lesson, decide one of:

| Verdict | When | Action |
|---|---|---|
| **keep** | Still relevant, not encoded elsewhere, no signal that it's stale | No frontmatter change. Log in report. |
| **update** | Still relevant but message/rule needs sharpening, tags are wrong, or scope drifted | Edit the file's body and/or tags; set `updated: today` |
| **promote** | Recurring pattern (2+ sibling lessons), should appear in Top Rules | Set `top_rule: true`; add a one-line entry to `_index.md → ## Top Rules`; set `updated: today` |
| **encode** | Rule belongs in CLAUDE.md or a hook, not in the lesson archive | Propose the encoding (don't apply it without user approval). Set `status: superseded`. Add a `superseded_by: <path>` field in frontmatter pointing to the encoded location once approved. |
| **archive** | Code/dep gone, lesson moot, or duplicated elsewhere | Set `status: archived`; move the file to `tasks/lessons/_archive/`; remove from `_index.md` Top Rules if listed |

A lesson can match only one verdict per refresh. If two verdicts seem plausible (e.g., promote vs encode), prefer the one with the lower long-term token cost (encode > promote > keep > update > archive in terms of effort, but encode is best because it eliminates the lesson from session boot context).

### Phase 4: Apply (Interactive Mode)

Present the verdict batch to the user with a compact table:

```text
# Verdicts (N lessons reviewed)

| Lesson | Verdict | Why |
|---|---|---|
| 2026-04-30-tailwind-purge-cache.md | keep | Rule still applies; no encoding found |
| 2026-04-15-tsconfig-wrong-edit.md | encode | Pattern hookable; suggest .claude/hooks/protect-files.sh enhancement |
| 2026-03-10-async-state-trap.md | archive | Code path removed in commit abc1234 |
| 2026-02-20-cors-config.md | promote | Recurrence: 3 sibling lessons in tag "auth" |

Apply all? (y/n/select)
```

- **y** — apply every verdict
- **n** — abort, no changes
- **select** — drop into per-lesson confirmation; user can override each

After applying:

- Print a summary: counts per verdict, paths touched
- For `encode` verdicts, write the proposed encoding (hook diff or CLAUDE.md addition) into `tasks/todo.md > ## Lessons to Encode` so the user can review without losing context

### Phase 5: Apply (Headless Mode)

In headless mode, apply only **safe verdicts**:

- `keep` — no change
- `update` — apply only if confidence in the new tags/scope is high
- `archive` — apply only if the evidence is "code surface gone" (file path doesn't exist anymore)

Skip in headless mode:

- `promote` — promoting to Top Rules affects session boot for everyone; should be human-approved
- `encode` — proposes changes to CLAUDE.md or hooks; never silent

Save the verdicts that were skipped to `tasks/todo.md > ## Lesson Refresh Pending` so the user can review on next interactive session.

## Run Mode

This skill supports interactive (default) and headless modes — see the canonical contract in `.claude/skills/_shared/blocks/mode-detection.md`.

Headless detection: presence of `mode:headless` in arguments.

| Decision point | Interactive default | Headless default |
|---|---|---|
| **Apply all vs per-lesson** (Phase 4) | Show batch table, ask y/n/select | Apply only safe verdicts (Phase 5); queue the rest to `tasks/todo.md > ## Lesson Refresh Pending` |
| **Promote / encode** | Suggest, await approval | Skip — queue for human review |
| **Archive ambiguity** (lesson might still be relevant but old) | Ask | Keep, don't archive — bias toward retention in headless mode |
| **End** | Summary + "anything to revisit?" | Print summary table only |

## Output Format

```markdown
# Lesson Refresh Report — YYYY-MM-DD

**Reviewed:** N active lessons (M archived skipped)
**Verdicts applied:** K keep, U update, A archive, P promote, E encode

## Verdicts

| Lesson | Verdict | Action | Why |
|---|---|---|---|
| 2026-04-30-tailwind-purge-cache.md | keep | — | Still applies; no encoding found |
| 2026-04-15-tsconfig-wrong-edit.md | encode | queued in tasks/todo.md | Hookable; better as PreToolUse check |
| 2026-03-10-async-state-trap.md | archive | moved to _archive/ | Code path removed in commit abc1234 |

## Pending (Headless mode only)

These verdicts require human review — queued in `tasks/todo.md > ## Lesson Refresh Pending`:

- promote 2026-02-20-cors-config.md (recurrence: 3 sibling lessons)
- encode 2026-04-15-tsconfig-wrong-edit.md (hook candidate)

## Top Rules Diff

Before: N rules
After: M rules
Added: <list>
Removed: <list>
```

## Notes

- This skill is the **counterpart** to the kit's broader "Spa Day" cleanup ritual (see `agent_docs/skills.md`). Spa Day reviews CLAUDE.md, agent_docs, and skills; lesson-refresh focuses only on `tasks/lessons/`.
- The `encode` verdict never modifies CLAUDE.md or hooks silently — it always queues for human approval. This is a load-bearing invariant: encoded rules affect every session and must be human-vetted.
- The `_archive/` directory exists so archived lessons are still findable. They are excluded from `_index.md` and from on-demand reads, but discoverable via grep when investigating past incidents.
- Recommended cadence: run interactively every 2–4 weeks, or schedule a monthly headless run via `/loop` for the safe-verdict pass.
