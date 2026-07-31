#!/usr/bin/env bash
#
# block-dangerous-commands.sh — PreToolUse hook
# Blocks destructive shell commands that are hard to reverse
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

TOOL_NAME=$(parse_json_field "tool_name")

# Only check Bash tool
[ "$TOOL_NAME" != "Bash" ] && exit 0

COMMAND=$(parse_json_field "command")
[ -z "$COMMAND" ] && exit 0

BLOCKED=false
REASON=""

# Destructive file operations — catch rm -rf, rm -r -f, rm --recursive --force, etc.
# The optional (--\s+)? handles the POSIX end-of-options separator (e.g. rm -rf -- /)
RM_RECURSIVE='rm\s+(-[a-zA-Z]*r[a-zA-Z]*\s+(-[a-zA-Z]+\s+)*|-r\s+-f\s+|-f\s+-r\s+|--recursive\s+(-f\s+|--force\s+)?|-r\s+--force\s+)(--\s+)?'

# Absolute system directories that must never be recursively deleted. Deeper,
# project-local paths (e.g. /home/u/app/node_modules, /tmp/build) stay allowed —
# only the catastrophic roots and system trees are blocked.
RM_SYS_DIRS='etc|usr|var|bin|sbin|lib|lib64|opt|boot|dev|proc|sys|root|srv|System|Library|Applications|private|Network|Volumes|cores'

# rm -rf /   or   rm -rf /*   (whole filesystem)
if grep -qE "${RM_RECURSIVE}/(\\*|[[:space:]]*($|[;&|]))" <<< "$COMMAND"; then
  BLOCKED=true
  REASON="Recursive delete on root directory"
fi

# rm -rf /etc , /usr/local , sudo rm -rf /etc/nginx — any system path
if grep -qE "${RM_RECURSIVE}/(${RM_SYS_DIRS})(/|[[:space:]]|[;&|]|$)" <<< "$COMMAND"; then
  BLOCKED=true
  REASON="Recursive delete on a system directory"
fi

# Whole home directory: ~ , ~/Documents , \$HOME , /home/<user> , /Users/<user>.
# Deeper paths (~/proj/dist, /home/u/app/node_modules) remain allowed.
if grep -qE "${RM_RECURSIVE}(~|\\\$HOME|\\\$\{HOME\})(/[^/[:space:];&|]+)?([[:space:]]|[;&|]|$)" <<< "$COMMAND"; then
  BLOCKED=true
  REASON="Recursive delete on home directory"
fi

if grep -qE "${RM_RECURSIVE}/(home|Users)(/[^/[:space:];&|]+)?([[:space:]]|[;&|]|$)" <<< "$COMMAND"; then
  BLOCKED=true
  REASON="Recursive delete on home directory"
fi

if grep -qE "${RM_RECURSIVE}\\.\s*($|[;&|])" <<< "$COMMAND"; then
  BLOCKED=true
  REASON="Recursive delete on current directory"
fi

if grep -qE "${RM_RECURSIVE}\\*" <<< "$COMMAND"; then
  BLOCKED=true
  REASON="Recursive delete with wildcard"
fi

# --no-preserve-root exists only to defeat rm's built-in root guard
if grep -qE -- '--no-preserve-root' <<< "$COMMAND"; then
  BLOCKED=true
  REASON="rm --no-preserve-root bypasses root protection"
fi

# Git history destruction
if grep -qE 'git\s+reset\s+--hard' <<< "$COMMAND"; then
  BLOCKED=true
  REASON="git reset --hard discards all uncommitted changes"
fi

if grep -qE 'git\s+clean\s+(-[a-zA-Z]*f[a-zA-Z]*d|-[a-zA-Z]*d[a-zA-Z]*f|-[a-zA-Z]*f\s+-[a-zA-Z]*d|-[a-zA-Z]*d\s+-[a-zA-Z]*f)' <<< "$COMMAND"; then
  BLOCKED=true
  REASON="git clean -fd permanently deletes untracked files"
fi

# Database destruction
if grep -qiE 'DROP\s+(TABLE|DATABASE|SCHEMA)\b' <<< "$COMMAND"; then
  BLOCKED=true
  REASON="SQL DROP statement — destructive database operation"
fi

if grep -qiE 'TRUNCATE\s+TABLE\b' <<< "$COMMAND"; then
  BLOCKED=true
  REASON="SQL TRUNCATE — deletes all rows permanently"
fi

# Docker destruction
if grep -qE 'docker\s+system\s+prune\s+-a' <<< "$COMMAND"; then
  BLOCKED=true
  REASON="Docker system prune -a removes all unused images and containers"
fi

# chmod/chown -R on the filesystem root or a system directory. Recursive perms
# on app/home paths (/srv/app, /var/www, /home/u/app) stay allowed — those are
# routine for deploys and were false-positives under the old `.*\s+/` matcher.
if grep -qE '(chmod|chown)\s+-R\s+([^;&|]*\s)?/((etc|usr|bin|sbin|lib|lib64|boot|dev|proc|sys|root|System|Library)(/|[[:space:]]|[;&|]|$)|[[:space:]]*($|[;&|]))' <<< "$COMMAND"; then
  BLOCKED=true
  REASON="Recursive permission change on a system directory"
fi

if [ "$BLOCKED" = true ]; then
  bump_counter "$ROOT/.hook-state/hook-firings.json" "block-dangerous-commands"
  echo "BLOCKED: $REASON"
  echo ""
  echo "Command: $COMMAND"
  echo ""
  echo "This command is potentially destructive and hard to reverse."
  echo "Get explicit approval from the user before running it."
  exit 2
fi

exit 0
