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

# `git push` possibly preceded by global options like `git -c key=val push` or
# `git -C dir push`. Matching the prefix means `git -c color.ui=always push
# origin main` can't slip by.
GIT_PUSH='git\s+(-[cC]\s+\S+\s+)*push'

# Judge each `git push` on its own arguments. Cut the command at every `;`, `&`
# and `|` (so `&&`, `||`, pipes and backgrounding too) and keep only the pieces
# holding a push — otherwise `git push -u origin feat/x && gh pr create --base
# main` reads `main` as the push target, and `git push origin feat && rm -f x`
# reads `-f` as a force push. A separator inside quotes (`-o 'a;b'`) or the `&`
# of a redirection (`2>&1`, `&>log`, `>&2`) does not cut: either would hide
# the arguments after it — `git push 2>&1 origin main` must still block.
split_commands() {
  awk '{
    n = length($0); out = ""
    for (i = 1; i <= n; i++) {
      c = substr($0, i, 1); p = substr($0, i - 1, 1); x = substr($0, i + 1, 1)
      if (esc) { esc = 0; out = out c; continue }
      if (c == "\\" && !sq) { esc = 1; out = out c; continue }
      if (c == "\047" && !dq) sq = !sq
      else if (c == "\"" && !sq) dq = !dq
      else if (!sq && !dq && (c == ";" || c == "|" || c == "&")) {
        if (c == "&" && (p == ">" || p == "<" || x == ">")) { out = out c; continue }
        out = out "\n"; continue
      }
      out = out c
    }
    print out
  }' <<< "$1"
}
PUSHES=$(split_commands "$COMMAND" | grep -E "${GIT_PUSH}" || true)
[ -z "$PUSHES" ] && exit 0

block_protected() {
  bump_branch_block
  echo "$1"
  echo ""
  echo "Create a feature branch and open a PR instead:"
  echo "  git checkout -b feat/your-feature"
  echo "  git push -u origin feat/your-feature"
  exit 2
}

while IFS= read -r PUSH; do
  # Check for force push (check first — always block regardless of branch)
  # Allow --force-with-lease (safer alternative) but block --force and -f
  if grep -qE "${GIT_PUSH}\s+.*--force-with-lease" <<< "$PUSH"; then
    : # Allow --force-with-lease (only overwrites if remote matches expectations)
  elif grep -qE "${GIT_PUSH}\s+.*--force|${GIT_PUSH}\s+.*-f\b" <<< "$PUSH"; then
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
  if grep -qE "${GIT_PUSH}\s+(\S+\s+)*(main|master)([[:space:])&<>]|$)" <<< "$PUSH" \
    || grep -qE "${GIT_PUSH}\s+.*:(main|master)([[:space:])&<>]|$)" <<< "$PUSH"; then
    block_protected "BLOCKED: Direct push to main/master branch"
  fi

  # Redirections (`2>&1`, `&>/dev/null`, `>log`) name no branch: drop them for
  # the HEAD and bare-push checks, so `git push &>/dev/null` is still bare.
  BARE=$(sed -E 's/[0-9]*(&>>?|>>?&?|<&?)[[:space:]]*[^[:space:]]+//g' <<< "$PUSH")

  # Check for `git push <remote> HEAD` when on main/master
  if grep -qE "${GIT_PUSH}\s+\S+\s+HEAD\b" <<< "$BARE"; then
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null) || CURRENT_BRANCH=""
    if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
      block_protected "BLOCKED: 'git push <remote> HEAD' resolves to protected branch '$CURRENT_BRANCH'"
    fi
  fi

  # Check for bare `git push` (no branch given) while on main/master. Tolerates
  # `-u`/`--set-upstream` and an explicit remote: `git push`, `git push -u origin`.
  # The push must open its piece, as it had to follow a separator before the cut.
  if grep -qE "^\s*${GIT_PUSH}(\s+(-u|--set-upstream))?(\s+origin)?\s*$" <<< "$BARE"; then
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null) || CURRENT_BRANCH=""
    # An undeterminable branch allows this push; later pushes are still checked.
    if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
      block_protected "BLOCKED: You are on '$CURRENT_BRANCH' — bare 'git push' would push to protected branch"
    fi
  fi
done <<< "$PUSHES"

exit 0
