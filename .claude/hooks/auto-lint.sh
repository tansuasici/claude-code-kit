#!/usr/bin/env bash
#
# auto-lint.sh — PostToolUse hook
# Runs the appropriate linter after file edits
#
# Reads tool input from stdin (JSON with tool_name and tool_input)
#

set -euo pipefail

INPUT=$(cat)
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
source "$HOOK_LIB/json-parse.sh"
source "$HOOK_LIB/roots.sh"

TOOL_NAME=$(parse_json_field "tool_name")

# Only run after file edits
case "$TOOL_NAME" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(parse_json_field "file_path")
[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

EXT="${FILE_PATH##*.}"
DIR=$(dirname "$FILE_PATH")

# Find project root: nearest project marker, stopping at the git worktree
# (lib/roots.sh). If none is found, fall back to the file's directory.
PROJECT_ROOT=$(package_root "$FILE_PATH")
[ -z "$PROJECT_ROOT" ] && PROJECT_ROOT="$DIR"

case "$EXT" in
  js|jsx|ts|tsx|mjs|cjs)
    # Try eslint
    if [ -f "$PROJECT_ROOT/node_modules/.bin/eslint" ]; then
      "$PROJECT_ROOT/node_modules/.bin/eslint" --fix "$FILE_PATH" 2>/dev/null || true
    elif command -v eslint &>/dev/null; then
      eslint --fix "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
  py)
    # Try ruff (fast), fall back to flake8
    if command -v ruff &>/dev/null; then
      ruff check --fix "$FILE_PATH" 2>/dev/null || true
    elif command -v flake8 &>/dev/null; then
      flake8 "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
  go)
    if command -v gofmt &>/dev/null; then
      gofmt -w "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
  rs)
    if command -v cargo &>/dev/null; then
      cargo clippy --fix --allow-dirty --allow-staged 2>/dev/null || true
    fi
    ;;
  rb)
    if command -v rubocop &>/dev/null; then
      rubocop -a "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
esac

exit 0
