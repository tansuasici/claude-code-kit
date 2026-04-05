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

# Requires INPUT to be set by the calling script
: "${INPUT:?json-parse.sh: INPUT variable must be set before sourcing}"

parse_json_field() {
  local field="$1"
  if command -v jq &>/dev/null; then
    echo "$INPUT" | jq -r "(.tool_input.${field} // .${field}) // empty" 2>/dev/null || true
  elif command -v python3 &>/dev/null; then
    echo "$INPUT" | python3 -c "import sys,json;d=json.load(sys.stdin);v=d.get('tool_input',d);print(v.get('${field}',d.get('${field}','')))" 2>/dev/null || true
  else
    echo "$INPUT" | grep -oE "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' || true
  fi
}
