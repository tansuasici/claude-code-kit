#!/usr/bin/env bash
#
# test-first-gate.sh — Stop hook
#
# Blocks completion (exit 2) while a source file this session edited still owes a
# test, or while a test this session ran is still red — but ONLY under the strict
# profile (CCK_TEST_FIRST=strict, set by
# scripts/gen-strict-settings.sh). In the default profile the discipline is
# advisory: test-first.sh already said it once at edit time, and this hook exits
# 0 without a word.
#
# Two sources, one question — is the test-first loop closed?
#
#   .hook-state/test-first-pending.tsv   (test-first.sh) source files with no
#       test behind them, session<TAB>file<TAB>epoch. Every line is re-asked of
#       the disk: a test that appeared without an Edit — Bash, a generator, a
#       merge, a checkout — settles the record. The list is a reminder of what to
#       re-check, never the verdict itself.
#   .hook-state/test-run-log.tsv         (test-run.sh) what the related tests did
#       when they ran, append-only. The latest line for a test is its verdict and
#       the earlier ones are its history, so a session that went red and then
#       green is a finished loop, not a blocked stop.
#
# Whose records: the Stop payload's session_id. A stop answers for the files its
# own session edited; a record or a stop without a session id counts everywhere
# (fail closed), the same rule stop-gate.sh applies.
#
# Escape hatch: SKIP_TEST_FIRST=1 (or CLAUDE_SKIP_TEST_FIRST=1) for the session —
# a refactor, a spike, or work on code whose tests live somewhere this hook
# cannot see. SKIP_QUALITY_GATE=1 also covers it: a session that has turned the
# quality gate off is not being held to the stricter rule.
#
# Advisory by default means advisory everywhere outside strict: before the
# profile is read, nothing in this hook can block, and its failure trap is armed
# only in strict mode.
#
# Registered beside stop-gate.sh under Stop. Nothing here depends on the order
# Claude Code runs them in: this hook reads its own state and reaches its own
# verdict, and a block from either one is a block.
#

set -uo pipefail

STRICT=0
[ "${CCK_TEST_FIRST:-}" = "strict" ] && STRICT=1
[ "$STRICT" = "1" ] || exit 0

# Fail closed, but only where this hook is allowed to block at all: in strict
# mode an unexpected error must not read as "allowed".
on_exit() {
  local rc=$?
  if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then
    echo "BLOCKED by test-first-gate.sh: the test-first check itself failed (exit $rc), so the Test List can't be confirmed. Set SKIP_TEST_FIRST=1 to bypass while it is broken." >&2
    exit 2
  fi
}
trap on_exit EXIT

for var in "${SKIP_TEST_FIRST:-0}" "${CLAUDE_SKIP_TEST_FIRST:-0}" \
           "${SKIP_QUALITY_GATE:-0}" "${CLAUDE_SKIP_QUALITY_GATE:-0}"; do
  [ "$var" = "1" ] && exit 0
done

INPUT=$(cat)
[ -n "$INPUT" ] || INPUT='{}'
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_LIB="$HOOK_DIR/lib"

# A missing library is not "no files owe a test": without test_exists_for every
# record would be skipped and the stop would read as clean. Say so and block,
# the same way stop-gate.sh turns unreadable state into an error status.
for lib in json-parse.sh test-paths.sh; do
  [ -r "$HOOK_LIB/$lib" ] && continue
  echo "BLOCKED by test-first-gate.sh: $HOOK_LIB/$lib is missing or unreadable, so the Test List can't be confirmed. Reinstall the hooks (./scripts/doctor.sh) or set SKIP_TEST_FIRST=1 to bypass while it is broken." >&2
  exit 2
done
source "$HOOK_LIB/json-parse.sh"
source "$HOOK_LIB/test-paths.sh"

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
PENDING="$ROOT/.hook-state/test-first-pending.tsv"
RUNLOG="$ROOT/.hook-state/test-run-log.tsv"

SID=$(parse_json_field "session_id")
SID="${SID//[[:space:]]/_}"
SID="${SID:--}"
TAB=$'\t'
NL=$'\n'

# ours SESSION — a record counts for this stop: its own session, or either side
# has none (fail closed).
ours() { [ "$SID" = "-" ] || [ "$1" = "-" ] || [ "$1" = "$SID" ]; }

# A state file that exists but can't be read is not an empty one: skipping it
# would drop every record and the stop would read as clean. Say so and block,
# the same way stop-gate.sh turns unreadable state into an error status.
unreadable() {
  echo "BLOCKED by test-first-gate.sh: $1 exists but is unreadable, so what this session owes can't be read. Fix its permissions or set SKIP_TEST_FIRST=1 to bypass." >&2
  exit 2
}

# Source files that still owe a test.
OWED=""
COUNT=0
if [ -f "$PENDING" ]; then
  [ -r "$PENDING" ] || unreadable "$PENDING"
  while IFS="$TAB" read -r s f _; do
    [ -n "${f:-}" ] || continue
    ours "${s:--}" || continue
    [ -f "$f" ] || continue          # deleted since — nothing left to test
    test_source_candidate "$f" || continue
    test_exists_for "$f" && continue # a test appeared after the record
    case "$f" in "$ROOT"/*) f="${f#"$ROOT"/}" ;; esac
    case "$NL$OWED" in *"$NL$f$NL"*) continue ;; esac
    OWED="$OWED$f$NL"
    COUNT=$((COUNT + 1))
  done <"$PENDING"
fi

# Tests that ran and are not green. Read newest line first, so the first line
# seen for a test is its latest run and the rest are history.
RED=""
RED_COUNT=0
if [ -f "$RUNLOG" ]; then
  [ -r "$RUNLOG" ] || unreadable "$RUNLOG"
  SEEN="$NL"
  while IFS="$TAB" read -r s t _ st _; do
    [ -n "${t:-}" ] || continue
    ours "${s:--}" || continue
    case "$NL$SEEN" in *"$NL$t$NL"*) continue ;; esac
    SEEN="$SEEN$t$NL"
    case "${st:-}" in failed|timeout|error) ;; *) continue ;; esac
    [ -f "$ROOT/$t" ] || continue    # the test was deleted since
    RED="$RED$t — $st$NL"
    RED_COUNT=$((RED_COUNT + 1))
  done <<<"$(sed -n '1!G;h;$p' "$RUNLOG" 2>/dev/null)"
fi

if [ "$COUNT" = 0 ] && [ "$RED_COUNT" = 0 ]; then
  exit 0
fi

{
  if [ "$COUNT" -gt 0 ]; then
    echo "BLOCKED by test-first-gate.sh: $COUNT file(s) this session edited have no test."
    echo ""
    printf '%s' "$OWED" | sed 's/^/  - /'
    echo ""
    echo "Write the named failing test for each, watch it fail, then make it pass"
    echo "(agent_docs/testing.md → Test-First). If a file is not meant to have one —"
    echo "a refactor, config, a spike — set SKIP_TEST_FIRST=1 for this session and say"
    echo "why in tasks/handoff.md."
  fi
  if [ "$RED_COUNT" -gt 0 ]; then
    [ "$COUNT" -gt 0 ] && echo ""
    echo "BLOCKED by test-first-gate.sh: $RED_COUNT test(s) this session ran are not green."
    echo ""
    printf '%s' "$RED" | sed 's/^/  - /'
    echo ""
    echo "A failing test is the loop unfinished: make it pass, then stop. A timeout or"
    echo "an error is the command, not the code — fix .claude/commands.json → test-file,"
    echo "or set SKIP_TEST_FIRST=1 for this session and say why in tasks/handoff.md."
  fi
} >&2
exit 2
