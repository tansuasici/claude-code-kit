#!/usr/bin/env bash
#
# stop-gate.sh — Stop hook
#
# Blocks completion (exit 2) while any file edited this session has no passing
# quality gate: its check failed, timed out or errored, or the file changed after
# its last check and still doesn't pass. Reads the per-file state quality-gate.sh
# keeps (.hook-state/quality-gate-state.json, lib/gate-state.sh); falls back to
# the `.hook-state/last_quality_gate.json` summary when only that exists.
# Replaces the prompt rule "Verification (Mandatory Order)" — which the agent can
# ignore — with deterministic enforcement.
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

# Read the verdict for the checkout this session is working in: the payload's cwd
# follows Claude into a git worktree (CLAUDE_PROJECT_DIR does not), and
# quality-gate.sh stores a worktree's results in that worktree (lib/roots.sh).
ROOT=$(hook_project_root "$(parse_json_field "cwd")")
STATE_FILE="$ROOT/.hook-state/last_quality_gate.json"
STATE_V2="$ROOT/.hook-state/quality-gate-state.json"

# No state → no gated edits happened (or hooks weren't wired) → allow stop
[ -f "$STATE_V2" ] || [ -f "$STATE_FILE" ] || exit 0

# Escape hatch (either name works). Marked in quality-gate-history.json so
# session-end.sh can surface skip_gate_used in the scorecard.
if [ "${CLAUDE_SKIP_QUALITY_GATE:-0}" = "1" ] || [ "${SKIP_QUALITY_GATE:-0}" = "1" ]; then
  bump_counter "$ROOT/.hook-state/quality-gate-history.json" "skip_gate_used"
  echo "stop-gate: bypassed via SKIP_QUALITY_GATE" >&2
  exit 0
fi

rel() { printf '%s' "${1#"$ROOT"/}"; }
dash() { [ "$1" = "-" ] || printf '%s' "$1"; }

BLOCK_LIST=""
UNVERIFIED=""
SHOWN_STATE="$STATE_FILE"

if [ -f "$STATE_V2" ] && command -v python3 &>/dev/null; then
  SHOWN_STATE="$STATE_V2"
  CONFIG_OK=1
  [ -n "$(project_commands_error "$ROOT")" ] && CONFIG_OK=0
  LINES=$(gate_state_lines "$STATE_V2" "$CONFIG_OK")

  # Re-verify stale files through quality-gate.sh — one per check scope (a
  # scope-wide re-run covers the rest), at most 3 to bound the stop. Its output
  # is swallowed: the refreshed state is what counts.
  STALE=$(awk -F'\t' '$1 == "stale" && !seen[$3]++ && n++ < 3 { print $2 }' <<<"$LINES")
  if [ -n "$STALE" ]; then
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      PAYLOAD=$(python3 -c 'import json, sys; print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": sys.argv[1]}}))' "$f")
      printf '%s' "$PAYLOAD" | bash "$HOOK_DIR/quality-gate.sh" >/dev/null 2>&1 || true
    done <<<"$STALE"
    LINES=$(gate_state_lines "$STATE_V2" "$CONFIG_OK")
  fi

  while IFS=$'\t' read -r kind a b c d; do
    case "$kind" in
      block)
        c=$(dash "$c"); d=$(dash "$d")
        BLOCK_LIST="${BLOCK_LIST}  - $(rel "$b") — $a: ${c}${d:+ ($d)}"$'\n'
        ;;
      stale)
        c=$(dash "$c")
        BLOCK_LIST="${BLOCK_LIST}  - $(rel "$a") — stale: changed since its last check${c:+ ($c)} and not re-verified"$'\n'
        ;;
      unverified)
        UNVERIFIED="${UNVERIFIED}$(rel "$a") ($(dash "$b")); "
        ;;
    esac
  done <<<"$LINES"
else
  # Only the summary exists (no python3, or state from before per-file results).
  STATUS=""
  if command -v python3 &>/dev/null; then
    STATUS=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("status",""))' "$STATE_FILE" 2>/dev/null || true)
  elif command -v jq &>/dev/null; then
    STATUS=$(jq -r '.status // ""' "$STATE_FILE" 2>/dev/null || true)
  else
    STATUS=$(grep -oE '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' || true)
  fi
  case "$STATUS" in
    failed|timeout|error) BLOCK_LIST="  - last quality gate did not pass (status: $STATUS)"$'\n' ;;
  esac
fi

if [ -n "$BLOCK_LIST" ]; then
  bump_counter "$ROOT/.hook-state/hook-firings.json" "stop-gate"
  cat <<EOF >&2
BLOCKED by stop-gate.sh: the quality gate has not passed for every file edited this session.
${BLOCK_LIST}State: $SHOWN_STATE

Fix the failing check and re-run, or set SKIP_QUALITY_GATE=1 if the
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
if [ -f "$LEDGER" ] && command -v python3 &>/dev/null; then
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
