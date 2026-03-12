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

TOOL_NAME=$(echo "$INPUT" | grep -oE '"tool_name"\s*:\s*"[^"]*"' | sed 's/.*:\s*"//;s/"$//')

# Only check Bash tool
[ "$TOOL_NAME" != "Bash" ] && exit 0

COMMAND=$(echo "$INPUT" | grep -oE '"command"\s*:\s*"[^"]*"' | sed 's/.*:\s*"//;s/"$//' || echo "")
[ -z "$COMMAND" ] && exit 0

# Only check git commit commands
if ! echo "$COMMAND" | grep -qE 'git\s+commit'; then
  exit 0
fi

# Extract commit message from -m/--message flag
MSG=$(echo "$COMMAND" | grep -oE '(-m|--message)\s*"[^"]*"' | sed 's/\(-m\|--message\)\s*"//;s/"$//' || echo "")

# Also try single quotes
if [ -z "$MSG" ]; then
  MSG=$(echo "$COMMAND" | grep -oE "(-m|--message)\s*'[^']*'" | sed "s/\(-m\|--message\)\s*'//;s/'$//" || echo "")
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
