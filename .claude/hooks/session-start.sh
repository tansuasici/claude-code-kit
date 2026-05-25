#!/usr/bin/env bash
#
# session-start.sh — SessionStart hook
#
# Injects minimal Tier 1 context at the start of every session, replacing
# the CLAUDE.md prompt rule "Read CODEBASE_MAP.md, CLAUDE.project.md, lessons,
# active todo" — which depends on the agent voluntarily following it.
#
# Output: JSON with `additionalContext` (Claude Code injects this into the
# session before the first user turn).
#
# Reads stdin but does not require any payload. Always exits 0.
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

# Reset transient session counters from any prior session. session-end.sh has
# already consumed them (or, if the prior session crashed, the next aggregator
# would otherwise double-count). New session starts at zero.
reset_state "$STATE_DIR/hook-firings.json"
reset_state "$STATE_DIR/quality-gate-history.json"
reset_state "$STATE_DIR/bash-budget.json"

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

CONTEXT=""

append() { CONTEXT="${CONTEXT}${1}"; }
append_line() { CONTEXT="${CONTEXT}${1}"$'\n'; }

append_line "[Auto-injected by session-start.sh]"
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

# 4. Branch hint (cheap, helps the agent reason about ship/release context)
if command -v git &>/dev/null && [ -d "$ROOT/.git" ]; then
  BRANCH=$(git -C "$ROOT" branch --show-current 2>/dev/null || true)
  if [ -n "$BRANCH" ]; then
    append_line ""
    append_line "Branch: $BRANCH"
  fi

  # 5. Working tree status — flag dirty state so the agent reconciles against
  # the active task before picking up uncommitted files as "in scope".
  # Silent when the tree is clean (no noise on fresh sessions).
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

# Nothing substantive? Skip the hook output entirely (don't pollute context).
# We always emit the [Auto-injected] banner + blank line (2 lines), so only
# proceed if there are at least 3 non-empty content lines beyond those.
NONEMPTY=$(printf '%s' "$CONTEXT" | grep -cE '^[^[:space:]]' || true)
if [ "${NONEMPTY:-0}" -lt 3 ]; then
  exit 0
fi

# Emit JSON. Prefer python3 for safe escaping; fall back to jq; last resort: best-effort bash.
if command -v python3 &>/dev/null; then
  printf '%s' "$CONTEXT" | python3 -c 'import json,sys; print(json.dumps({"additionalContext": sys.stdin.read()}))'
elif command -v jq &>/dev/null; then
  printf '%s' "$CONTEXT" | jq -Rs '{additionalContext: .}'
else
  # Minimal escape: backslash, double-quote, newline
  ESCAPED=$(printf '%s' "$CONTEXT" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk 'BEGIN{ORS=""} {print; printf "\\n"}')
  printf '{"additionalContext":"%s"}\n' "$ESCAPED"
fi

exit 0
