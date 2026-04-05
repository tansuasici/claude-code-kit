#!/usr/bin/env bash
#
# loop-detect.sh — PostToolUse hook
# Detects agent edit loops: same file edited 4+ times without progress
#
# Tracks recent Edit/Write actions in a temp file and warns or blocks
# when the same file is being repeatedly edited.
#

set -euo pipefail

INPUT=$(cat)
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
source "$HOOK_LIB/json-parse.sh"

TOOL_NAME=$(parse_json_field "tool_name")

# Only track file-editing tools
case "$TOOL_NAME" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(parse_json_field "file_path")
[ -z "$FILE_PATH" ] && exit 0

# Track file in a session-scoped temp file
TRACK_FILE="/tmp/claude-loop-detect-$$"
# Use parent PID for session scope (agent runs hooks as child processes)
TRACK_FILE="/tmp/claude-loop-detect-${PPID:-$$}"

# Append current edit
echo "$FILE_PATH" >> "$TRACK_FILE"

# Count recent edits to this file (last 10 entries)
RECENT_EDITS=$(tail -10 "$TRACK_FILE" 2>/dev/null | grep -cF "$FILE_PATH" || echo "0")

if [ "$RECENT_EDITS" -ge 6 ]; then
  # Second warning: block the action
  echo "BLOCKED: $FILE_PATH has been edited $RECENT_EDITS times in recent actions."
  echo ""
  echo "This looks like an edit loop. Stop and:"
  echo "  1. Re-read the original goal"
  echo "  2. Re-read the file to understand current state"
  echo "  3. Ask the user for guidance if stuck"
  echo ""
  echo "Do NOT continue editing the same file repeatedly."
  exit 2
elif [ "$RECENT_EDITS" -ge 4 ]; then
  # First warning: let it through but warn
  echo "WARNING: $FILE_PATH has been edited $RECENT_EDITS times in recent actions."
  echo ""
  echo "You may be in an edit loop. Consider:"
  echo "  - Re-reading the file to check current state"
  echo "  - Re-reading the original goal"
  echo "  - Trying a different approach"
  exit 0
fi

exit 0
