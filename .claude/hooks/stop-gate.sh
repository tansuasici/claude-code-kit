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

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_FILE="$ROOT/.hook-state/last_quality_gate.json"

# No state → no edits happened (or hooks weren't wired) → allow stop
[ ! -f "$STATE_FILE" ] && exit 0

# Escape hatch (either name works)
if [ "${CLAUDE_SKIP_QUALITY_GATE:-0}" = "1" ] || [ "${SKIP_QUALITY_GATE:-0}" = "1" ]; then
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
  cat <<EOF >&2
BLOCKED by stop-gate.sh: last quality gate did not pass.
State: $STATE_FILE

Fix the failing check and re-run, or set SKIP_QUALITY_GATE=1 if the
failure is unrelated to your change (e.g. broken test infrastructure).
EOF
  exit 2
fi

exit 0
