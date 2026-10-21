#!/usr/bin/env bash
#
# test-run.sh — PostToolUse hook (matcher: Edit|Write|NotebookEdit)
#
# Runs the ONE test that covers the edited file and records the result. This is
# the half of the test-first loop a path check can't reach: test-first.sh asks
# whether a test exists, this asks whether it passes (agent_docs/testing.md →
# Test-First). Running the whole suite per edit is what the quality gate
# deliberately refuses; running the related test is affordable, and it is what
# makes "done" mean something other than "the edits stopped".
#
# Opt-in. The command comes from .claude/commands.json → "test-file", which must
# carry a "{file}" placeholder (lib/project-commands.sh):
#
#   { "test-file": "npx vitest run {file}" }
#   { "test-file": "python -m pytest -q {file}" }
#
# Absent, "" or without the placeholder → the hook does nothing: the kit does not
# guess how to run one test, because the wrong guess runs the whole suite on every
# edit. A broken commands.json is quality-gate.sh's to report, not this hook's.
#
# Which test: lib/test-paths.sh, by path convention. An edit to the test file
# itself runs that file — that is where the red bar normally comes from, since
# the test is written before the code it tests.
#
# Does NOT block the edit. Results go to .hook-state/test-run-log.tsv, which is
# append-only:
#
#   session<TAB>test<TAB>source<TAB>status<TAB>epoch<TAB>detail
#
# Paths are relative to the project; source is "-" when the edit was to the test
# itself. The latest line for a test is its verdict (test-first-gate.sh reads it
# that way, and blocks on a red one only under CCK_TEST_FIRST=strict); the earlier
# lines are the evidence. Statuses: passed · failed · timeout (killed at
# CCK_TEST_RUN_TIMEOUT, else the declared "timeout", else 60s, with its whole
# process group) · error (command not found or not executable).
#
# Why its own log and not the quality gate's state: gate-state.sh keys one check
# scope per file path, and quality-gate.sh gates test files too (calc.test.ts is a
# .ts file it typechecks). A test result recorded there against the test file's
# path would replace the gate's own record for it, and a passing test would erase
# a failing typecheck — a stop that reads clean. stop-gate.sh also re-verifies a
# stale record by re-running quality-gate.sh, never this hook. Separate states,
# and neither hook is touched (tasks/decisions.md → ADR-025).
#
# A test that was green the first time it ran this session gets one line of
# context: it has never been red, so it is not yet evidence of anything. Advisory
# in both profiles — no hook can watch a test fail for you.
#

set -uo pipefail

INPUT=$(cat)
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
source "$HOOK_LIB/json-parse.sh"
source "$HOOK_LIB/test-paths.sh"
source "$HOOK_LIB/project-commands.sh"
source "$HOOK_LIB/run-with-timeout.sh"

TOOL_NAME=$(parse_json_field "tool_name")
case "$TOOL_NAME" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(parse_json_field "file_path")
[ -n "$FILE_PATH" ] || exit 0
[ -f "$FILE_PATH" ] || exit 0

# The session's own project: one log, read by one Stop gate. An edit into another
# worktree is not followed the way quality-gate.sh follows it (ADR-024) — the
# declared command belongs to this project and runs from its root.
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

# Nothing declared → nothing to run, and no python3 → no way to read the
# declaration. Either way this hook is silent. Checked first: it costs one
# python3 and skips the disk walk below for every project that hasn't opted in.
CMD=$(project_command "$ROOT" test-file)
[ -n "$CMD" ] || exit 0
# Without the placeholder the command would run the whole suite on every edit.
# That value is a config error, which quality-gate.sh reports; here it is off.
case "$CMD" in *'{file}'*) ;; *) exit 0 ;; esac

# Physical paths, so `..` and symlinks can't move a file in or out of the project.
# Both the edited file and its test must live inside it: the command runs from the
# project root, and a path outside it is not this project's test.
ROOT_P=$(cd "$ROOT" 2>/dev/null && pwd -P) || exit 0
FILE_DIR_P=$(cd "$(dirname "$FILE_PATH")" 2>/dev/null && pwd -P) || exit 0
FILE_P="$FILE_DIR_P/$(basename "$FILE_PATH")"
case "$FILE_DIR_P/" in "$ROOT_P"/*) ;; *) exit 0 ;; esac

# The test to run: the edited file when it is one, else the test that covers it.
# No test on disk → nothing is run and nothing is logged. test-first.sh already
# says "this file owes a test", and two hooks saying it would nag twice per edit.
SOURCE_REL="-"
if test_file_name "$FILE_P"; then
  TEST_P="$FILE_P"
elif test_source_candidate "$FILE_P"; then
  TEST_P=$(test_path_for "$FILE_P") || exit 0
  SOURCE_REL="${FILE_P#"$ROOT_P"/}"
else
  exit 0
fi
case "$TEST_P" in "$ROOT_P"/*) ;; *) exit 0 ;; esac
TEST_REL="${TEST_P#"$ROOT_P"/}"

STATE_DIR="$ROOT/.hook-state"
LOG="$STATE_DIR/test-run-log.tsv"
TAB=$'\t'

SID=$(parse_json_field "session_id")
SID="${SID//[[:space:]]/_}"
SID="${SID:--}"

# No state directory → no log to keep. Nothing here blocks, so a project whose
# .hook-state can't be written loses the record, not the edit.
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
[ -f "$STATE_DIR/.gitignore" ] || { printf '*\n!.gitignore\n' >"$STATE_DIR/.gitignore"; } 2>/dev/null || true

# Hard time limit, in this order: the env var, the project's declared timeout
# (the same budget it sets for the per-edit check), then 60s. A test that outruns
# it is logged "timeout" — too slow for this gate, which is not the same as red.
TIMEOUT="${CCK_TEST_RUN_TIMEOUT:-}"
case "$TIMEOUT" in ''|*[!0-9]*|0) TIMEOUT="" ;; esac
if [ -z "$TIMEOUT" ]; then
  TIMEOUT=$(project_commands_timeout "$ROOT")
  case "$TIMEOUT" in ''|*[!0-9]*|0) TIMEOUT=60 ;; esac
fi

# The path goes into a shell command, so it is single-quoted and every quote in it
# is closed and reopened: a file called `we'ird name.ts` must not end the quoting
# and run the rest as code.
shell_quote() {
  local s="$1" q="'"
  s=${s//$q/$q\\$q$q}   # a quote closes the quoting, escapes itself, reopens it
  printf "%s%s%s" "$q" "$s" "$q"
}
RUN_CMD="${CMD//\{file\}/$(shell_quote "$TEST_REL")}"

# Output to a file, not a pipe: a process the test leaves behind could hold a pipe
# open and keep this hook waiting past the time limit.
OUT_FILE="$STATE_DIR/.test-run-output.$$"
: >"$OUT_FILE" 2>/dev/null || OUT_FILE=""
if [ -n "$OUT_FILE" ]; then
  run_with_timeout "$TIMEOUT" sh -c "cd $(shell_quote "$ROOT_P") && $RUN_CMD" >"$OUT_FILE" 2>&1
  RC=$?
  OUT=$(tail -c 1500 "$OUT_FILE" 2>/dev/null) || OUT=""
  rm -f "$OUT_FILE" 2>/dev/null || true
else
  OUT=$(run_with_timeout "$TIMEOUT" sh -c "cd $(shell_quote "$ROOT_P") && $RUN_CMD" 2>&1)
  RC=$?
fi

REASON=""
case "$RC" in
  0)   STATUS="passed" ;;
  124) STATUS="timeout"; REASON="killed after ${TIMEOUT}s" ;;
  126) STATUS="error";   REASON="command not executable" ;;
  127) STATUS="error";   REASON="command not found" ;;
  *)   STATUS="failed" ;;
esac

# Asked before the line is appended: has this test run at all this session? The
# log is never deduped, so "the first status logged for it" is the whole question.
FIRST_RUN=1
if [ -f "$LOG" ] && grep -qF -- "$SID$TAB$TEST_REL$TAB" "$LOG" 2>/dev/null; then
  FIRST_RUN=0
fi

DETAIL="$RUN_CMD${REASON:+ ($REASON)}"
DETAIL="${DETAIL//$TAB/ }"
DETAIL="${DETAIL//$'\n'/ }"
DETAIL="${DETAIL:0:300}"
{ printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$SID" "$TEST_REL" "$SOURCE_REL" "$STATUS" "$(date +%s)" "${DETAIL:--}" >>"$LOG"; } 2>/dev/null || true

MSG=""
case "$STATUS" in
  failed|timeout|error)
    MSG="The related test is $STATUS: $TEST_REL ($RUN_CMD)${REASON:+ — $REASON}."
    TAIL=$(printf '%s' "$OUT" | tr -d '\000' | tail -c 1200)
    [ -n "${TAIL// /}" ] && MSG="$MSG"$'\n'"$TAIL"
    MSG="$MSG"$'\n'"This is the red bar: make it pass before calling the task done (agent_docs/testing.md → Test-First). The edit is not blocked; under --profile strict, test-first-gate.sh holds the stop until this test is green."
    ;;
  passed)
    if [ "$FIRST_RUN" = 1 ]; then
      MSG="$TEST_REL passed the first time it ran this session: it never went red. A test that is green before the code it tests is not yet evidence: it may assert nothing, or pin something that was already true. Break what it claims to pin, watch it fail, then put it back (agent_docs/testing.md → Test-First). Nothing is blocked."
    fi
    ;;
esac

# json_str (lib/json-parse.sh) builds the string body without python3, so the
# message survives a project where python3 is unusable.
if [ -n "$MSG" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$(json_str "$MSG")"
fi
exit 0
