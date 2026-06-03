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
#   JSON, missing fields, or unsupported values produce empty output.
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
    printf '%s' "$INPUT" | jq -r --arg field "$field" \
      'if type == "object" then ((.tool_input? | objects | .[$field]) // .[$field] // empty) else empty end' \
      2>/dev/null || true
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
