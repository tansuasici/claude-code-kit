#!/usr/bin/env bash
#
# block-dangerous-commands.sh — PreToolUse hook
# Blocks destructive shell commands that are hard to reverse
#
# Reads tool input from stdin (JSON with tool_name and tool_input)
#

set -euo pipefail

INPUT=$(cat)
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
source "$HOOK_LIB/json-parse.sh"

TOOL_NAME=$(parse_json_field "tool_name")

# Only check Bash tool
[ "$TOOL_NAME" != "Bash" ] && exit 0

COMMAND=$(parse_json_field "command")
[ -z "$COMMAND" ] && exit 0

BLOCKED=false
REASON=""

# Destructive file operations — catch rm -rf, rm -r -f, rm --recursive --force, etc.
RM_RECURSIVE='rm\s+(-[a-zA-Z]*r[a-zA-Z]*\s+(-[a-zA-Z]+\s+)*|-r\s+-f\s+|-f\s+-r\s+|--recursive\s+(-f\s+|--force\s+)?|-r\s+--force\s+)'

if echo "$COMMAND" | grep -qE "${RM_RECURSIVE}/[[:space:]]*($|[;&|])"; then
  BLOCKED=true
  REASON="Recursive delete on root directory"
fi

if echo "$COMMAND" | grep -qE "${RM_RECURSIVE}(~|\\\$HOME|\\\$\{HOME\})\b"; then
  BLOCKED=true
  REASON="Recursive delete on home directory"
fi

if echo "$COMMAND" | grep -qE "${RM_RECURSIVE}\\.\s*($|[;&|])"; then
  BLOCKED=true
  REASON="Recursive delete on current directory"
fi

if echo "$COMMAND" | grep -qE "${RM_RECURSIVE}\\*"; then
  BLOCKED=true
  REASON="Recursive delete with wildcard"
fi

# Git history destruction
if echo "$COMMAND" | grep -qE 'git\s+reset\s+--hard'; then
  BLOCKED=true
  REASON="git reset --hard discards all uncommitted changes"
fi

if echo "$COMMAND" | grep -qE 'git\s+clean\s+(-[a-zA-Z]*f[a-zA-Z]*d|-[a-zA-Z]*d[a-zA-Z]*f|-[a-zA-Z]*f\s+-[a-zA-Z]*d|-[a-zA-Z]*d\s+-[a-zA-Z]*f)'; then
  BLOCKED=true
  REASON="git clean -fd permanently deletes untracked files"
fi

# Database destruction
if echo "$COMMAND" | grep -qiE 'DROP\s+(TABLE|DATABASE|SCHEMA)\b'; then
  BLOCKED=true
  REASON="SQL DROP statement — destructive database operation"
fi

if echo "$COMMAND" | grep -qiE 'TRUNCATE\s+TABLE\b'; then
  BLOCKED=true
  REASON="SQL TRUNCATE — deletes all rows permanently"
fi

# Docker destruction
if echo "$COMMAND" | grep -qE 'docker\s+system\s+prune\s+-a'; then
  BLOCKED=true
  REASON="Docker system prune -a removes all unused images and containers"
fi

# chmod/chown on broad paths
if echo "$COMMAND" | grep -qE '(chmod|chown)\s+-R\s+.*\s+/'; then
  BLOCKED=true
  REASON="Recursive permission change on root path"
fi

if [ "$BLOCKED" = true ]; then
  echo "BLOCKED: $REASON"
  echo ""
  echo "Command: $COMMAND"
  echo ""
  echo "This command is potentially destructive and hard to reverse."
  echo "Get explicit approval from the user before running it."
  exit 2
fi

exit 0
