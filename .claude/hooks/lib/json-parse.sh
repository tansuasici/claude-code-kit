#!/usr/bin/env bash
#
# json-parse.sh — Shared JSON parsing for Claude Code Kit hooks
#
# Usage: source this file after reading INPUT from stdin.
#
#   INPUT=$(cat)
#   HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
#   source "$HOOK_LIB/json-parse.sh"
#
#   TOOL_NAME=$(parse_json_field "tool_name")
#   FILE_PATH=$(parse_json_field "file_path")
#
#
# Security contract:
# - INPUT is expected to be one Claude hook JSON object. Invalid JSON, non-object
#   JSON, or missing fields produce empty output.
# - Lookup prefers .tool_input.<field>, then the top-level .<field>. A key present
#   in tool_input wins even when its value is null (which yields empty). Values
#   render as text: strings and numbers as-is, booleans as true/false, objects and
#   arrays as compact single-line JSON; null yields empty. The jq and python3 paths
#   apply identical rules (they agree on every value hook inputs carry; only the
#   rendering of unusual numeric literals — e.g. 1e3, trailing zeros — can differ,
#   and hook fields never hold those). The no-parser regex fallback resolves string
#   values only (non-string values yield empty).
# - Field names must be simple keys: [A-Za-z_][A-Za-z0-9_]*. Do not pass jq
#   filters, dotted paths, shell fragments, or user-controlled expressions.
# - parse_json_field never evaluates field names as code; parser-specific queries
#   receive the field as data.

# Requires INPUT to be set by the calling script
: "${INPUT:?json-parse.sh: INPUT variable must be set before sourcing}"

parse_json_field() {
  local field="${1:-}"

  if ! [[ "$field" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    return 0
  fi

  if command -v jq &>/dev/null; then
    # Mirror the python3 path exactly: a key present in tool_input wins (even if
    # null → empty), else fall back to the top-level key. Render booleans as
    # true/false and objects/arrays as compact JSON; null/missing → empty. Avoid
    # `//`, whose null/false-coalescing would mask false values and leak nulls
    # through to the top-level lookup.
    printf '%s' "$INPUT" | jq -r --arg field "$field" '
      if type != "object" then empty
      else
        (if (.tool_input | type) == "object" and (.tool_input | has($field)) then .tool_input
         elif has($field) then .
         else null end) as $src
        | if $src == null then empty
          else ($src[$field]) as $v
            | if   $v == null               then empty
              elif ($v | type) == "boolean" then (if $v then "true" else "false" end)
              elif ($v | type) == "object" or ($v | type) == "array" then ($v | tojson)
              else ($v | tostring) end
          end
      end' 2>/dev/null || true
  elif command -v python3 &>/dev/null; then
    printf '%s' "$INPUT" | python3 -c '
import json
import sys

field = sys.argv[1]
try:
    data = json.load(sys.stdin)
    if not isinstance(data, dict):
        sys.exit(0)
    tool_input = data.get("tool_input")
    if isinstance(tool_input, dict) and field in tool_input:
        value = tool_input.get(field)
    else:
        value = data.get(field, "")
    if value is None:
        sys.exit(0)
    if isinstance(value, bool):
        sys.stdout.write("true" if value else "false")
    elif isinstance(value, (dict, list)):
        sys.stdout.write(json.dumps(value, separators=(",", ":")))
    else:
        sys.stdout.write(str(value))
except (json.JSONDecodeError, OSError, TypeError):
    pass
' "$field" 2>/dev/null || true
  else
    printf '%s' "$INPUT" | grep -oE "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' || true
  fi
}
