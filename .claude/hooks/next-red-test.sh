#!/usr/bin/env bash
#
# next-red-test.sh — SessionEnd hook
#
# A session that ends with a test red ends mid-loop. Write that test's name into
# the handoff the next session reads (CLAUDE.md step 3 → the latest
# tasks/handoff-*.md), with the command that re-runs it, so the next session
# starts at the red bar instead of re-deriving where this one stopped. Ending
# deliberately on a failing test is the oldest trick in the TDD book; the only
# part a hook can do is make sure the name survives the session.
#
# Source: .hook-state/test-run-log.tsv through test_run_red (lib/test-run-log.sh)
# — the latest line for a test is its verdict, so a test that went red and then
# green is not reported. Nothing red → nothing written, and no file created: the
# existence of a handoff is itself the signal that a session was interrupted, and
# a file written on every clean exit would make that signal worthless.
#
# The re-run command comes from .claude/commands.json → "test-file" with {file}
# substituted (lib/project-commands.sh); without a declared command the logged
# one is quoted instead.
#
# Runs beside session-end.sh (the scorecard) and journal-fold.sh (which folds the
# journal and the agent scratchpad into the same file). Its own hook rather than
# a branch inside journal-fold.sh, which exits early when there is nothing to
# fold — a red test is worth a handoff even when nothing else is.
#
# Written through redact_secrets: the logged detail is the command that ran, and
# a command line can carry a token (TAN-4733, the rule journal-fold.sh follows).
#
# Always exits 0. Never blocks anything — the session is already over.
#

set -uo pipefail

INPUT=$(cat)
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_LIB="$HOOK_DIR/lib"

[ -r "$HOOK_LIB/test-run-log.sh" ] || exit 0
source "$HOOK_LIB/test-run-log.sh"
# Optional: without them the section still names the test, which is the point.
# shellcheck source=/dev/null
[ -r "$HOOK_LIB/project-commands.sh" ] && source "$HOOK_LIB/project-commands.sh"
# shellcheck source=/dev/null
[ -r "$HOOK_LIB/redact-secrets.sh" ] && source "$HOOK_LIB/redact-secrets.sh"
declare -F redact_secrets >/dev/null 2>&1 || redact_secrets() { cat; }

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
RUNLOG="$ROOT/.hook-state/test-run-log.tsv"
TAB=$'\t'

# session_id, the same way journal-fold.sh reads it (and the same fallback, so
# both hooks of one session write to one file).
SESSION_ID=""
if command -v python3 >/dev/null 2>&1; then
  SESSION_ID=$(printf '%s' "$INPUT" | python3 -c "import sys,json
try:
    d = json.load(sys.stdin)
    sys.stdout.write(d.get('session_id', '') or '')
except Exception:
    pass" 2>/dev/null || true)
fi
[ -n "$SESSION_ID" ] || SESSION_ID=$(date -u +%Y%m%d-%H%M%S)

RED=$(test_run_red "$RUNLOG" "$ROOT" "${SESSION_ID//[[:space:]]/_}") || exit 0
[ -n "$RED" ] || exit 0

CMD=""
if declare -F project_command >/dev/null 2>&1; then
  CMD=$(project_command "$ROOT" test-file 2>/dev/null) || CMD=""
  case "$CMD" in *'{file}'*) ;; *) CMD="" ;; esac
fi

HANDOFF="$ROOT/tasks/handoff-${SESSION_ID}.md"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mkdir -p "$ROOT/tasks" 2>/dev/null || exit 0

{
  echo ""
  echo "## Next: the red bar — from test-run-log.tsv on $NOW"
  echo ""
  echo "This session ended with these tests red. Start here: run the test, watch it"
  echo "fail, then make it pass (agent_docs/testing.md → Test-First)."
  echo ""
  while IFS="$TAB" read -r t st src detail; do
    [ -n "${t:-}" ] || continue
    printf -- '- `%s` — %s' "$t" "$st"
    [ "${src:--}" = "-" ] || printf ' (covers `%s`)' "$src"
    echo ""
    if [ -n "$CMD" ]; then
      echo "  - re-run: \`${CMD//\{file\}/$t}\`"
    elif [ "${detail:--}" != "-" ]; then
      echo "  - last run: \`$detail\`"
    fi
  done <<<"$RED"
  echo ""
} | redact_secrets >>"$HANDOFF" 2>/dev/null || true

exit 0
