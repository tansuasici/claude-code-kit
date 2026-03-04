#!/usr/bin/env bash
#
# branch-protect.sh — PreToolUse hook
# Blocks direct pushes to main/master branch
#
# Reads tool input from stdin (JSON with tool_name and tool_input)
#

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | cut -d'"' -f4)

# Only check Bash tool
[ "$TOOL_NAME" != "Bash" ] && exit 0

COMMAND=$(echo "$INPUT" | grep -o '"command":"[^"]*"' | cut -d'"' -f4 || echo "")
[ -z "$COMMAND" ] && exit 0

# Check for git push to protected branches
if echo "$COMMAND" | grep -qE 'git\s+push.*\s+(origin\s+)?(main|master)\b'; then
  echo "BLOCKED: Direct push to main/master branch"
  echo ""
  echo "Create a feature branch and open a PR instead:"
  echo "  git checkout -b feat/your-feature"
  echo "  git push -u origin feat/your-feature"
  exit 2
fi

# Check for force push
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*--force|git\s+push\s+-f\b'; then
  echo "BLOCKED: Force push detected"
  echo ""
  echo "Force pushing can overwrite remote history."
  echo "Get explicit approval from the user before force pushing."
  exit 2
fi

exit 0
