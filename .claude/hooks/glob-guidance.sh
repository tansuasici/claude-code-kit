#!/usr/bin/env bash
#
# glob-guidance.sh — PreToolUse hook (matcher: Edit|Write|NotebookEdit)
#
# Surfaces path-scoped guidance for CROSS-CUTTING file patterns that don't map to
# a single directory (where a subdir CLAUDE.md already suffices) — e.g. test files
# or migrations anywhere in the tree. One-shot per pattern per session, so it
# nudges once, never nags. NON-BLOCKING: emits to stderr (the PreToolUse feedback
# channel Claude sees) and always exits 0.
#
# Customise: edit the case blocks below, or drop a project hook in
# .claude/hooks/project/ (never touched by kit upgrades).
#

set -euo pipefail

INPUT=$(cat)
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
source "$HOOK_LIB/json-parse.sh"

FILE_PATH=$(parse_json_field "file_path")
[ -z "$FILE_PATH" ] && exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.hook-state"
mkdir -p "$STATE_DIR" 2>/dev/null || true
[ -f "$STATE_DIR/.gitignore" ] || printf '*\n!.gitignore\n' >"$STATE_DIR/.gitignore" 2>/dev/null || true
FIRED="$STATE_DIR/glob-guidance-fired"

base=$(basename "$FILE_PATH")

# Emit a one-shot-per-session nudge for a given pattern id.
emit() {  # id  message
  if [ -f "$FIRED" ] && grep -qxF "$1" "$FIRED" 2>/dev/null; then
    return 0
  fi
  printf '%s\n' "$1" >> "$FIRED" 2>/dev/null || true
  echo "[glob-guidance] $2" >&2
}

# --- Guidance table (cross-cutting patterns) -----------------------------
case "$base" in
  *.test.*|*_test.*|*.spec.*|test_*.py)
    emit tests "Test file — keep tests behavior-focused. For a bug fix, add a failing test first, then make it pass (CLAUDE.md → Verification)." ;;
esac

case "$FILE_PATH" in
  */migrations/*|*[._-]migration[._-]*|*/migrate/*)
    emit migrations "Migration — this is a Protected Change. Confirm rollback, lock duration, and backfill/read-write impact before applying (CLAUDE.md → Protected Changes)." ;;
esac

exit 0
