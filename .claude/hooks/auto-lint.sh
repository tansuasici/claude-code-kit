#!/usr/bin/env bash
#
# auto-lint.sh — PostToolUse hook
# Runs the appropriate linter after file edits
#
# Reads tool input from stdin (JSON with tool_name and tool_input)
#

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | grep -oE '"tool_name"\s*:\s*"[^"]*"' | sed 's/.*:\s*"//;s/"$//')

# Only run after file edits
case "$TOOL_NAME" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"\s*:\s*"[^"]*"' | sed 's/.*:\s*"//;s/"$//' || echo "")
[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

EXT="${FILE_PATH##*.}"
DIR=$(dirname "$FILE_PATH")

# Find project root (look for common markers)
PROJECT_ROOT="$DIR"
while [ "$PROJECT_ROOT" != "/" ]; do
  if [ -f "$PROJECT_ROOT/package.json" ] || [ -f "$PROJECT_ROOT/pyproject.toml" ] || [ -f "$PROJECT_ROOT/go.mod" ] || [ -f "$PROJECT_ROOT/Cargo.toml" ]; then
    break
  fi
  PROJECT_ROOT=$(dirname "$PROJECT_ROOT")
done
# If no project marker found, fall back to the file's directory
[ "$PROJECT_ROOT" = "/" ] && PROJECT_ROOT="$DIR"

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
