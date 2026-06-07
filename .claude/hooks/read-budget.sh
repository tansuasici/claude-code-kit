#!/usr/bin/env bash
#
# read-budget.sh — PostToolUse hook (matcher: Read)
#
# Tracks cumulative file-read token cost per session — the other half of context
# burn that bash-budget.sh measures for shell output. Emits a one-time stderr
# warning when a threshold is crossed. Does NOT block.
#
# Rationale: large/whole-file reads are a major, unmeasured context-window cost.
# This nudges the tiered / on-demand loading the kit already preaches (CLAUDE.md
# → Session Boot Tiered), without ever truncating — we measure and signal only.
#
# State: .hook-state/read-budget.json (atomic write; self-gitignored).
# Threshold: $READ_BUDGET_THRESHOLD env var, default 100000 tokens.
# Estimate: chars(tool_response) / 4 — shape-agnostic, no LLM calls, no deps.
#

set -euo pipefail

INPUT=$(cat)
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
source "$HOOK_LIB/json-parse.sh"

TOOL_NAME=$(parse_json_field "tool_name")
[ "$TOOL_NAME" = "Read" ] || exit 0

FILE_PATH=$(parse_json_field "file_path")

# Token estimate = chars of the injected read result / 4. tool_response shape
# varies (string or object), so stringify the whole thing and measure length.
CHARS=0
if command -v jq &>/dev/null; then
  CHARS=$(printf '%s' "$INPUT" | jq -r '(.tool_response // "") | tostring | length' 2>/dev/null || echo 0)
elif command -v python3 &>/dev/null; then
  CHARS=$(printf '%s' "$INPUT" | python3 -c "import sys,json
try:
    d=json.load(sys.stdin); r=d.get('tool_response','')
    sys.stdout.write(str(len(r if isinstance(r,str) else json.dumps(r))))
except Exception:
    sys.stdout.write('0')" 2>/dev/null || echo 0)
fi
[ -z "$CHARS" ] && CHARS=0
TOKENS=$(( CHARS / 4 ))

# Anchor state to the project root (CLAUDE_PROJECT_DIR) — the same dir the
# readers (session-end.sh / session-start.sh) use. NOT a pwd walk-up: that would
# write to a nested-package .hook-state the scorecard never reads (the monorepo
# mismatch fixed for quality-gate.sh).
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.hook-state"
mkdir -p "$STATE_DIR"
[ -f "$STATE_DIR/.gitignore" ] || printf '*\n!.gitignore\n' >"$STATE_DIR/.gitignore"

STATE_FILE="$STATE_DIR/read-budget.json"
THRESHOLD="${READ_BUDGET_THRESHOLD:-100000}"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

FILE_HEAD=$(basename "${FILE_PATH:-}" 2>/dev/null || echo "")
[ -z "$FILE_HEAD" ] && FILE_HEAD="(unknown)"

# Atomic JSON read-modify-write; signal a threshold crossing via exit code 42.
PY_RC=0
if command -v python3 &>/dev/null; then
  set +e
  python3 - "$STATE_FILE" "$TOKENS" "$THRESHOLD" "$NOW" "$FILE_HEAD" <<'PY' 2>/dev/null
import json, os, sys
state_file, tokens, threshold, now, file_head = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4], sys.argv[5]
try:
    with open(state_file) as f:
        state = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    state = None
if not isinstance(state, dict) or state.get("schema_version") != 1:
    state = {"schema_version": 1, "cumulative_tokens": 0, "threshold": threshold,
             "warned": False, "since_session_start": now, "by_file_top5": {}}
new_total = int(state.get("cumulative_tokens", 0)) + tokens
state["cumulative_tokens"] = new_total
state["threshold"] = threshold
by_file = dict(state.get("by_file_top5", {}))
by_file[file_head] = int(by_file.get(file_head, 0)) + tokens
state["by_file_top5"] = dict(sorted(by_file.items(), key=lambda kv: -kv[1])[:5])
crossed_now = (not state.get("warned", False)) and new_total >= threshold
if crossed_now:
    state["warned"] = True
tmp = state_file + ".tmp"
with open(tmp, "w") as f:
    json.dump(state, f, indent=2)
os.replace(tmp, state_file)
sys.exit(42 if crossed_now else 0)
PY
  PY_RC=$?
  set -e
fi

if [ "$PY_RC" = "42" ]; then
  cat >&2 <<EOF
[read-budget] Cumulative file-read output has crossed ${THRESHOLD} tokens this session.
Context compaction risk is high. Prefer tiered / on-demand loading:
  - Read only the slice you need (offset/limit) instead of whole files.
  - Use Grep/Glob to locate before reading.
  - Lean on CODEBASE_MAP.md + agent_docs pointers rather than re-reading trees.
See CLAUDE.md → Session Boot (Tiered). One-shot warning; further reads tracked silently.
EOF
fi

exit 0
