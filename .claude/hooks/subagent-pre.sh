#!/usr/bin/env bash
#
# subagent-pre.sh — PreToolUse hook (matcher: Task)
#
# Opens an agent-invocation telemetry row when a sub-agent is dispatched:
# appends one JSON line to .hook-state/agent-invocations.jsonl recording
# {agent, task, started_at}. The paired PostToolUse hook (subagent-post.sh)
# closes the row with finished_at + duration. /scorecard rolls these up
# per-agent so you can see which sub-agent runs most and how long it takes
# (CLA-38).
#
# Telemetry must never interfere with the call: this hook never blocks and
# always exits 0, even on malformed input or a missing python3.
#

set -uo pipefail

INPUT=$(cat)
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
# shellcheck source=/dev/null
source "$HOOK_LIB/json-parse.sh"

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.hook-state"
mkdir -p "$STATE_DIR" 2>/dev/null || true
[ -f "$STATE_DIR/.gitignore" ] || printf '*\n!.gitignore\n' >"$STATE_DIR/.gitignore" 2>/dev/null || true

AGENT=$(parse_json_field "subagent_type" 2>/dev/null || true)
DESC=$(parse_json_field "description" 2>/dev/null || true)
[ -n "$AGENT" ] || AGENT="unknown"

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
NOW_EPOCH=$(date +%s)
LOG="$STATE_DIR/agent-invocations.jsonl"

if command -v python3 &>/dev/null; then
  python3 - "$LOG" "$AGENT" "$DESC" "$NOW" "$NOW_EPOCH" <<'PY' 2>/dev/null || true
import json, sys
log, agent, desc, now, epoch = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5])
row = {
    "agent": agent,
    "task": (desc or "")[:120],
    "started_at": now,
    "started_epoch": epoch,
    "status": "open",
}
with open(log, "a") as f:
    f.write(json.dumps(row) + "\n")
PY
else
  # No python3: append a minimal, still-valid row (description omitted to avoid
  # escaping bugs). The scorecard tolerates rows without a task field.
  printf '{"agent":"%s","started_at":"%s","started_epoch":%s,"status":"open"}\n' \
    "$AGENT" "$NOW" "$NOW_EPOCH" >> "$LOG" 2>/dev/null || true
fi

exit 0
