#!/usr/bin/env bash
#
# branch-protect.sh — PreToolUse hook
# Blocks direct pushes to main/master branch
#
# Reads tool input from stdin (JSON with tool_name and tool_input)
#

set -euo pipefail

INPUT=$(cat)
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd || true)"
# Fail closed: a safety hook that can't load its library must block, not
# silently no-op. Empty HOOK_LIB → lib/ missing → exit 2 (CLA-47).
if [ -z "$HOOK_LIB" ] || [ ! -f "$HOOK_LIB/json-parse.sh" ]; then
  echo "BLOCKED: $(basename "$0") cannot load .claude/hooks/lib/ — refusing to run fail-open. Reinstall kit hooks (cck init --upgrade)." >&2
  exit 2
fi
source "$HOOK_LIB/json-parse.sh"
source "$HOOK_LIB/state-counter.sh"

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

bump_branch_block() {
  bump_counter "$ROOT/.hook-state/hook-firings.json" "branch-protect"
}

TOOL_NAME=$(parse_json_field "tool_name")

# Only check Bash tool
[ "$TOOL_NAME" != "Bash" ] && exit 0

COMMAND=$(parse_json_field "command")
[ -z "$COMMAND" ] && exit 0

# `git push` possibly preceded by global options like `git -c key=val push`.
# Matching the prefix means `git -c color.ui=always push origin main` can't slip by.
GIT_PUSH='git\s+(-c\s+\S+\s+)*push'

# Check for force push (check first — always block regardless of branch)
# Allow --force-with-lease (safer alternative) but block --force and -f
if echo "$COMMAND" | grep -qE "${GIT_PUSH}\s+.*--force-with-lease"; then
  : # Allow --force-with-lease (only overwrites if remote matches expectations)
elif echo "$COMMAND" | grep -qE "${GIT_PUSH}\s+.*--force|${GIT_PUSH}\s+.*-f\b"; then
  bump_branch_block
  echo "BLOCKED: Force push detected"
  echo ""
  echo "Force pushing can overwrite remote history."
  echo "Consider using --force-with-lease for a safer alternative,"
  echo "or get explicit approval from the user before force pushing."
  exit 2
fi

# Check for git push to a protected branch, named explicitly. Two shapes:
#   1. main/master as the final positional arg, regardless of how many options
#      precede it:  git push origin main | git push -u origin main |
#                   git push --set-upstream origin main
#   2. a refspec whose DESTINATION is protected:  HEAD:main | local:master |
#      main:main   (pushing TO main). `git push origin main:feature` is allowed —
#      that pushes local main to a feature branch, not to remote main.
if echo "$COMMAND" | grep -qE "${GIT_PUSH}\s+(\S+\s+)*(main|master)([[:space:]]|[;&|]|$)" \
  || echo "$COMMAND" | grep -qE "${GIT_PUSH}\s+.*:(main|master)([[:space:]]|[;&|]|$)"; then
  bump_branch_block
  echo "BLOCKED: Direct push to main/master branch"
  echo ""
  echo "Create a feature branch and open a PR instead:"
  echo "  git checkout -b feat/your-feature"
  echo "  git push -u origin feat/your-feature"
  exit 2
fi

# Check for `git push <remote> HEAD` when on main/master
if echo "$COMMAND" | grep -qE "${GIT_PUSH}\s+\S+\s+HEAD\b"; then
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null) || CURRENT_BRANCH=""
  if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
    bump_branch_block
    echo "BLOCKED: 'git push <remote> HEAD' resolves to protected branch '$CURRENT_BRANCH'"
    echo ""
    echo "Create a feature branch and open a PR instead:"
    echo "  git checkout -b feat/your-feature"
    echo "  git push -u origin feat/your-feature"
    exit 2
  fi
fi

# Check for bare `git push` (no branch given) while on main/master. Tolerates
# `-u`/`--set-upstream` and an explicit remote: `git push`, `git push -u origin`.
if echo "$COMMAND" | grep -qE "(^|[;&|]\s*)${GIT_PUSH}(\s+(-u|--set-upstream))?(\s+origin)?\s*($|[;&|])"; then
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null) || CURRENT_BRANCH=""
  if [ -z "$CURRENT_BRANCH" ]; then
    exit 0  # Cannot determine branch, allow the push
  fi
  if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
    bump_branch_block
    echo "BLOCKED: You are on '$CURRENT_BRANCH' — bare 'git push' would push to protected branch"
    echo ""
    echo "Create a feature branch and open a PR instead:"
    echo "  git checkout -b feat/your-feature"
    echo "  git push -u origin feat/your-feature"
    exit 2
  fi
fi

exit 0
