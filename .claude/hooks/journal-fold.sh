#!/usr/bin/env bash
#
# journal-fold.sh — SessionEnd hook
#
# After a session ends, decide what to do with .hook-state/session-journal.md
# (populated by the `/note` skill mid-session):
#
#   - If it contains [finding] or [decision] entries → fold into
#     tasks/handoff-<session-id>.md so the next session can pick up
#   - If it contains only [summary] entries → discard (transient breadcrumbs)
#   - Always: remove the journal file so the next session starts clean
#
# Runs alongside session-end.sh (the scorecard hook); both are wired under
# SessionEnd in .claude/settings.json. Reads stdin for session_id but does
# not require any payload.
#
# Always exits 0 (never blocks). Silent when there is no journal.
#

set -euo pipefail

INPUT=$(cat)
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
JOURNAL="$ROOT/.hook-state/session-journal.md"

# No journal? Silent exit.
[ -f "$JOURNAL" ] || exit 0

# Empty journal? Clean up and exit.
if [ ! -s "$JOURNAL" ]; then
  rm -f "$JOURNAL"
  exit 0
fi

# Count entries by tag. `grep -c` returns "" on no match in some envs; coerce.
FINDINGS=$(grep -c '\[finding\]' "$JOURNAL" 2>/dev/null || true)
DECISIONS=$(grep -c '\[decision\]' "$JOURNAL" 2>/dev/null || true)
SUMMARIES=$(grep -c '\[summary\]' "$JOURNAL" 2>/dev/null || true)
FINDINGS=${FINDINGS:-0}
DECISIONS=${DECISIONS:-0}
SUMMARIES=${SUMMARIES:-0}

# If only summaries (no findings/decisions), discard.
if [ "$FINDINGS" -eq 0 ] && [ "$DECISIONS" -eq 0 ]; then
  rm -f "$JOURNAL"
  exit 0
fi

# Extract session_id from stdin (best effort, falls back to a timestamp slug).
SESSION_ID=""
if command -v python3 >/dev/null 2>&1; then
  SESSION_ID=$(printf '%s' "$INPUT" | python3 -c "import sys,json
try:
    d = json.load(sys.stdin)
    sys.stdout.write(d.get('session_id', '') or '')
except Exception:
    pass" 2>/dev/null || true)
fi
if [ -z "$SESSION_ID" ]; then
  SESSION_ID=$(date -u +%Y%m%d-%H%M%S)
fi

# Fold journal contents into tasks/handoff-<session-id>.md (append if exists).
HANDOFF="$ROOT/tasks/handoff-${SESSION_ID}.md"
mkdir -p "$ROOT/tasks"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

{
  echo ""
  echo "## Journal — folded from session-journal.md on $NOW"
  echo ""
  cat "$JOURNAL"
  echo ""
  echo "**Counts:** findings: $FINDINGS · decisions: $DECISIONS · summaries: $SUMMARIES"
  echo ""
} >> "$HANDOFF"

rm -f "$JOURNAL"
exit 0
