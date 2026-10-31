#!/usr/bin/env bash
#
# gen-plugin-hooks.sh — derive hooks/hooks.json from the hooks block of
# .claude/settings.json.
#
# settings.json is the single source of truth for which hooks run on which
# event. The plugin loader never reads .claude/hooks/, and a `hooks` key in
# plugin.json would double-load everything, so the plugin needs its own copy at
# the default path hooks/hooks.json (ADR-027). The only difference is the
# command: in plugin mode a bare relative path resolves against the USER's
# project, not the plugin, and silently does nothing — so every command is
# rooted through ${CLAUDE_PLUGIN_ROOT}. This script encodes ONLY that rewrite,
# so the two files can never drift on which hooks exist. CI runs it with
# `--check` to fail the build if the committed copy falls behind.
#
# Usage:
#   ./scripts/gen-plugin-hooks.sh           # (re)write hooks/hooks.json
#   ./scripts/gen-plugin-hooks.sh --check   # exit 1 if a rewrite would change it
#
# Uses python3 for the JSON transform, like gen-strict-settings.sh — the
# commands embed escaped quotes, so a line-wise sed/grep rewrite mis-parses them.
#

set -uo pipefail

KIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$KIT_ROOT"

BASE=".claude/settings.json"
OUT="hooks/hooks.json"

CHECK_ONLY=0
if [ "${1:-}" = "--check" ]; then
  CHECK_ONLY=1
fi

command -v python3 >/dev/null 2>&1 || { echo "gen-plugin-hooks.sh requires python3" >&2; exit 2; }
[ -f "$BASE" ] || { echo "gen-plugin-hooks.sh: missing base settings ($BASE)" >&2; exit 2; }

GENERATED=$(python3 - "$BASE" <<'PY'
import copy, json, sys

DESCRIPTION = (
    "Claude Code Kit hooks, run from the plugin. The installed kit wires the "
    "same scripts in .claude/settings.json; this file is the plugin-mode copy, "
    "with every command resolved through ${CLAUDE_PLUGIN_ROOT} so it runs the "
    "plugin's scripts and not a path inside the user's project."
)

with open(sys.argv[1]) as fh:
    hooks = copy.deepcopy(json.load(fh)["hooks"])

for matchers in hooks.values():
    for matcher in matchers:
        for hook in matcher.get("hooks", []):
            command = hook["command"]
            if not command.startswith(".claude/hooks/"):
                sys.exit(f"gen-plugin-hooks.sh: unexpected hook command {command!r}")
            hook["command"] = '"${CLAUDE_PLUGIN_ROOT}"/' + command

print(json.dumps({"description": DESCRIPTION, "hooks": hooks}, indent=2))
PY
) || { echo "gen-plugin-hooks.sh: failed to generate plugin hooks" >&2; exit 1; }

if [ "$CHECK_ONLY" -eq 1 ]; then
  CURRENT=$(cat "$OUT" 2>/dev/null || echo "")
  if [ "$GENERATED" != "$CURRENT" ]; then
    echo "$OUT is out of sync with the hooks block of $BASE." >&2
    echo "" >&2
    echo "Run scripts/gen-plugin-hooks.sh (no args) to regenerate, then commit." >&2
    echo "" >&2
    echo "--- Drift (committed < ; regenerated >) ---" >&2
    diff <(printf '%s\n' "$CURRENT") <(printf '%s\n' "$GENERATED") >&2 || true
    exit 1
  fi
  echo "$OUT is in sync with the hooks block of $BASE."
  exit 0
fi

printf '%s\n' "$GENERATED" > "$OUT"
echo "Regenerated $OUT from the hooks block of $BASE."
exit 0
