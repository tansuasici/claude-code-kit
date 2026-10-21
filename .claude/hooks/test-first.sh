#!/usr/bin/env bash
#
# test-first.sh — PostToolUse hook (matcher: Edit|Write|NotebookEdit)
#
# Records a source file edited with no test behind it, and says so once. The
# Test List comes first (agent_docs/testing.md → Test-First): a named failing
# test is what makes "done" checkable, and the failure mode this catches is the
# agent-specific one — a function returning a constant, with no red test on
# screen, shipped as done.
#
# Does NOT block the edit. The record lands in
# .hook-state/test-first-pending.tsv (session<TAB>file<TAB>epoch) and
# test-first-gate.sh decides at Stop what to do with it — advisory by default,
# blocking under CCK_TEST_FIRST=strict. Same record-then-block split as
# quality-gate.sh / stop-gate.sh (tasks/decisions.md → ADR-022), so one edit
# never owns a completion decision.
#
# What Claude needs to hear goes out as PostToolUse additionalContext on stdout:
# stderr from a hook that exits 0 only reaches the debug log. Once per file per
# session — a second edit of the same untested file stays silent.
#
# Which files: lib/test-paths.sh decides, by path convention only. Shell, Rust,
# docs, config, barrels, generated output and anything already under a test
# directory are out of scope — a false "this file owes a test" is the expensive
# error, because the strict profile blocks on it.
#
# Writing the test first is the quiet path: the test file exists when the source
# is edited, so nothing is recorded and nothing is said.
#

set -uo pipefail

INPUT=$(cat)
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
source "$HOOK_LIB/json-parse.sh"
source "$HOOK_LIB/test-paths.sh"

TOOL_NAME=$(parse_json_field "tool_name")
case "$TOOL_NAME" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(parse_json_field "file_path")
[ -n "$FILE_PATH" ] || exit 0
[ -f "$FILE_PATH" ] || exit 0

# The session's own project: one state location, read by one Stop gate. An edit
# into another git worktree is not followed the way quality-gate.sh follows it —
# a missing nudge there costs a reminder, not a verdict (ADR-024).
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.hook-state"
PENDING="$STATE_DIR/test-first-pending.tsv"
TAB=$'\t'

SID=$(parse_json_field "session_id")
SID="${SID//[[:space:]]/_}"
SID="${SID:--}"

# No state directory → no record to keep. Nothing here blocks, so a project
# whose .hook-state can't be written just loses the nudge.
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
[ -f "$STATE_DIR/.gitignore" ] || { printf '*\n!.gitignore\n' >"$STATE_DIR/.gitignore"; } 2>/dev/null || true

# drop_satisfied — rewrite the pending list, keeping only files that still exist
# and still owe a test. Asks test_exists_for again rather than matching the
# written test back to a source: one matching rule, asked in one direction.
drop_satisfied() {
  local tmp line s f e
  [ -s "$PENDING" ] || return 0
  tmp="$PENDING.$$"
  : >"$tmp" 2>/dev/null || return 0
  while IFS="$TAB" read -r s f e; do
    [ -n "${f:-}" ] || continue
    [ -f "$f" ] || continue
    test_exists_for "$f" && continue
    printf '%s\t%s\t%s\n' "$s" "$f" "${e:-0}" >>"$tmp"
  done <"$PENDING"
  mv -f "$tmp" "$PENDING" 2>/dev/null || rm -f "$tmp" 2>/dev/null || true
}

# A test was written: every pending source it covers is settled.
if is_test_file "$FILE_PATH"; then
  drop_satisfied
  exit 0
fi

test_source_candidate "$FILE_PATH" || exit 0

if test_exists_for "$FILE_PATH"; then
  drop_satisfied   # it may have been pending before the test appeared
  exit 0
fi

# Already recorded for this session → nudge once, never nag (glob-guidance.sh's
# one-shot contract). grep reads the file directly: never pipe into a quiet grep.
if [ -f "$PENDING" ] && grep -qF -- "$SID$TAB$FILE_PATH$TAB" "$PENDING" 2>/dev/null; then
  exit 0
fi

{ printf '%s\t%s\t%s\n' "$SID" "$FILE_PATH" "$(date +%s)" >>"$PENDING"; } 2>/dev/null || exit 0

REL="$FILE_PATH"
case "$FILE_PATH" in "$ROOT"/*) REL="${FILE_PATH#"$ROOT"/}" ;; esac

MSG="$REL has no test file. Write the failing test first, then the code that passes it (agent_docs/testing.md → Test-First): a named test is what makes \"done\" checkable, and a function that returns the right constant with no red test behind it is a stub, not an implementation. If this file is not meant to have one — a refactor, config, a spike — say so and move on; nothing is blocked here."

# json_str (lib/json-parse.sh) builds the string body without needing python3 —
# the nudge must survive a project where python3 is unusable.
printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$(json_str "$MSG")"
exit 0
