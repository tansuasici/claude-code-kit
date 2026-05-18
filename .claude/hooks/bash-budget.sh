#!/usr/bin/env bash
#
# bash-budget.sh — PostToolUse hook (matcher: Bash)
#
# Tracks cumulative Bash output token cost per session. Emits a one-time
# stderr warning when a configurable threshold is crossed. Does NOT block.
#
# Rationale: Bash output is empirically the #1 context-window consumer in
# agentic sessions. Edit/Write hooks already cover file changes; this hook
# closes the observability gap on the shell side.
#
# State: .hook-state/bash-budget.json (atomic write; self-gitignored).
# Threshold: $BASH_BUDGET_THRESHOLD env var, default 50000 tokens.
# Estimate: (chars stdout + chars stderr) / 4 — no LLM calls, no deps.
#
# Inspired by rtk's "command output dominates context cost" observation,
# without rtk's lossy proxy-rewrite model. We measure and signal; we never
# rewrite or truncate.
#

set -euo pipefail

INPUT=$(cat)
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
source "$HOOK_LIB/json-parse.sh"

TOOL_NAME=$(parse_json_field "tool_name")
[ "$TOOL_NAME" = "Bash" ] || exit 0

COMMAND=$(parse_json_field "command")

# Read tool_response.{stdout,stderr}. The shared json-parse.sh only handles
# tool_input.X and top-level X; tool_response lives one level deep, so parse
# inline here.
if command -v jq &>/dev/null; then
  STDOUT=$(printf '%s' "$INPUT" | jq -r '.tool_response.stdout // ""' 2>/dev/null || printf '')
  STDERR=$(printf '%s' "$INPUT" | jq -r '.tool_response.stderr // ""' 2>/dev/null || printf '')
elif command -v python3 &>/dev/null; then
  STDOUT=$(printf '%s' "$INPUT" | python3 -c "import sys,json
try:
    d=json.load(sys.stdin)
    r=d.get('tool_response',{}) or {}
    sys.stdout.write(r.get('stdout','') or '')
except Exception:
    pass" 2>/dev/null || printf '')
  STDERR=$(printf '%s' "$INPUT" | python3 -c "import sys,json
try:
    d=json.load(sys.stdin)
    r=d.get('tool_response',{}) or {}
    sys.stdout.write(r.get('stderr','') or '')
except Exception:
    pass" 2>/dev/null || printf '')
else
  # No JSON parser available — best effort, treat as empty.
  STDOUT=""
  STDERR=""
fi

# Token estimate: chars / 4 (well-established heuristic for English/code).
TOTAL_CHARS=$(( ${#STDOUT} + ${#STDERR} ))
TOKENS=$(( TOTAL_CHARS / 4 ))

# Find project root (same algorithm as quality-gate.sh).
DIR=$(pwd)
ROOT="$DIR"
while [ "$ROOT" != "/" ]; do
  if [ -f "$ROOT/package.json" ] || [ -f "$ROOT/pyproject.toml" ] || [ -f "$ROOT/go.mod" ] || [ -f "$ROOT/Cargo.toml" ] || [ -d "$ROOT/.git" ]; then
    break
  fi
  ROOT=$(dirname "$ROOT")
done
[ "$ROOT" = "/" ] && exit 0  # no project root → nothing to track

STATE_DIR="$ROOT/.hook-state"
mkdir -p "$STATE_DIR"
# Self-gitignore: state is transient, never commit.
[ -f "$STATE_DIR/.gitignore" ] || printf '*\n!.gitignore\n' >"$STATE_DIR/.gitignore"

STATE_FILE="$STATE_DIR/bash-budget.json"
THRESHOLD="${BASH_BUDGET_THRESHOLD:-50000}"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Extract first 1-2 words of the command for top5 bucketing.
CMD_HEAD=$(printf '%s' "$COMMAND" | awk '{print $1" "$2}' | sed 's/[[:space:]]*$//')
[ -z "$CMD_HEAD" ] && CMD_HEAD="(empty)"

# State mutation: python3 owns the atomic JSON read-modify-write. Signals a
# threshold crossing via exit code 42 (chosen to avoid collision with 0/2).
PY_RC=0
if command -v python3 &>/dev/null; then
  set +e
  python3 - "$STATE_FILE" "$TOKENS" "$THRESHOLD" "$NOW" "$CMD_HEAD" <<'PY' 2>/dev/null
import json, os, sys

state_file = sys.argv[1]
tokens = int(sys.argv[2])
threshold = int(sys.argv[3])
now = sys.argv[4]
cmd_head = sys.argv[5]

try:
    with open(state_file) as f:
        state = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    state = None

if not isinstance(state, dict) or state.get("schema_version") != 1:
    state = {
        "schema_version": 1,
        "cumulative_tokens": 0,
        "threshold": threshold,
        "warned": False,
        "since_session_start": now,
        "by_command_top5": {},
    }

prev_total = int(state.get("cumulative_tokens", 0))
new_total = prev_total + tokens
state["cumulative_tokens"] = new_total
state["threshold"] = threshold

by_cmd = dict(state.get("by_command_top5", {}))
by_cmd[cmd_head] = int(by_cmd.get(cmd_head, 0)) + tokens
state["by_command_top5"] = dict(sorted(by_cmd.items(), key=lambda kv: -kv[1])[:5])

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
[bash-budget] Cumulative Bash output has crossed ${THRESHOLD} tokens this session.
Context compaction risk is high. Prefer compact-output flags:
  git status        → git status --short
  pytest            → pytest -q --tb=line
  cargo test        → cargo test --quiet
  rg "x" .          → rg --count "x" .
See agent_docs/conventions.md → Compact Output Flags.
This warning is one-shot per session; further high-volume commands will be tracked silently.
EOF
fi

exit 0
