#!/usr/bin/env bash
#
# subagent-post.sh — PostToolUse hook (matcher: Task)
#
# Closes the most recent OPEN telemetry row for the finishing sub-agent in
# .hook-state/agent-invocations.jsonl: sets finished_at, duration_seconds,
# and status=closed (outcome defaults to "completed"). Pairs with
# subagent-pre.sh; /scorecard rolls these up per-agent (CLA-38).
#
# Never blocks. Always exits 0. No-op when there is no open row to close.
#

set -uo pipefail

INPUT=$(cat)
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
# shellcheck source=/dev/null
source "$HOOK_LIB/json-parse.sh"

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
LOG="$ROOT/.hook-state/agent-invocations.jsonl"
[ -f "$LOG" ] || exit 0

AGENT=$(parse_json_field "subagent_type" 2>/dev/null || true)
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
NOW_EPOCH=$(date +%s)

command -v python3 &>/dev/null || exit 0

python3 - "$LOG" "$AGENT" "$NOW" "$NOW_EPOCH" <<'PY' 2>/dev/null || true
import json, os, sys
log, agent, now, epoch = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
try:
    with open(log) as f:
        lines = [ln.rstrip("\n") for ln in f]
except FileNotFoundError:
    sys.exit(0)

# Parse each line; keep unparseable lines verbatim so nothing is lost.
parsed = []
for ln in lines:
    s = ln.strip()
    if not s:
        parsed.append(("raw", ln))
        continue
    try:
        parsed.append(("json", json.loads(s)))
    except Exception:
        parsed.append(("raw", ln))

# Find the last OPEN row, preferring one whose agent matches (if known).
idx = None
for i in range(len(parsed) - 1, -1, -1):
    kind, val = parsed[i]
    if kind == "json" and val.get("status") == "open" and (not agent or val.get("agent") == agent):
        idx = i
        break
if idx is None:
    sys.exit(0)

val = parsed[idx][1]
val["finished_at"] = now
start = val.get("started_epoch")
if isinstance(start, int):
    val["duration_seconds"] = max(0, epoch - start)
val["status"] = "closed"
val.setdefault("outcome", "completed")

tmp = log + ".tmp"
with open(tmp, "w") as f:
    for kind, v in parsed:
        f.write((json.dumps(v) if kind == "json" else v) + "\n")
os.replace(tmp, log)
PY

exit 0
