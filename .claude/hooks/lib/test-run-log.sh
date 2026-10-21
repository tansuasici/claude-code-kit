#!/usr/bin/env bash
#
# test-run-log.sh — read .hook-state/test-run-log.tsv (written by test-run.sh)
#
# Source it:  source "$HOOK_LIB/test-run-log.sh"
#
# The log is append-only, one line per run:
#
#   session<TAB>test<TAB>source<TAB>status<TAB>epoch<TAB>detail
#
# so the LATEST line for a test is its verdict and the earlier ones are its
# history — a test that went red and then green is a finished loop, not a
# failure. Three hooks ask the same question of it (test-first-gate.sh at Stop,
# commit-gate.sh at a check-in, next-red-test.sh at session end), and each
# answering it with its own copy of the reversed read is how the three would
# drift apart.
#
#   test_run_red  <log> <root> <session>
#       One line per test whose latest run is not green, newest first:
#         test<TAB>status<TAB>source<TAB>detail
#       Relative paths, as logged; "-" for an empty field. Statuses: failed ·
#       timeout · error. A test that no longer exists on disk is left out — it
#       was deleted or renamed since it ran, so there is nothing to re-run.
#       Prints nothing and returns 0 when the log is absent or every test is
#       green; returns 1 WITHOUT printing when the log exists but cannot be
#       read. A caller must not read that as "nothing is red": an unreadable
#       log is an unknown verdict (test-first-gate.sh blocks on it).
#
# Whose lines: a record counts for <session> when it carries that session id, or
# when either side has none ("-") — fail closed, the rule stop-gate.sh applies.
#

# _trl_ours RECORD_SESSION SESSION
_trl_ours() { [ "$2" = "-" ] || [ "$1" = "-" ] || [ "$1" = "$2" ]; }

test_run_red() {
  local log="$1" root="$2" sid="$3"
  local s t src st detail seen
  local NL=$'\n' TAB=$'\t'

  [ -f "$log" ] || return 0
  [ -r "$log" ] || return 1

  sid="${sid:--}"
  seen="$NL"
  # Newest line first, so the first line seen for a test is its latest run.
  while IFS="$TAB" read -r s t src st _ detail; do
    [ -n "${t:-}" ] || continue
    _trl_ours "${s:--}" "$sid" || continue
    case "$seen" in *"$NL$t$NL"*) continue ;; esac
    seen="$seen$t$NL"
    case "${st:-}" in failed|timeout|error) ;; *) continue ;; esac
    [ -f "$root/$t" ] || continue
    printf '%s\t%s\t%s\t%s\n' "$t" "$st" "${src:--}" "${detail:--}"
  done <<<"$(sed -n '1!G;h;$p' "$log" 2>/dev/null)"
}
