#!/usr/bin/env bash
#
# branch-protect.sh — PreToolUse hook
# Blocks direct pushes to main/master branch
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

# Check for force push (check first — always block regardless of branch)
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*--force|git\s+push\s+.*-f\b'; then
  echo "BLOCKED: Force push detected"
  echo ""
  echo "Force pushing can overwrite remote history."
  echo "Get explicit approval from the user before force pushing."
  exit 2
fi

# Check for git push to protected branches (explicit branch name)
if echo "$COMMAND" | grep -qE 'git\s+push.*\s+(origin\s+)?(main|master)\b'; then
  echo "BLOCKED: Direct push to main/master branch"
  echo ""
  echo "Create a feature branch and open a PR instead:"
  echo "  git checkout -b feat/your-feature"
  echo "  git push -u origin feat/your-feature"
  exit 2
fi

# Check for bare `git push` when on main/master (no branch specified)
if echo "$COMMAND" | grep -qE '^git\s+push(\s+-u)?(\s+origin)?\s*$'; then
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null) || CURRENT_BRANCH=""
  if [ -z "$CURRENT_BRANCH" ]; then
    exit 0  # Cannot determine branch, allow the push
  fi
  if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
    echo "BLOCKED: You are on '$CURRENT_BRANCH' — bare 'git push' would push to protected branch"
    echo ""
    echo "Create a feature branch and open a PR instead:"
    echo "  git checkout -b feat/your-feature"
    echo "  git push -u origin feat/your-feature"
    exit 2
  fi
fi

exit 0
