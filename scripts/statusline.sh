#!/usr/bin/env bash
#
# statusline.sh — Claude Code status line script
#
# Shows: model | git branch | context usage | session cost
#
# Setup: Add to .claude/settings.json:
#   "statusLine": {
#     "command": "./scripts/statusline.sh"
#   }
#
# Input: JSON via stdin with fields:
#   model, contextWindow, contextUsed, costUSD, sessionId
#

# Don't use set -e — missing fields shouldn't crash the script
set -uo pipefail

INPUT=$(cat)

# JSON parser: tries jq, then python3, then grep fallback
json_str() {
  if command -v jq &>/dev/null; then
    echo "$INPUT" | jq -r ".${1} // empty" 2>/dev/null || echo ""
  elif command -v python3 &>/dev/null; then
    echo "$INPUT" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('${1}',''))" 2>/dev/null || echo ""
  else
    echo "$INPUT" | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' || echo ""
  fi
}
json_num() {
  if command -v jq &>/dev/null; then
    echo "$INPUT" | jq -r ".${1} // empty" 2>/dev/null | sed 's/\..*//' || echo ""
  elif command -v python3 &>/dev/null; then
    echo "$INPUT" | python3 -c "import sys,json;d=json.load(sys.stdin);v=d.get('${1}');print(int(v) if v is not None else '')" 2>/dev/null || echo ""
  else
    echo "$INPUT" | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*[0-9.]+" | head -1 | sed 's/.*:[[:space:]]*//' | sed 's/\..*//' || echo ""
  fi
}
json_float() {
  if command -v jq &>/dev/null; then
    echo "$INPUT" | jq -r ".${1} // empty" 2>/dev/null || echo ""
  elif command -v python3 &>/dev/null; then
    echo "$INPUT" | python3 -c "import sys,json;d=json.load(sys.stdin);v=d.get('${1}');print(v if v is not None else '')" 2>/dev/null || echo ""
  else
    echo "$INPUT" | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*[0-9.]+" | head -1 | sed 's/.*:[[:space:]]*//' || echo ""
  fi
}

# Parse fields
MODEL=$(json_str "model" | sed 's/claude-//' | cut -c1-20)
CONTEXT_WINDOW=$(json_num "contextWindow")
CONTEXT_USED=$(json_num "contextUsed")
COST=$(json_float "costUSD")

# Git branch
BRANCH=$(git branch --show-current 2>/dev/null || echo "?")

# Context percentage
CTX="?"
if [ -n "$CONTEXT_WINDOW" ] && [ -n "$CONTEXT_USED" ] && [ "$CONTEXT_WINDOW" -gt 0 ] 2>/dev/null; then
  PCT=$(( CONTEXT_USED * 100 / CONTEXT_WINDOW ))

  # Progress bar (10 chars) — clamp to valid range
  FILLED=$(( PCT / 10 ))
  [ "$FILLED" -lt 0 ] && FILLED=0
  [ "$FILLED" -gt 10 ] && FILLED=10
  EMPTY=$(( 10 - FILLED ))
  BAR=""
  for ((i=0; i<FILLED; i++)); do BAR="${BAR}█"; done
  for ((i=0; i<EMPTY; i++)); do BAR="${BAR}░"; done

  CTX="${BAR} ${PCT}%"
fi

# Format cost
COST_FMT=""
if [ -n "$COST" ]; then
  COST_FMT="\$${COST}"
fi

# Output
OUTPUT="${MODEL:-?} | ${BRANCH} | ${CTX}"
[ -n "$COST_FMT" ] && OUTPUT="$OUTPUT | $COST_FMT"
echo "$OUTPUT"
