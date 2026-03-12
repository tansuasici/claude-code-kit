#!/usr/bin/env bash
#
# block-dangerous-commands.sh — PreToolUse hook
# Blocks destructive shell commands that are hard to reverse
#
# Reads tool input from stdin (JSON with tool_name and tool_input)
#

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | grep -oE '"tool_name"\s*:\s*"[^"]*"' | sed 's/.*:\s*"//;s/"$//')

# Only check Bash tool
[ "$TOOL_NAME" != "Bash" ] && exit 0

COMMAND=$(echo "$INPUT" | grep -oE '"command"\s*:\s*"[^"]*"' | sed 's/.*:\s*"//;s/"$//' || echo "")
[ -z "$COMMAND" ] && exit 0

BLOCKED=false
REASON=""

# Destructive file operations
if echo "$COMMAND" | grep -qE 'rm\s+-(r|rf|fr)\s+/'; then
  BLOCKED=true
  REASON="Recursive delete on root directory"
fi

if echo "$COMMAND" | grep -qE 'rm\s+-(r|rf|fr)\s+(~|\$HOME)\b'; then
  BLOCKED=true
  REASON="Recursive delete on home directory"
fi

if echo "$COMMAND" | grep -qE 'rm\s+-(r|rf|fr)\s+\.\s*($|[;&|])'; then
  BLOCKED=true
  REASON="Recursive delete on current directory"
fi

if echo "$COMMAND" | grep -qE 'rm\s+-(r|rf|fr)\s+\*'; then
  BLOCKED=true
  REASON="Recursive delete with wildcard"
fi

# Git history destruction
if echo "$COMMAND" | grep -qE 'git\s+reset\s+--hard'; then
  BLOCKED=true
  REASON="git reset --hard discards all uncommitted changes"
fi

if echo "$COMMAND" | grep -qE 'git\s+clean\s+-fd'; then
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
