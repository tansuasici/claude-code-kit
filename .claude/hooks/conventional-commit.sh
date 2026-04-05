#!/usr/bin/env bash
#
# conventional-commit.sh — PreToolUse hook
# Validates commit messages follow conventional commit format
#
# Format: <type>: <description>
# Types: feat, fix, refactor, test, docs, chore, perf, ci, build, style
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

# Only check git commit commands
if ! echo "$COMMAND" | grep -qE 'git\s+commit'; then
  exit 0
fi

# Extract commit message from -m/--message flag
MSG=$(echo "$COMMAND" | grep -oE '(-m|--message)[[:space:]]*"[^"]*"' | sed -E 's/(-m|--message)[[:space:]]*"//;s/"$//' || echo "")

# Also try single quotes
if [ -z "$MSG" ]; then
  MSG=$(echo "$COMMAND" | grep -oE "(-m|--message)[[:space:]]*'[^']*'" | sed -E "s/(-m|--message)[[:space:]]*'//;s/'$//" || echo "")
fi

# If using heredoc or no -m flag, skip validation
if [ -z "$MSG" ]; then
  exit 0
fi

# Get first line of commit message
FIRST_LINE=$(echo "$MSG" | head -1)

# Validate conventional commit format
VALID_TYPES="feat|fix|refactor|test|docs|chore|perf|ci|build|style"

if ! echo "$FIRST_LINE" | grep -qE "^($VALID_TYPES)(\(.+\))?: .+"; then
  echo "BLOCKED: Commit message doesn't follow conventional commit format"
  echo ""
  echo "  Got:      $FIRST_LINE"
  echo "  Expected: <type>: <description>"
  echo ""
  echo "  Valid types: feat, fix, refactor, test, docs, chore, perf, ci, build, style"
  echo ""
  echo "  Examples:"
  echo "    feat: add user search endpoint"
  echo "    fix: handle null response from auth API"
  echo "    refactor(auth): simplify token validation"
  exit 2
fi

exit 0
