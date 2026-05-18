#!/usr/bin/env bash
#
# state-counter.sh — Shared atomic JSON counter helper for kit hooks
#
# Usage:
#
#   HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
#   source "$HOOK_LIB/state-counter.sh"
#
#   bump_counter "$ROOT/.hook-state/hook-firings.json" "protect-files"
#
# The state file is a flat JSON object: {"protect-files": 3, "stop-gate": 1, ...}.
# Counters are session-scoped: the file is created on first bump of a session
# and cleared on session-start. Atomic via write-temp-then-rename.
#
# Falls back gracefully when python3 is missing (no-op rather than crash).
#

bump_counter() {
  local file="$1"
  local key="$2"
  local dir
  dir=$(dirname "$file")
  mkdir -p "$dir" 2>/dev/null || return 0
  # Self-gitignore: state files are transient, never commit
  [ -f "$dir/.gitignore" ] || printf '*\n!.gitignore\n' >"$dir/.gitignore" 2>/dev/null || true

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$file" "$key" <<'PY' 2>/dev/null || true
import json, os, sys
f, key = sys.argv[1], sys.argv[2]
try:
    with open(f) as fh:
        d = json.load(fh)
    if not isinstance(d, dict):
        d = {}
except (FileNotFoundError, json.JSONDecodeError):
    d = {}
d[key] = int(d.get(key, 0)) + 1
tmp = f + ".tmp"
with open(tmp, "w") as fh:
    json.dump(d, fh, indent=2)
os.replace(tmp, f)
PY
  fi
  return 0
}

reset_state() {
  # Wipe a state file (used by session-start.sh to clear stale counters from
  # the previous session). No-op if the file doesn't exist.
  local file="$1"
  [ -f "$file" ] && rm -f "$file" 2>/dev/null
  return 0
}
