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
# hook so command substitutions reuse it instead of probing again.
#

python3_usable() {
  if [ -z "${_CCK_PYTHON3_USABLE:-}" ]; then
    if command -v python3 >/dev/null 2>&1 \
       && python3 -c 'import fcntl, hashlib, json, tempfile' >/dev/null 2>&1; then
      _CCK_PYTHON3_USABLE=1
    else
      _CCK_PYTHON3_USABLE=0
    fi
  fi
  [ "$_CCK_PYTHON3_USABLE" = 1 ]
}
