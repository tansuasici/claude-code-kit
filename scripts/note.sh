#!/usr/bin/env bash
#
# note.sh — append a tagged journal entry for mid-session across-compaction memory.
#
# Backs the `/note` skill. Writes one timestamped line to
# `.hook-state/session-journal.md` and reports the new entry count.
# The journal is transient (gitignored, same lifetime as other .hook-state/*)
# and is consumed by `.claude/hooks/journal-fold.sh` at session end.
#
# Usage:
#   ./scripts/note.sh <tag> <text>
#
# Tag must be one of: finding, decision, summary.
#
# Exit codes:
#   0  appended successfully
#   2  usage error (missing args or invalid tag)
#

set -euo pipefail

TAG="${1:-}"
shift || true
TEXT="${*:-}"

if [ -z "$TAG" ] || [ -z "$TEXT" ]; then
  echo "note: usage: $0 <tag> <text>" >&2
  echo "      tag must be one of: finding, decision, summary" >&2
  exit 2
fi

case "$TAG" in
  finding|decision|summary) ;;
  *)
    echo "note: invalid tag '$TAG'; must be one of: finding, decision, summary" >&2
    exit 2
    ;;
esac

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
STATE_DIR="$ROOT/.hook-state"
mkdir -p "$STATE_DIR"
[ -f "$STATE_DIR/.gitignore" ] || printf '*\n!.gitignore\n' >"$STATE_DIR/.gitignore"

JOURNAL="$STATE_DIR/session-journal.md"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LINE="$NOW [$TAG] $TEXT"
printf '%s\n' "$LINE" >> "$JOURNAL"

COUNT=$(wc -l < "$JOURNAL" | tr -d ' ')
echo "Noted: $LINE"
echo "→ .hook-state/session-journal.md ($COUNT entries)"
exit 0
