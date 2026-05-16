#!/usr/bin/env bash
#
# quality-gate.sh — PostToolUse hook
#
# After a file edit, runs a fast verification command appropriate to the
# project type (typecheck, lint, or syntax-check). Writes the result to
# `.hook-state/last_quality_gate.json` so stop-gate.sh can decide whether
# the agent is allowed to finish the turn.
#
# Does NOT block (always exits 0). Blocking happens in stop-gate.sh based
# on the persisted state — this separation matches Nader Dabit's "Agent
# Hooks: Deterministic Control" model and avoids tying every edit to a
# block decision.
#
# Timeout: 30s. Skipped silently if no suitable tool is found.
#

set -euo pipefail

INPUT=$(cat)
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
source "$HOOK_LIB/json-parse.sh"

TOOL_NAME=$(parse_json_field "tool_name")

case "$TOOL_NAME" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(parse_json_field "file_path")
[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

EXT="${FILE_PATH##*.}"

# Find project root (same algorithm as auto-lint.sh — look for common markers).
DIR=$(dirname "$FILE_PATH")
ROOT="$DIR"
while [ "$ROOT" != "/" ]; do
  if [ -f "$ROOT/package.json" ] || [ -f "$ROOT/pyproject.toml" ] || [ -f "$ROOT/go.mod" ] || [ -f "$ROOT/Cargo.toml" ] || [ -d "$ROOT/.git" ]; then
    break
  fi
  ROOT=$(dirname "$ROOT")
done
[ "$ROOT" = "/" ] && exit 0  # no project root → nothing to gate

STATE_DIR="$ROOT/.hook-state"
mkdir -p "$STATE_DIR"
# Self-gitignore: state is transient, never commit
[ -f "$STATE_DIR/.gitignore" ] || printf '*\n!.gitignore\n' >"$STATE_DIR/.gitignore"

START=$(date +%s)
TOOL_USED=""
STATUS="skipped"
EXIT_CODE=0
STDERR_TAIL=""
OUT=""

# Portable 30-second timeout: prefer gtimeout (macOS coreutils), then timeout.
run_with_timeout() {
  if command -v gtimeout &>/dev/null; then
    gtimeout 30 "$@"
  elif command -v timeout &>/dev/null; then
    timeout 30 "$@"
  else
    "$@"
  fi
}

# run_check NAME CMD [ARGS...]
# Capture output and exit code without using `|| true` (which would always
# yield exit 0 and falsely report "passed").
run_check() {
  TOOL_USED="$1"; shift
  set +e
  OUT=$(run_with_timeout "$@" 2>&1)
  EXIT_CODE=$?
  set -e
  if [ "$EXIT_CODE" -eq 0 ]; then
    STATUS="passed"
  else
    STATUS="failed"
  fi
  STDERR_TAIL=$(printf '%s' "$OUT" | tail -c 2000)
}

case "$EXT" in
  ts|tsx|mts|cts)
    if [ -f "$ROOT/tsconfig.json" ]; then
      # `cd` and `npx` chained via sh -c so the timeout wraps the actual tool.
      run_check "tsc --noEmit" sh -c "cd \"$ROOT\" && npx --no-install tsc --noEmit"
    fi
    ;;
  js|jsx|mjs|cjs)
    if [ -f "$ROOT/package.json" ] && grep -q '"lint"' "$ROOT/package.json" 2>/dev/null; then
      run_check "npm run lint" sh -c "cd \"$ROOT\" && npm run lint --silent"
    fi
    ;;
  py)
    if command -v ruff &>/dev/null; then
      run_check "ruff check" ruff check "$FILE_PATH"
    elif command -v python3 &>/dev/null; then
      run_check "python3 -m py_compile" python3 -m py_compile "$FILE_PATH"
    fi
    ;;
  go)
    if command -v go &>/dev/null; then
      PKG_DIR=$(dirname "$FILE_PATH")
      # Portable relative path: strip ROOT prefix. Fall back to "..." if outside.
      REL_PKG="${PKG_DIR#"$ROOT"/}"
      if [ "$REL_PKG" = "$PKG_DIR" ] || [ -z "$REL_PKG" ]; then
        REL_PKG="..."  # outside ROOT or equals ROOT — vet everything
      fi
      run_check "go vet ./$REL_PKG" sh -c "cd \"$ROOT\" && go vet \"./$REL_PKG\""
    fi
    ;;
  rs)
    if command -v cargo &>/dev/null; then
      run_check "cargo check" sh -c "cd \"$ROOT\" && cargo check --quiet"
    fi
    ;;
esac

# If nothing ran, leave state untouched (don't overwrite a prior failed gate with a skip).
[ "$STATUS" = "skipped" ] && exit 0

END=$(date +%s)
DURATION=$((END - START))

# Write state file (JSON). Use python3 for safe escaping when available.
STATE_FILE="$STATE_DIR/last_quality_gate.json"
if command -v python3 &>/dev/null; then
  python3 - "$STATUS" "$EXIT_CODE" "$TOOL_USED" "$FILE_PATH" "$DURATION" "$STDERR_TAIL" >"$STATE_FILE" <<'PY'
import json, sys
status, exit_code, tool, edited, duration, stderr_tail = sys.argv[1:]
print(json.dumps({
    "status": status,
    "exit_code": int(exit_code),
    "tool": tool,
    "edited_file": edited,
    "duration_seconds": int(duration),
    "stderr_tail": stderr_tail,
}, indent=2))
PY
else
  # Bash fallback — escape minimally
  ESC_STDERR=$(printf '%s' "$STDERR_TAIL" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
  cat >"$STATE_FILE" <<EOF
{
  "status": "$STATUS",
  "exit_code": $EXIT_CODE,
  "tool": "$TOOL_USED",
  "edited_file": "$FILE_PATH",
  "duration_seconds": $DURATION,
  "stderr_tail": "$ESC_STDERR"
}
EOF
fi

# Surface failure to the agent without blocking the current tool call.
if [ "$STATUS" = "failed" ]; then
  echo "Quality gate FAILED ($TOOL_USED, ${DURATION}s). See $STATE_FILE." >&2
  echo "Completion will be blocked by stop-gate.sh until this is fixed." >&2
fi

exit 0
