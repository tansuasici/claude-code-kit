#!/usr/bin/env bash
#
# project-commands.sh — read a project's declared canonical commands
#
# Single source of truth for "how do I check this project?". A project may ship
# .claude/commands.json declaring its typecheck / lint / test / build / smoke
# commands so the quality gate, /ship, and reviewers all run the SAME command
# instead of each guessing. Optional — absent file means callers fall back to
# their own detection.
#
# Usage:
#   HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
#   source "$HOOK_LIB/project-commands.sh"
#   cmd=$(project_command "$PROJECT_ROOT" test)   # empty if unset / no file
#
# Schema (both forms accepted):
#   { "typecheck": "...", "lint": "...", "test": "...", "build": "...", "smoke": "..." }
#   { "commands": { "test": "...", ... } }
#
# Only simple string values are returned; anything else yields empty. The key
# must be a simple identifier — callers pass a fixed literal, never user input.

project_command() {
  local root="$1" key="$2"
  local file="$root/.claude/commands.json"
  [ -f "$file" ] || return 0
  command -v python3 >/dev/null 2>&1 || return 0
  [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 0
  python3 - "$file" "$key" <<'PY' 2>/dev/null || true
import json, sys
f, key = sys.argv[1], sys.argv[2]
try:
    with open(f) as fh:
        d = json.load(fh)
except (FileNotFoundError, json.JSONDecodeError, OSError):
    sys.exit(0)
if not isinstance(d, dict):
    sys.exit(0)
v = d.get(key)
if v is None and isinstance(d.get("commands"), dict):
    v = d["commands"].get(key)
if isinstance(v, str) and v.strip():
    print(v.strip())
PY
}
