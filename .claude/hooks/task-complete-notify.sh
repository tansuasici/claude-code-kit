#!/usr/bin/env bash
#
# task-complete-notify.sh — Stop hook (or Notification hook)
# Sends a desktop notification when Claude finishes a task
#
# Works on macOS (osascript) and Linux (notify-send)
#

set -euo pipefail

TITLE="Claude Code"
MESSAGE="Task completed"

# macOS
if command -v osascript &>/dev/null; then
  osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\"" 2>/dev/null || true

  # Optional: play a sound
  afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &

# Linux with notify-send
elif command -v notify-send &>/dev/null; then
  notify-send "$TITLE" "$MESSAGE" 2>/dev/null || true

  # Optional: play a sound
  if command -v paplay &>/dev/null; then
    paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null &
  fi
fi

exit 0
