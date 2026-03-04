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

set -euo pipefail

INPUT=$(cat)

# Parse JSON fields
MODEL=$(echo "$INPUT" | grep -o '"model":"[^"]*"' | cut -d'"' -f4 | sed 's/claude-//' | cut -c1-20)
CONTEXT_WINDOW=$(echo "$INPUT" | grep -o '"contextWindow":[0-9]*' | cut -d: -f2)
CONTEXT_USED=$(echo "$INPUT" | grep -o '"contextUsed":[0-9]*' | cut -d: -f2)
COST=$(echo "$INPUT" | grep -o '"costUSD":[0-9.]*' | cut -d: -f2)

# Git branch
BRANCH=$(git branch --show-current 2>/dev/null || echo "?")

# Context percentage
if [ -n "$CONTEXT_WINDOW" ] && [ "$CONTEXT_WINDOW" -gt 0 ] 2>/dev/null; then
  PCT=$(( CONTEXT_USED * 100 / CONTEXT_WINDOW ))

  # Progress bar (10 chars)
  FILLED=$(( PCT / 10 ))
  EMPTY=$(( 10 - FILLED ))
  BAR=$(printf '%0.s█' $(seq 1 $FILLED 2>/dev/null) 2>/dev/null || echo "")
  BAR="${BAR}$(printf '%0.s░' $(seq 1 $EMPTY 2>/dev/null) 2>/dev/null || echo "")"

  CTX="${BAR} ${PCT}%"
else
  CTX="?"
fi

# Format cost
if [ -n "$COST" ] 2>/dev/null; then
  COST_FMT="\$${COST}"
else
  COST_FMT=""
fi

# Output
echo "${MODEL} | ${BRANCH} | ${CTX} | ${COST_FMT}"
