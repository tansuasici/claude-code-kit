#!/usr/bin/env bash
#
# stop-gate.sh — Stop hook
#
# Blocks completion (exit 2) while any file edited this session has no passing
# quality gate: its check failed, timed out or errored, its result could not be
# recorded, or the file changed after its last check and still doesn't pass.
# Reads the per-file state quality-gate.sh keeps (.hook-state/quality-gate-state.json,
# lib/gate-state.sh); falls back to the `.hook-state/last_quality_gate.json`
# summary when only that exists or no usable python3 can read the per-file state.
# Replaces the prompt rule "Verification (Mandatory Order)" — which the agent can
# ignore — with deterministic enforcement.
#
# Fails closed: a gate state that exists but can't be read — a torn or edited
# file, a reader that errors — blocks with a message saying how to reset it. It is
# never read as "nothing failed".
#
# Stale files — changed after their check by Bash, a formatter or codegen, or
# whose check never finished — are re-verified here by re-running quality-gate.sh
# on them (one file per check scope, at most 3), so an old pass never stands for
# new code.
#
# Files no check covers (skipped: unsupported language, tool not installed) don't
# block — quality-gate.sh told Claude at edit time that they are NOT verified —
# and never count as passed.
#
# Escape hatch: set CLAUDE_SKIP_QUALITY_GATE=1 (or SKIP_QUALITY_GATE=1) for
# the session when test infrastructure is broken or an intentional ship is
# in progress. Recording the bypass reason in tasks/decisions.md or
# tasks/handoff.md is strongly recommended.
#
# Runs before task-complete-notify.sh so the notification only fires on
# successful completion.
#

set -euo pipefail

INPUT=$(cat)
[ -n "$INPUT" ] || INPUT='{}'

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_LIB="$HOOK_DIR/lib"
source "$HOOK_LIB/json-parse.sh"
source "$HOOK_LIB/state-counter.sh"
source "$HOOK_LIB/roots.sh"
source "$HOOK_LIB/project-commands.sh"
source "$HOOK_LIB/gate-state.sh"

python3_usable || true  # probe once; the command substitutions below reuse the answer

# Whose verdicts count. The checkout this session is working in: the payload's cwd
# follows Claude into a git worktree (CLAUDE_PROJECT_DIR does not), and
# quality-gate.sh stores a worktree's results in that worktree (lib/roots.sh). And
# the project the session started in: a session that moved into a worktree still
# answers for failures it left in the main checkout. (A stop from the main
# checkout doesn't answer for a subagent's worktree — merging it back does.)
ROOT=$(hook_project_root "$(parse_json_field "cwd")")
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

has_state() { [ -f "$1/.hook-state/quality-gate-state.json" ] || [ -f "$1/.hook-state/last_quality_gate.json" ]; }

# No state → no gated edits happened (or hooks weren't wired) → allow stop
if ! has_state "$ROOT" && ! has_state "$PROJECT_DIR"; then
  exit 0
fi

# Escape hatch (either name works). Marked in quality-gate-history.json so
# session-end.sh can surface skip_gate_used in the scorecard.
if [ "${CLAUDE_SKIP_QUALITY_GATE:-0}" = "1" ] || [ "${SKIP_QUALITY_GATE:-0}" = "1" ]; then
  bump_counter "$ROOT/.hook-state/quality-gate-history.json" "skip_gate_used"
  echo "stop-gate: bypassed via SKIP_QUALITY_GATE" >&2
  exit 0
fi

rel() { printf '%s' "${2#"$1"/}"; }  # rel ROOT PATH
dash() { [ "$1" = "-" ] || printf '%s' "$1"; }

BLOCK_LIST=""
UNVERIFIED=""
SHOWN_STATE=""
UNREADABLE=""

# check_root ROOT — add ROOT's blocking files to BLOCK_LIST and its unverified
# ones to UNVERIFIED.
check_root() {
  local root="$1"
  local state_file="$root/.hook-state/last_quality_gate.json"
  local state_v2="$root/.hook-state/quality-gate-state.json"
  local blocks="" shown lines config_ok stale f payload status kind a b c d
  has_state "$root" || return 0

  if [ -f "$state_v2" ] && python3_usable; then
    shown="$state_v2"
    config_ok=1
    if [ -n "$(project_commands_error "$root")" ]; then
      config_ok=0
    fi
    # On failure gate_state_lines prints an "error" line, which blocks below.
    if lines=$(gate_state_lines "$state_v2" "$config_ok"); then
      # Re-verify stale files through quality-gate.sh — one per check scope (a
      # scope-wide re-run covers the rest), at most 3 to bound the stop. Its output
      # is swallowed: the refreshed state is what counts.
      stale=$(awk -F'\t' '$1 == "stale" && !seen[$3]++ && n++ < 3 { print $2 }' <<<"$lines")
      if [ -n "$stale" ]; then
        while IFS= read -r f; do
          [ -n "$f" ] || continue
          payload=$(python3 -c 'import json, sys; print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": sys.argv[1]}}))' "$f")
          printf '%s' "$payload" | bash "$HOOK_DIR/quality-gate.sh" >/dev/null 2>&1 || true
        done <<<"$stale"
        lines=$(gate_state_lines "$state_v2" "$config_ok") || true
      fi
    fi

    while IFS=$'\t' read -r kind a b c d; do
      case "$kind" in
        block)
          c=$(dash "$c"); d=$(dash "$d")
          blocks="${blocks}  - $(rel "$root" "$b") — $a: ${c}${d:+ ($d)}"$'\n'
          ;;
        stale)
          c=$(dash "$c")
          blocks="${blocks}  - $(rel "$root" "$a") — stale: changed since its last check${c:+ ($c)} and not re-verified"$'\n'
          ;;
        unrecorded)
          blocks="${blocks}  - $(rel "$root" "$a") — its check result could not be recorded"$'\n'
          ;;
        error)
          blocks="${blocks}  - $a"$'\n'
          UNREADABLE="${UNREADABLE}  $root/.hook-state/"$'\n'
          ;;
        unverified)
          UNVERIFIED="${UNVERIFIED}$(rel "$root" "$a") ($(dash "$b")); "
          ;;
      esac
    done <<<"$lines"
  else
    # Only the summary to go on (no usable python3, or no per-file state). A
    # summary that is missing or can't be read blocks: it may record a failure.
    shown="$state_file"
    status=""
    if [ -f "$state_file" ]; then
      if python3_usable; then
        status=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("status",""))' "$state_file" 2>/dev/null) || status=""
      elif command -v jq &>/dev/null; then
        status=$(jq -r '.status // ""' "$state_file" 2>/dev/null) || status=""
      else
        status=$(grep -oE '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$state_file" | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' || true)
      fi
    fi
    case "$status" in
      failed|timeout|error)
        blocks="  - last quality gate did not pass (status: $status)"$'\n'
        ;;
      "")
        blocks="  - the gate state can't be read: $(basename "$state_file") is missing or unreadable"
        if [ -f "$state_v2" ]; then
          blocks="$blocks, and there is no usable python3 to read $(basename "$state_v2")"
        fi
        blocks="$blocks"$'\n'
        UNREADABLE="${UNREADABLE}  $root/.hook-state/"$'\n'
        ;;
    esac
  fi

  if [ -n "$blocks" ]; then
    BLOCK_LIST="${BLOCK_LIST}${blocks}"
    SHOWN_STATE="${SHOWN_STATE}State: $shown"$'\n'
  fi
}

check_root "$ROOT"
if [ "$PROJECT_DIR" != "$ROOT" ]; then
  check_root "$PROJECT_DIR"
fi

if [ -n "$BLOCK_LIST" ]; then
  bump_counter "$ROOT/.hook-state/hook-firings.json" "stop-gate"
  RESET_HELP=""
  if [ -n "$UNREADABLE" ]; then
    RESET_HELP="The gate state is unreadable, so the failures it may record can't be ruled out.
To reset it, delete quality-gate-state.json and last_quality_gate.json in
${UNREADABLE}(a new session also resets them), then save the files you edited again so
their checks re-run.
"
  fi
  cat <<EOF >&2
BLOCKED by stop-gate.sh: the quality gate has not passed for every file edited this session.
${BLOCK_LIST}${SHOWN_STATE}
${RESET_HELP}Fix the failing check and re-run, or set SKIP_QUALITY_GATE=1 if the
failure is unrelated to your change (e.g. broken test infrastructure).
EOF
  exit 2
fi

if [ -n "$UNVERIFIED" ]; then
  echo "stop-gate: code changed without a passing check (no check covers it — NOT verified): ${UNVERIFIED%; }" >&2
fi

# Non-blocking nudge: the kit mandates a smoke test (CLAUDE.md → Verification
# step 4), but it's manual and a hook can't run it. If verification ran this
# session (ledger has entries) but no smoke-test result is recorded, remind once
# — never block (smoke testing stays a manual step).
LEDGER="$ROOT/.hook-state/verification-ledger.json"
if [ -f "$LEDGER" ] && python3_usable; then
  NEED_SMOKE=$(python3 -c '
import json,sys
try:
    d=json.load(open(sys.argv[1]))
    print("1" if (d.get("entries") and d.get("smoke_test") is None) else "0")
except Exception:
    print("0")' "$LEDGER" 2>/dev/null || echo 0)
  if [ "$NEED_SMOKE" = "1" ]; then
    echo "stop-gate: reminder — auto-gates passed but no smoke-test result is recorded (CLAUDE.md → Verification step 4 is manual). Record it with /verification-status. Non-blocking." >&2
  fi
fi

exit 0
