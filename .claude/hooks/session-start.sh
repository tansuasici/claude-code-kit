#!/usr/bin/env bash
#
# session-start.sh — SessionStart hook
#
# Runs on every SessionStart source: "startup" (new), "resume", "clear", and
# "compact" (fired mid-session right after a context compaction). It does two
# related jobs depending on the source:
#
#   • startup / resume / clear — the beginning of a working session: reset the
#     transient per-session state and inject minimal Tier 1 context (project map
#     pointers, top rules, active task, branch + dirty-tree status). Replaces the
#     CLAUDE.md rule "read Tier 1 files at session start", which depends on the
#     agent voluntarily following it.
#
#   • compact — does NOT reset session state (counters, the session clock, and
#     the handoff scratchpad belong to the whole session and must survive a
#     mid-session compaction) and instead re-injects the working anchors the
#     compaction summary may have blurred: active task, top rules, any active
#     contract, and the session journal. This is the deterministic half of
#     CLAUDE.md's "After Compaction" rule. SessionStart(source="compact") is
#     Claude Code's purpose-built channel for it — unlike PreCompact/PostCompact,
#     its additionalContext actually reaches the model.
#
# Output: JSON with `additionalContext` (Claude Code injects it before the next
# turn). Reads stdin but requires no payload. Always exits 0.
#

set -euo pipefail

INPUT=$(cat)

HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
source "$HOOK_LIB/json-parse.sh"
source "$HOOK_LIB/state-counter.sh"

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.hook-state"
mkdir -p "$STATE_DIR" 2>/dev/null || true
[ -f "$STATE_DIR/.gitignore" ] || printf '*\n!.gitignore\n' >"$STATE_DIR/.gitignore" 2>/dev/null || true

# "startup" | "resume" | "clear" | "compact". A compact-source start fires
# mid-session after a compaction; every other source marks a fresh session.
SOURCE=$(parse_json_field "source" 2>/dev/null || true)

if [ "$SOURCE" != "compact" ]; then
  # New session (startup/resume/clear) — reset transient per-session state.
  # Deliberately skipped on "compact": resetting counters or the session clock
  # mid-session would corrupt the session's metrics and clear the stop-gate
  # verdict (stop-gate.sh would stop blocking a still-failing gate until the
  # next qualifying edit).

  # Reset transient session counters from any prior session. session-end.sh has
  # already consumed them (or, if the prior session crashed, the next aggregator
  # would otherwise double-count). New session starts at zero.
  reset_state "$STATE_DIR/hook-firings.json"
  reset_state "$STATE_DIR/quality-gate-history.json"
  reset_state "$STATE_DIR/bash-budget.json"
  reset_state "$STATE_DIR/read-budget.json"
  # Also clear the verdict stop-gate.sh reads. quality-gate.sh only overwrites it
  # on a qualifying edit, so a "failed" verdict from a prior session would
  # otherwise persist and block completion of a new session that makes no code
  # edit (e.g. a Markdown-only or Q&A session). New session starts with no verdict.
  reset_state "$STATE_DIR/last_quality_gate.json"
  # Verification ledger is per-session evidence — start each session clean.
  reset_state "$STATE_DIR/verification-ledger.json"
  # glob-guidance one-shot markers (plain text, one pattern-id per line) — clear
  # so cross-cutting path nudges fire once per fresh session, never nag.
  rm -f "$STATE_DIR/glob-guidance-fired" 2>/dev/null || true

  # Clear the inter-agent handoff scratchpad (CLA-37). It is per-session: each
  # sub-agent overwrites it with a <=5-line summary on exit, and journal-fold.sh
  # folds it into the session handoff at SessionEnd. Start every session empty.
  : > "$STATE_DIR/agent-handoff.md" 2>/dev/null || true

  # Write session metadata. session-end.sh reads it to compute
  # session_duration_seconds and propagate session_id into the scorecard.
  SESSION_ID=$(parse_json_field "session_id" 2>/dev/null || true)
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  NOW_EPOCH=$(date +%s)
  if command -v python3 &>/dev/null; then
    python3 - "$STATE_DIR/session-meta.json" "${SESSION_ID:-}" "$NOW" "$NOW_EPOCH" <<'PY' 2>/dev/null || true
import json, os, sys
f, sid, now_iso, now_epoch = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
d = {"session_id": sid, "started_at": now_iso, "started_at_epoch": now_epoch}
tmp = f + ".tmp"
with open(tmp, "w") as fh:
    json.dump(d, fh, indent=2)
os.replace(tmp, f)
PY
  fi
fi

CONTEXT=""

append() { CONTEXT="${CONTEXT}${1}"; }
append_line() { CONTEXT="${CONTEXT}${1}"$'\n'; }

if [ "$SOURCE" = "compact" ]; then
  append_line "[Context restored after compaction by session-start.sh]"
  append_line "The conversation was just compacted; earlier detail may be lost. Re-establish context before continuing (CLAUDE.md → After Compaction)."
else
  append_line "[Auto-injected by session-start.sh]"
fi
append_line ""

# 1. Project map pointer (don't dump the whole file — just confirm presence)
if [ -f "$ROOT/CODEBASE_MAP.md" ]; then
  append_line "Project map: CODEBASE_MAP.md is present. Read it before non-trivial work."
fi
if [ -f "$ROOT/CLAUDE.project.md" ]; then
  append_line "Project overlay: CLAUDE.project.md present — project rules override kit defaults."
fi

# 2. Top rules from lessons index (first lines after '## Top Rules', max 8 lines)
LESSONS_INDEX="$ROOT/tasks/lessons/_index.md"
if [ -f "$LESSONS_INDEX" ]; then
  TOP_RULES=$(awk '/^## Top Rules/{f=1;next} f && /^## /{exit} f && NF{print; n++; if(n>=8) exit}' "$LESSONS_INDEX" 2>/dev/null || true)
  if [ -n "$TOP_RULES" ]; then
    append_line ""
    append_line "Top rules from prior lessons:"
    append_line "$TOP_RULES"
  fi
fi

# 3. Active task from todo.md (first ### header under '## In Progress')
TODO="$ROOT/tasks/todo.md"
if [ -f "$TODO" ]; then
  ACTIVE=$(awk '/^## In Progress/{f=1;next} f && /^## /{exit} f && /^### /{print; exit}' "$TODO" 2>/dev/null || true)
  if [ -n "$ACTIVE" ]; then
    append_line ""
    append_line "Active task in tasks/todo.md → $ACTIVE"
  fi
fi

# 3b. Lesson-candidate nudge — the PRIOR session hit learnable signals but added
#     no lesson (one-shot breadcrumb from session-end.sh). Surface once on a fresh
#     session, then consume. Not on compact (same session continuing).
if [ "$SOURCE" != "compact" ]; then
  CAND="$STATE_DIR/lesson-candidate.json"
  if [ -f "$CAND" ]; then
    if command -v python3 &>/dev/null; then
      CAND_MSG=$(python3 - "$CAND" <<'PY' 2>/dev/null || true
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(f"Last session: {d.get('gate_failures', 0)} quality-gate failure(s), {d.get('journal_findings', 0)} journaled finding(s), but no lesson added.")
except Exception:
    print("")
PY
)
      if [ -n "$CAND_MSG" ]; then
        append_line ""
        append_line "$CAND_MSG Consider capturing a lesson (tasks/lessons/ or /skill-extractor)."
      fi
    fi
    rm -f "$CAND" 2>/dev/null || true
  fi
fi

# 4. Compaction restore — re-inject the extra anchors the summary may have
#    dropped: full-plan/edited-files nudge, any active contract, and the
#    in-session journal. Fresh sessions don't need these (todo/lessons above are
#    the boot context; the journal is empty at startup).
if [ "$SOURCE" = "compact" ]; then
  if [ -f "$TODO" ]; then
    append_line ""
    append_line "Re-read tasks/todo.md for the full plan before continuing."
  fi
  # The specific files you were editing = the uncommitted working set (unchanged
  # by compaction). List them so "re-read what you were editing" is concrete, not
  # a vague reminder. Deletions excluded; .hook-state noise filtered.
  if command -v git &>/dev/null && [ -d "$ROOT/.git" ]; then
    EDITED=$(git -C "$ROOT" status --porcelain 2>/dev/null \
      | grep -vE '^( D|D )' | awk '{print $NF}' \
      | grep -vE '^\.hook-state/' | head -20 | sed 's/^/- /' || true)
    if [ -n "$EDITED" ]; then
      append_line ""
      append_line "Files you were editing (uncommitted — re-read these to continue):"
      append_line "$EDITED"
    fi
  fi
  if compgen -G "$ROOT/tasks/*_CONTRACT.md" >/dev/null 2>&1; then
    append_line ""
    append_line "Active contract(s) — re-read before continuing:"
    for c in "$ROOT"/tasks/*_CONTRACT.md; do
      append_line "- tasks/$(basename "$c")"
    done
  fi
  JOURNAL="$STATE_DIR/session-journal.md"
  if [ -f "$JOURNAL" ] && [ -s "$JOURNAL" ]; then
    JOURNAL_TAIL=$(tail -n 60 "$JOURNAL" 2>/dev/null || true)
    if [ -n "$JOURNAL_TAIL" ]; then
      append_line ""
      append_line "Session journal (.hook-state/session-journal.md) — pre-compaction notes:"
      append_line "$JOURNAL_TAIL"
    fi
  fi
  append_line ""
  append_line "Do NOT resume coding until context is re-established."
fi

# 5. Branch + working-tree status — boot orientation only. Skipped on compact:
#    the branch/tree haven't changed since the session began, and the agent
#    already reconciled them at startup.
if [ "$SOURCE" != "compact" ] && command -v git &>/dev/null && [ -d "$ROOT/.git" ]; then
  BRANCH=$(git -C "$ROOT" branch --show-current 2>/dev/null || true)
  if [ -n "$BRANCH" ]; then
    append_line ""
    append_line "Branch: $BRANCH"
  fi

  # Working tree status — flag dirty state so the agent reconciles against the
  # active task before picking up uncommitted files as "in scope". Silent when
  # the tree is clean (no noise on fresh sessions).
  PORCELAIN=$(git -C "$ROOT" status --porcelain 2>/dev/null || true)
  if [ -n "$PORCELAIN" ]; then
    MOD_COUNT=$(printf '%s\n' "$PORCELAIN" | grep -cE '^( M|M |MM|AM| A| D| R)' 2>/dev/null || true)
    UNT_COUNT=$(printf '%s\n' "$PORCELAIN" | grep -cE '^\?\?' 2>/dev/null || true)
    DEFAULT_BRANCH=$(git -C "$ROOT" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || echo main)
    AHEAD=0
    if [ -n "${BRANCH:-}" ] && [ "$BRANCH" != "$DEFAULT_BRANCH" ]; then
      AHEAD=$(git -C "$ROOT" rev-list --count "${DEFAULT_BRANCH}..HEAD" 2>/dev/null || echo 0)
    fi
    append_line ""
    append_line "Working tree (uncommitted):"
    [ "${MOD_COUNT:-0}" -gt 0 ] && append_line "- ${MOD_COUNT} modified file(s) (run \`git status\` to inspect)"
    [ "${UNT_COUNT:-0}" -gt 0 ] && append_line "- ${UNT_COUNT} untracked file(s)"
    if [ "${AHEAD:-0}" -gt 0 ]; then
      append_line "- Branch is ${AHEAD} commit(s) ahead of ${DEFAULT_BRANCH}"
    fi
    append_line "- Plan check: are these changes part of the active task in tasks/todo.md? If not, flag before proceeding."
  fi
fi

# Nothing substantive on a fresh session? Skip the hook output entirely (don't
# pollute context). We always emit the banner + blank line (2 lines), so only
# proceed if there are at least 3 non-empty content lines. The compact path
# always emits — its "re-establish context" message is worth showing even when
# todo/lessons are absent.
NONEMPTY=$(printf '%s' "$CONTEXT" | grep -cE '^[^[:space:]]' || true)
if [ "$SOURCE" != "compact" ] && [ "${NONEMPTY:-0}" -lt 3 ]; then
  exit 0
fi

# Emit JSON. Prefer python3 for safe escaping; fall back to jq; last resort: best-effort bash.
if command -v python3 &>/dev/null; then
  printf '%s' "$CONTEXT" | python3 -c 'import json,sys; print(json.dumps({"additionalContext": sys.stdin.read()}))'
elif command -v jq &>/dev/null; then
  printf '%s' "$CONTEXT" | jq -Rs '{additionalContext: .}'
else
  # No python3/jq: strip C0 control chars except tab/newline, escape backslash,
  # double-quote, and tab, then convert newlines to \n. Keeps the fallback's JSON
  # valid even when restored journal/todo/contract content carries tabs.
  TAB=$(printf '\t')
  ESCAPED=$(printf '%s' "$CONTEXT" \
    | LC_ALL=C tr -d '\000-\010\013-\037' \
    | sed 's/\\/\\\\/g; s/"/\\"/g; s/'"$TAB"'/\\t/g' \
    | awk 'BEGIN{ORS=""} {print; printf "\\n"}')
  printf '{"additionalContext":"%s"}\n' "$ESCAPED"
fi

exit 0
