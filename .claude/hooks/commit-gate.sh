#!/usr/bin/env bash
#
# commit-gate.sh — PreToolUse hook (matcher: Bash)
#
# Clean check-in: a commit never carries a check this session already knows is
# red. The quality gate and the test-first gate both answer at Stop — the moment
# the model declares itself done — and `git commit` is the other way out of the
# loop. conventional-commit.sh checks the shape of the message and nothing else,
# so without this hook a commit can carry a file whose typecheck failed two edits
# ago, or a test that is still failing.
#
# Two sources, read-only, both already written by other hooks:
#
#   .hook-state/quality-gate-state.json  through gate_state_lines (lib/gate-state.sh)
#       block · orphan · unrecorded · error → red: a check that ran and did not pass
#       stale                               → named, never blocks (see below)
#       unverified                          → ignored: nothing checks that file, and
#                                             a skipped check is not a failure
#                                             (stop-gate.sh ignores it the same way)
#   .hook-state/test-run-log.tsv         through test_run_red (lib/test-run-log.sh)
#       the latest line for a test is its verdict; red then green is a finished loop
#
# Default profile: exit 0 and say it through PreToolUse additionalContext — the
# commit goes through. Strict profile (CCK_TEST_FIRST=strict, set by
# scripts/gen-strict-settings.sh): exit 2, which routes like a permission deny,
# so the reason on stderr is what Claude reads. One profile switch for one
# discipline — the same variable closes the Stop door in test-first-gate.sh.
#
# It never re-runs a check and never writes state. A stale record (the file
# changed after the check that passed it) is therefore named but never blocks:
# re-verifying costs seconds, and stop-gate.sh owns that budget
# (CCK_STOP_REVERIFY_BUDGET). A commit door that re-runs typechecks is a commit
# door people route around (tasks/decisions.md → ADR-026).
#
# Escape hatches, both session-wide and shared with the gates they belong to:
# SKIP_QUALITY_GATE=1 and SKIP_TEST_FIRST=1 (and their CLAUDE_ forms). A session
# that has turned a gate off is not held to the stricter rule at the commit.
#
# Not read here: the plain per-file log quality-gate.sh keeps when python3 is
# unusable (.hook-state/quality-gate-files.tsv). Without python3 there is no way
# to read the per-file state either, so in strict this hook fails closed and says
# so; stop-gate.sh is the one that reads both and re-verifies.
#
# Also not read here: the other checkouts a session touched. stop-gate.sh walks
# them (.hook-state/quality-gate-roots, ADR-022) because a stop answers for the
# whole session; a commit is made in one checkout, and that checkout's root is
# the one this hook reads. A commit run from a sibling worktree therefore meets
# that worktree's verdict only when CLAUDE_PROJECT_DIR points there — the same
# limit as `git -C dir commit`, which the matcher misses outright.
#
# Matcher shared with conventional-commit.sh (`git\s+commit`), deliberately: two
# hooks in the same array must not disagree about what a commit is. The blind
# spots come with it — `git -C dir commit` is missed, the string inside
# `echo "git commit"` matches.
#

set -uo pipefail

STRICT=0
[ "${CCK_TEST_FIRST:-}" = "strict" ] && STRICT=1

for var in "${SKIP_TEST_FIRST:-0}" "${CLAUDE_SKIP_TEST_FIRST:-0}" \
           "${SKIP_QUALITY_GATE:-0}" "${CLAUDE_SKIP_QUALITY_GATE:-0}"; do
  [ "$var" = "1" ] && exit 0
done

INPUT=$(cat)
[ -n "$INPUT" ] || INPUT='{}'
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_LIB="$HOOK_DIR/lib"

[ -r "$HOOK_LIB/json-parse.sh" ] || exit 0
source "$HOOK_LIB/json-parse.sh"

TOOL_NAME=$(parse_json_field "tool_name")
[ "$TOOL_NAME" != "Bash" ] && exit 0
COMMAND=$(parse_json_field "command")
if ! grep -qE 'git\s+commit' <<<"$COMMAND"; then exit 0; fi

# From here on this IS a check-in, so in strict an unexpected error must not read
# as "clean" — the same fail-closed trap test-first-gate.sh arms only in strict.
on_exit() {
  local rc=$?
  if [ "$STRICT" = "1" ] && [ "$rc" != 0 ] && [ "$rc" != 2 ]; then
    echo "BLOCKED by commit-gate.sh: the check-in check itself failed (exit $rc), so the state of this commit can't be read. Set SKIP_QUALITY_GATE=1 to bypass while it is broken." >&2
    exit 2
  fi
}
trap on_exit EXIT

# A missing library is not "nothing is red". In strict say so and block; by
# default stay silent — a warning is not worth a broken hook's noise.
for lib in gate-state.sh test-run-log.sh project-commands.sh; do
  [ -r "$HOOK_LIB/$lib" ] && continue
  if [ "$STRICT" = "1" ]; then
    echo "BLOCKED by commit-gate.sh: $HOOK_LIB/$lib is missing or unreadable, so this commit's checks can't be read. Reinstall the hooks (./scripts/doctor.sh) or set SKIP_QUALITY_GATE=1 to bypass." >&2
    exit 2
  fi
  exit 0
done
source "$HOOK_LIB/gate-state.sh"
source "$HOOK_LIB/test-run-log.sh"
source "$HOOK_LIB/project-commands.sh"

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE="$ROOT/.hook-state/quality-gate-state.json"
RUNLOG="$ROOT/.hook-state/test-run-log.tsv"

SID=$(parse_json_field "session_id")
SID="${SID//[[:space:]]/_}"
SID="${SID:--}"
TAB=$'\t'
NL=$'\n'

rel() { case "$1" in "$ROOT"/*) printf '%s' "${1#"$ROOT"/}" ;; *) printf '%s' "$1" ;; esac; }
dash() { [ "${1:--}" = "-" ] || printf ' (%s)' "$1"; }

RED=""     # checks that ran and did not pass
STALE=""   # records that no longer cover the file's content

# --- the quality gate's own state ---------------------------------------------
if [ -f "$STATE" ]; then
  if python3_usable; then
    CONFIG_OK=1
    [ -n "$(project_commands_error "$ROOT")" ] && CONFIG_OK=0
    while IFS="$TAB" read -r kind a b c d; do
      case "$kind" in
        block)
          RED="$RED  - $(rel "$b") — $a: ${c:--}$(dash "${d:--}")$NL" ;;
        orphan)
          RED="$RED  - $a: ${c:--} ($b) — every file it covered has since been renamed or deleted; save a file it covers so the check runs again$NL" ;;
        unrecorded)
          RED="$RED  - $(rel "$a") — its check result could not be recorded$NL" ;;
        error|unreadable)
          RED="$RED  - $a$NL" ;;
        stale)
          STALE="$STALE  - $(rel "$a") — stale: changed since its last check$(dash "${c:--}")$NL" ;;
      esac
    done <<<"$(gate_state_lines "$STATE" "$CONFIG_OK" "$SID" || true)"
  elif [ "$STRICT" = "1" ]; then
    RED="$RED  - $STATE can't be read: python3 is missing or doesn't run (on macOS, xcode-select --install)$NL"
  fi
fi

# --- the tests this session ran ------------------------------------------------
if ! RUN_RED=$(test_run_red "$RUNLOG" "$ROOT" "$SID"); then
  RED="$RED  - $RUNLOG exists but is unreadable, so what the tests did can't be read$NL"
  RUN_RED=""
fi
while IFS="$TAB" read -r t st src _; do
  [ -n "${t:-}" ] || continue
  RED="$RED  - $t — $st${src:+ (covers $src)}$NL"
done <<<"$RUN_RED"

[ -n "$RED$STALE" ] || exit 0

# A stale record is not a failed check — it is a check whose answer is older than
# the file. When that is all there is, the message says so in its own words
# rather than borrowing the failure's.
MESSAGE="$RED"
if [ -n "$STALE" ]; then
  [ -n "$RED" ] && MESSAGE="$MESSAGE${NL}Not re-verified here — stop-gate.sh re-verifies a stale record, with a budget:$NL"
  MESSAGE="$MESSAGE$STALE"
fi

if [ "$STRICT" = "1" ] && [ -n "$RED" ]; then
  if [ -r "$HOOK_LIB/state-counter.sh" ]; then
    source "$HOOK_LIB/state-counter.sh"
    bump_counter "$ROOT/.hook-state/hook-firings.json" "commit-gate"
  fi
  cat <<EOF >&2
BLOCKED by commit-gate.sh: this check-in carries work whose checks did not pass.
$MESSAGE
A commit is a claim that the build is not broken (Clean Check-in). Fix the check
or the test and commit again. If the failure is unrelated to this change — broken
test infrastructure, a spike, a refactor — set SKIP_QUALITY_GATE=1 or
SKIP_TEST_FIRST=1 for this session and say why in the commit message.
EOF
  exit 2
fi

if [ -n "$RED" ]; then
  MSG="This commit carries work whose checks did not pass:$NL$MESSAGE${NL}Clean check-in means the commit does not break the build: fix the check or the test first, or say why this commit is an exception. Nothing is blocked here (the strict profile blocks)."
else
  MSG="This commit carries a file whose last check is older than its content:$NL$MESSAGE${NL}Nothing failed — the record just no longer covers what is being committed. Save the file again to re-check it, or leave it: stop-gate.sh re-verifies a stale record at Stop, with a budget. Nothing is blocked here, in either profile."
fi
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "$(json_str "$MSG")"
exit 0
