#!/usr/bin/env bash
#
# session-end.sh — SessionEnd hook
#
# Appends a JSON-line audit record to reports/session-audit.log when the
# session ends. Replaces the prompt rule "Session End → write handoff if
# mid-work" with a deterministic log line.
#
# Captures session_id, exit reason, transcript path, and the most recent
# quality-gate status so the operator can see at a glance whether the
# session ended clean.
#

set -euo pipefail

INPUT=$(cat)

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
REPORTS_DIR="$ROOT/reports"
mkdir -p "$REPORTS_DIR"
# Self-gitignore: audit logs are transient and machine-local
[ -f "$REPORTS_DIR/.gitignore" ] || printf 'session-audit.log\n' >"$REPORTS_DIR/.gitignore"
LOG="$REPORTS_DIR/session-audit.log"

# Detect the last quality-gate status (if quality-gate.sh ran this session).
GATE_STATUS="none"
STATE_FILE="$ROOT/.hook-state/last_quality_gate.json"
if [ -f "$STATE_FILE" ]; then
  if command -v python3 &>/dev/null; then
    GATE_STATUS=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("status","none"))' "$STATE_FILE" 2>/dev/null || echo "none")
  elif command -v jq &>/dev/null; then
    GATE_STATUS=$(jq -r '.status // "none"' "$STATE_FILE" 2>/dev/null || echo "none")
  else
    GATE_STATUS=$(grep -oE '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' || echo "none")
  fi
fi

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build the audit JSON in one shot. Prefer python3 (handles quoting, spaces
# in field values, missing keys). Fall back to a minimal bash construction —
# acceptable because the SessionEnd payload schema is small and stable.
#
# Note: we use `python3 -c` (not `python3 -` + heredoc) because `-` tells
# python to read the *source* from stdin, which conflicts with the JSON
# payload we want to pipe in. With `-c`, stdin remains available for
# `json.load(sys.stdin)`.
if command -v python3 &>/dev/null; then
  printf '%s' "$INPUT" | python3 -c '
import json, sys
ts = sys.argv[1]
gate = sys.argv[2]
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
print(json.dumps({
    "timestamp": ts,
    "event": "SessionEnd",
    "session_id": d.get("session_id", ""),
    "reason": d.get("reason", "unknown"),
    "transcript_path": d.get("transcript_path", ""),
    "last_quality_gate": gate,
}))
' "$TS" "$GATE_STATUS" >>"$LOG"
else
  # Best-effort grep extraction (acceptable: the payload is small and known)
  SESSION_ID=$(printf '%s' "$INPUT" | grep -oE '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')
  REASON=$(printf '%s' "$INPUT" | grep -oE '"reason"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')
  TRANSCRIPT=$(printf '%s' "$INPUT" | grep -oE '"transcript_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')
  printf '{"timestamp":"%s","event":"SessionEnd","session_id":"%s","reason":"%s","transcript_path":"%s","last_quality_gate":"%s"}\n' \
    "$TS" "${SESSION_ID:-}" "${REASON:-unknown}" "${TRANSCRIPT:-}" "$GATE_STATUS" >>"$LOG"
fi

exit 0
