#!/usr/bin/env bash
#
# stop-gate.sh — Stop hook
#
# Reads `.hook-state/last_quality_gate.json` and blocks completion (exit 2)
# when the last verification run failed. Replaces the prompt rule
# "Verification (Mandatory Order)" — which the agent can ignore — with
# deterministic enforcement.
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

# Consume stdin (hook protocol)
cat > /dev/null

HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
source "$HOOK_LIB/state-counter.sh"

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_FILE="$ROOT/.hook-state/last_quality_gate.json"

# No state → no edits happened (or hooks weren't wired) → allow stop
[ ! -f "$STATE_FILE" ] && exit 0

# Escape hatch (either name works). Marked in quality-gate-history.json so
# session-end.sh can surface skip_gate_used in the scorecard.
if [ "${CLAUDE_SKIP_QUALITY_GATE:-0}" = "1" ] || [ "${SKIP_QUALITY_GATE:-0}" = "1" ]; then
  bump_counter "$ROOT/.hook-state/quality-gate-history.json" "skip_gate_used"
  echo "stop-gate: bypassed via SKIP_QUALITY_GATE" >&2
  exit 0
fi

# Extract status
STATUS=""
if command -v python3 &>/dev/null; then
  STATUS=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("status",""))' "$STATE_FILE" 2>/dev/null || true)
elif command -v jq &>/dev/null; then
  STATUS=$(jq -r '.status // ""' "$STATE_FILE" 2>/dev/null || true)
else
  STATUS=$(grep -oE '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' || true)
fi

if [ "$STATUS" = "failed" ]; then
  bump_counter "$ROOT/.hook-state/hook-firings.json" "stop-gate"
  cat <<EOF >&2
BLOCKED by stop-gate.sh: last quality gate did not pass.
State: $STATE_FILE

Fix the failing check and re-run, or set SKIP_QUALITY_GATE=1 if the
failure is unrelated to your change (e.g. broken test infrastructure).
EOF
  exit 2
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
