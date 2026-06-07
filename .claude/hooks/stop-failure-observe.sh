#!/usr/bin/env bash
#
# stop-failure-observe.sh — StopFailure hook
#
# StopFailure fires only when a turn ends on an API-level error (rate limit,
# auth, server error) — NOT on a deliberate stop-gate block (that's a Stop hook
# exit 2). Its stdout and exit code are IGNORED by Claude Code, so this is pure
# side-effect: record the API-error count + the last error string in
# .hook-state/stop-failures.json. The scorecard reads it to distinguish "the
# session died on infra" from "the agent skipped its steps" — context that keeps
# other metrics (lessons_added, gate status) from being misread. Always exits 0.
#
set -euo pipefail

INPUT=$(cat)
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
source "$HOOK_LIB/json-parse.sh"

ERR=$(parse_json_field "error")

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.hook-state"
FILE="$STATE_DIR/stop-failures.json"
mkdir -p "$STATE_DIR" 2>/dev/null || true
[ -f "$STATE_DIR/.gitignore" ] || printf '*\n!.gitignore\n' >"$STATE_DIR/.gitignore" 2>/dev/null || true

if command -v python3 >/dev/null 2>&1; then
  python3 - "$FILE" "$ERR" <<'PY' 2>/dev/null || true
import json, os, sys
f, err = sys.argv[1], sys.argv[2]
try:
    with open(f) as fh:
        d = json.load(fh)
    if not isinstance(d, dict):
        d = {}
except (FileNotFoundError, json.JSONDecodeError):
    d = {}
d.setdefault("schema_version", 1)
d["count"] = int(d.get("count", 0)) + 1
if err:
    d["last_error"] = err[:300]
tmp = f + ".tmp"
with open(tmp, "w") as fh:
    json.dump(d, fh, indent=2)
os.replace(tmp, f)
PY
fi

exit 0
