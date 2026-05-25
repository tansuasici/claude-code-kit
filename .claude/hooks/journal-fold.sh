#!/usr/bin/env bash
#
# journal-fold.sh — SessionEnd hook
#
# After a session ends, fold two transient .hook-state artifacts into the
# durable session handoff (tasks/handoff-<session-id>.md), then clear them so
# the next session starts clean:
#
#   - .hook-state/agent-handoff.md   — the live inter-agent scratchpad (CLA-37);
#     the last sub-agent's <=5-line summary. Folded verbatim when non-empty.
#   - .hook-state/session-journal.md — populated by the `/note` skill:
#       * [finding] / [decision] entries → fold into the handoff
#       * [summary]-only                 → discard (transient breadcrumbs)
#
# Runs alongside session-end.sh (the scorecard hook); both are wired under
# SessionEnd in .claude/settings.json. Reads stdin for session_id but does
# not require any payload.
#
# Always exits 0 (never blocks). Silent when there is nothing to fold.
#

set -euo pipefail

INPUT=$(cat)
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
JOURNAL="$ROOT/.hook-state/session-journal.md"
AGENT_HANDOFF="$ROOT/.hook-state/agent-handoff.md"

# Extract session_id once (shared by both folds); fall back to a timestamp slug.
SESSION_ID=""
if command -v python3 >/dev/null 2>&1; then
  SESSION_ID=$(printf '%s' "$INPUT" | python3 -c "import sys,json
try:
    d = json.load(sys.stdin)
    sys.stdout.write(d.get('session_id', '') or '')
except Exception:
    pass" 2>/dev/null || true)
fi
[ -n "$SESSION_ID" ] || SESSION_ID=$(date -u +%Y%m%d-%H%M%S)

HANDOFF="$ROOT/tasks/handoff-${SESSION_ID}.md"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# --- Fold the inter-agent handoff scratchpad (CLA-37) ---
# The last sub-agent leaves a <=5-line summary here; preserve it in the session
# handoff so the next session sees where the agent chain left off. Always clear
# it afterward so the next session starts with an empty scratchpad.
if [ -f "$AGENT_HANDOFF" ] && [ -s "$AGENT_HANDOFF" ]; then
  mkdir -p "$ROOT/tasks"
  {
    echo ""
    echo "## Agent handoff — folded from agent-handoff.md on $NOW"
    echo ""
    cat "$AGENT_HANDOFF"
    echo ""
  } >> "$HANDOFF"
fi
rm -f "$AGENT_HANDOFF"

# --- Fold the /note journal ---
# No journal? Nothing more to do.
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

# Fold journal contents into tasks/handoff-<session-id>.md (append if exists).
mkdir -p "$ROOT/tasks"

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
