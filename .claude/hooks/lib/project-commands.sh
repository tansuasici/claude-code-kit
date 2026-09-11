#!/usr/bin/env bash
#
# project-commands.sh — read a project's declared canonical commands
#
# Single source of truth for "how do I check this project?". A project may ship
# .claude/commands.json declaring its commands so the quality gate, /ship, and
# reviewers all run the SAME command instead of each guessing. Optional — absent
# file means callers fall back to their own detection.
#
# Usage:
#   HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
#   source "$HOOK_LIB/project-commands.sh"
#   cmd=$(project_command "$PROJECT_ROOT" test)   # empty if unset / no file
#
# Schema (both forms accepted):
#   { "typecheck": "...", "lint": "...", "test": "...", "build": "...", "smoke": "...", "timeout": 90 }
#   { "commands": { "test": "...", ... } }
#
#   typecheck, lint      FAST — the per-edit quality gate runs these
#   test, build, smoke   FULL — /ship and the qa-reviewer; never run per edit
#   timeout              seconds the per-edit check may run (CCK_QUALITY_GATE_TIMEOUT wins)
#   "//..." keys         comments
#
# An absent key means "not declared — auto-detect". A key set to "" means "this
# project has no such check": callers report the step as skipped, never as
# passed, and never guess a replacement. Anything else — an unknown key (a typo
# like "typcheck"), a non-string command, a bad timeout, invalid JSON — is a
# config error (project_commands_error), not "nothing declared".
#
# Keys must be simple identifiers — callers pass fixed literals, never user input.

# shellcheck source=python3.sh
source "$(dirname "${BASH_SOURCE[0]}")/python3.sh"

# _project_commands_py <file> <mode> [args...] — one python for every query.
_project_commands_py() {
  python3 - "$@" <<'PY'
import json, math, sys

f, mode, args = sys.argv[1], sys.argv[2], sys.argv[3:]
ALLOWED = ("typecheck", "lint", "test", "build", "smoke", "timeout")

try:
    # utf-8-sig: editors that save a BOM still produce a valid file.
    with open(f, encoding="utf-8-sig") as fh:
        d = json.load(fh)
except json.JSONDecodeError as e:
    if mode == "error":
        print(f".claude/commands.json is not valid JSON ({e.msg}, line {e.lineno})")
    sys.exit(0)
except ValueError:
    if mode == "error":
        print(".claude/commands.json is not valid UTF-8")
    sys.exit(0)
except OSError as e:
    if mode == "error":
        print(f".claude/commands.json is unreadable ({e.strerror})")
    sys.exit(0)

if mode == "error":
    if not isinstance(d, dict):
        print(".claude/commands.json must be a JSON object")
        sys.exit(0)
    problems = []

    def check(obj, where):
        for k, v in obj.items():
            if k.startswith("//"):
                continue
            if k == "commands" and not where:
                if isinstance(v, dict):
                    check(v, "commands.")
                else:
                    problems.append('"commands" must be an object')
            elif k not in ALLOWED:
                problems.append(f'unknown key "{where}{k}" (expected {", ".join(ALLOWED)}, or a "//" comment)')
            elif k == "timeout":
                if (isinstance(v, bool) or not isinstance(v, (int, float))
                        or not math.isfinite(v) or v <= 0):
                    problems.append(f'"{where}timeout" must be a positive number of seconds')
            elif not isinstance(v, str):
                problems.append(f'"{where}{k}" must be a string: the command, or "" for none')

    check(d, "")
    if problems:
        print(".claude/commands.json: " + "; ".join(problems))
    sys.exit(0)

if not isinstance(d, dict):
    sys.exit(0)

def get(key):
    if key in d:
        return d[key]
    c = d.get("commands")
    return c.get(key) if isinstance(c, dict) else None

if mode == "get":
    v = get(args[0])
    if isinstance(v, str) and v.strip():
        print(v.strip())
elif mode == "timeout":
    v = get("timeout")
    if isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v) and v > 0:
        print(int(math.ceil(v)))
elif mode == "check":
    # The keys that apply to an edit, in priority order: the first with a
    # command runs; if every one is "", the project turned the check off.
    off = []
    for key in args:
        v = get(key)
        if isinstance(v, str) and v.strip():
            print(f"run\t{v.strip()}")
            sys.exit(0)
        if isinstance(v, str):
            off.append(key)
    print(f"off\t{', '.join(off)}" if off and len(off) == len(args) else "auto")
PY
}

# project_command <root> <key> — the declared command, or empty if unset / "" / no file.
project_command() {
  local root="$1" key="$2"
  local file="$root/.claude/commands.json"
  [ -f "$file" ] || return 0
  python3_usable || return 0
  [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 0
  _project_commands_py "$file" get "$key" 2>/dev/null || true
}

# project_check_command <root> <key>... — how to check an edit, given the keys
# that apply to it in priority order (e.g. typecheck lint):
#   run<TAB><command>   the first key that declares a command
#   off<TAB><keys>      every key is declared as "" — the check is turned off
#   auto                otherwise (no file, or a key is absent) — auto-detect
project_check_command() {
  local root="$1"
  shift
  local file="$root/.claude/commands.json" out=""
  if [ -f "$file" ] && python3_usable; then
    out=$(_project_commands_py "$file" check "$@" 2>/dev/null || true)
  fi
  printf '%s\n' "${out:-auto}"
}

# project_commands_timeout <root> — the declared per-edit limit in whole seconds, or empty.
project_commands_timeout() {
  local file="$1/.claude/commands.json"
  [ -f "$file" ] || return 0
  python3_usable || return 0
  _project_commands_py "$file" timeout 2>/dev/null || true
}

# project_commands_error <root> — why .claude/commands.json can't be used, or
# empty when it is absent or valid. A gate must not treat a broken or mistyped
# file as "nothing declared": silently falling back to auto-detection runs a
# different check than the project declared. Callers report it as a config error.
project_commands_error() {
  local file="$1/.claude/commands.json"
  [ -f "$file" ] || return 0
  python3_usable || return 0
  _project_commands_py "$file" error 2>/dev/null || true
}
