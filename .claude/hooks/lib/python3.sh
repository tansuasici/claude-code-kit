#!/usr/bin/env bash
#
# python3.sh — is there a python3 the hooks can actually use?
#
# Source it:  source "$HOOK_LIB/python3.sh"   (the other libs source it themselves)
#
#   python3_usable   0 when python3 runs and has what the hooks need, else 1.
#
# `command -v python3` is not enough: macOS without the developer tools ships a
# /usr/bin/python3 stub that only prints an xcode-select note and exits 1. Every
# JSON read through it came back empty, and an empty answer read as "nothing
# failed". A python3 that fails this probe counts as absent, so callers take their
# jq / bash fallbacks instead.
#
# The answer is cached in the calling shell; call it once at the top level of a
# hook so command substitutions reuse it instead of probing again. Running the
# probe costs ~40ms, so a "yes" is also cached in ${TMPDIR:-/tmp}/cck-python3-usable
# — trusted only while that file is ours, names the python3 now on PATH, and is
# newer than it, so an upgraded or replaced python3 is probed again. A "no" is
# never cached: a python3 that starts working must be picked up at once. A python3
# that breaks without its file changing (the developer tools removed under
# /usr/bin/python3) keeps a stale "yes" until then — the helpers that need it fail,
# and stop-gate.sh blocks rather than passing.
#

python3_usable() {
  local py cache line
  if [ -z "${_CCK_PYTHON3_USABLE:-}" ]; then
    _CCK_PYTHON3_USABLE=0
    py=$(command -v python3 2>/dev/null) || py=""
    if [ -n "$py" ]; then
      cache="${TMPDIR:-/tmp}/cck-python3-usable"
      line=""
      if [ -f "$cache" ] && [ ! -L "$cache" ] && [ -O "$cache" ] && [ "$cache" -nt "$py" ]; then
        read -r line <"$cache" 2>/dev/null || line=""
      fi
      if [ "$line" = "$py" ]; then
        _CCK_PYTHON3_USABLE=1
      elif python3 -c 'import fcntl, hashlib, json, tempfile' >/dev/null 2>&1; then
        _CCK_PYTHON3_USABLE=1
        { printf '%s\n' "$py" >"$cache"; } 2>/dev/null || true
      fi
    fi
  fi
  [ "$_CCK_PYTHON3_USABLE" = 1 ]
}
