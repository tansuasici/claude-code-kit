---
name: note
description: Append a timestamped mid-session note to the session journal — finding/decision/summary tags for across-compaction memory. The journal is folded to handoff at session end by .claude/hooks/journal-fold.sh.
user-invocable: true
---

# Note

## Core Rule

Append `<ISO8601> [<tag>] <text>` to `.hook-state/session-journal.md`. Tag MUST be one of `finding`, `decision`, `summary`. The journal is transient (gitignored, same lifetime as other `.hook-state/*`) but durable across `/compact` within the same session.

## Process

```bash
scripts/note.sh <tag> <text>
```

The helper validates the tag, ensures the `.hook-state/` dir + `.gitignore` exist, appends a timestamped line, and prints a confirmation with the new entry count.

## Tags

Three only — pick exactly one per note. Don't invent new tags; extend the vocabulary only after a recurring pattern shows up across multiple sessions.

| Tag | Use for |
|---|---|
| `finding` | A non-obvious technical observation worth carrying past `/compact` (e.g. "qdrant treats null filter as ANY") |
| `decision` | A choice made mid-session that may later become an ADR in `tasks/decisions.md` (e.g. "going with Drizzle over Prisma") |
| `summary` | A "what state are we in right now" checkpoint, useful before a tool-heavy block (e.g. "auth wired, billing endpoints next") |

The lifecycle differs by tag:

- `finding` / `decision` → folded into `tasks/handoff-<session-id>.md` at session end (durable)
- `summary` → discarded at session end if no findings/decisions are present (transient breadcrumb)

## When to Use

When you discover something that:

- The session needs to remember after `/compact` (compaction wipes mid-session findings from the conversation)
- Doesn't yet warrant a lesson (correction-driven) or ADR (architectural decision)
- Is too small to commit as a code change

Examples:

```bash
scripts/note.sh finding "qdrant client treats null filter as ANY, not none"
scripts/note.sh decision "going with Drizzle over Prisma — see ADR-014 draft"
scripts/note.sh summary "auth wired, billing endpoints next"
```

Not for:

- Code — use `Edit` / `Write`
- Across-session memory — use `tasks/lessons/` (correction-driven) or `tasks/decisions.md` (ADRs)
- Long-form content — the journal is one line per entry; for paragraphs use a real file
- Replacing the lesson flow — lessons come from user corrections, not agent self-discovery

## Lifecycle

```text
mid-session (you call /note)
  └─► .hook-state/session-journal.md (append)

/compact happens
  └─► CLAUDE.md → After Compaction tells you to re-read the journal

session ends
  └─► .claude/hooks/journal-fold.sh:
        ├─ findings or decisions present? → fold to tasks/handoff-<session-id>.md
        ├─ only summaries? → discard
        └─ always: rm .hook-state/session-journal.md
```

The journal never persists across sessions; durable content lands in handoff.

## Output Format

`scripts/note.sh` prints to stdout:

```text
Noted: 2026-05-22T19:30:11Z [finding] qdrant client treats null filter as ANY
→ .hook-state/session-journal.md (3 entries)
```

The appended line in the journal file is exactly the first stdout line minus the `Noted:` prefix.

## Rules

Always:

- Use `scripts/note.sh` — never write to the journal file directly (the helper guarantees timestamp format and tag validation)
- Pick a tag explicitly — let the agent's classifier earn its place; never `/note auto`
- Keep notes one-line — multiple notes if you need to record multiple things

Never:

- Use this skill for content that should be committed (code, ADRs, lessons)
- Read other agents' notes (this is a per-session, local journal — sharing happens via handoff)
- Bypass the helper script — direct `echo >>` skips timestamp + gitignore guards

## Smoke Test

```bash
# 1. Write a finding
./scripts/note.sh finding "test observation"
cat .hook-state/session-journal.md
# Expect: one ISO8601 line with [finding] test observation

# 2. Add a decision
./scripts/note.sh decision "test choice"
wc -l .hook-state/session-journal.md
# Expect: 2

# 3. Invalid tag is rejected
./scripts/note.sh nonsense "ignored"
# Expect: exit 2, stderr: "invalid tag 'nonsense'"

# 4. Missing args rejected
./scripts/note.sh finding
# Expect: exit 2, usage message
```

End-to-end roundtrip (skill write → fold at session end) is covered in `bench/scenarios/s18-note-journal-fold.json`.

## Pairs With

- **CLAUDE.md → After Compaction** — instructs re-read of the journal post-compaction
- **`.claude/hooks/journal-fold.sh`** — SessionEnd companion that consumes the journal
- **`tasks/handoff-*.md`** — auto-populated by `journal-fold.sh` from this skill's output
- **`tasks/lessons/`** — across-session memory (different time-scale; a `finding` may later turn into a lesson if it recurs)

## Out of Scope

- Tag vocabulary beyond `finding`/`decision`/`summary` — extend later if patterns emerge
- LLM-classified or auto-tagged notes — agent picks the tag explicitly
- Auto-promotion of `finding` entries to `tasks/lessons/` — that's a separate, deliberate lifecycle (`/lesson-refresh` plus user judgment)
- Cross-session journal merging — every session starts with an empty journal
- Reading journal contents during write (this skill writes only; reading happens in `## After Compaction`)
