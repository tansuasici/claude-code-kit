#!/usr/bin/env bash
#
# tool-failure-observe.sh — PostToolUseFailure hook (all tools)
#
# Fire-and-forget observability. PostToolUseFailure fires after a tool call
# errors (a Bash non-zero exit, a failed Edit, etc.) — it cannot prevent the
# failure. This hook counts those failures per session, broken down by tool, in
# .hook-state/tool-failures.json. session-end.sh folds the total into the
# scorecard so a session's friction (lots of failed tool calls = thrashing) is
# visible instead of invisible. NEVER blocks; always exits 0.
#
set -euo pipefail

INPUT=$(cat)
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
source "$HOOK_LIB/json-parse.sh"

TOOL_NAME=$(parse_json_field "tool_name")
[ -z "$TOOL_NAME" ] && TOOL_NAME="unknown"

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.hook-state"
FILE="$STATE_DIR/tool-failures.json"
mkdir -p "$STATE_DIR" 2>/dev/null || true
[ -f "$STATE_DIR/.gitignore" ] || printf '*\n!.gitignore\n' >"$STATE_DIR/.gitignore" 2>/dev/null || true

if command -v python3 >/dev/null 2>&1; then
  python3 - "$FILE" "$TOOL_NAME" <<'PY' 2>/dev/null || true
import json, os, sys
f, tool = sys.argv[1], sys.argv[2]
try:
    with open(f) as fh:
        d = json.load(fh)
    if not isinstance(d, dict):
        d = {}
except (FileNotFoundError, json.JSONDecodeError):
    d = {}
d.setdefault("schema_version", 1)
d["cumulative"] = int(d.get("cumulative", 0)) + 1
by = d.get("by_tool")
if not isinstance(by, dict):
    by = {}
by[tool] = int(by.get(tool, 0)) + 1
d["by_tool"] = by
tmp = f + ".tmp"
with open(tmp, "w") as fh:
    json.dump(d, fh, indent=2)
os.replace(tmp, f)
PY
fi

exit 0
