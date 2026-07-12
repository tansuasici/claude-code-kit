#!/usr/bin/env bash
#
# gen-strict-settings.sh — derive .claude/settings.strict.json from the standard
# .claude/settings.json by applying the strict-profile delta.
#
# The standard settings.json is the single source of truth for the shared hook
# structure and permissions. The strict profile is that base plus a small,
# explicit delta — this script encodes ONLY the delta, so the two files can
# never drift on their shared structure. `install.sh --profile strict` copies
# the committed .claude/settings.strict.json (no generation at install time, so
# users need neither python nor jq); CI runs this with `--check` to fail the
# build if the committed file drifts from base + delta.
#
# The strict delta (kept in sync with agent_docs/hooks.md and tasks/decisions.md):
#   1. env.CCK_PROTECT_BUILD_CONFIGS = "1"  — hard-block build-config edits
#   2. UserPromptSubmit  += skill-extract-reminder.sh
#   3. PostToolUse (Edit|Write|NotebookEdit) += auto-lint.sh, auto-format.sh,
#      skill-compliance.sh — inserted before quality-gate.sh so the gate still
#      runs last.
#   4. Notification += notify-waiting.sh — out-of-terminal ping when the agent
#      is waiting (advisory; remote push stays env-gated / off by default).
#
# Usage:
#   ./scripts/gen-strict-settings.sh           # (re)write .claude/settings.strict.json
#   ./scripts/gen-strict-settings.sh --check   # exit 1 if a rewrite would change it
#
# Uses python3 for the JSON transform — the same interpreter doctor.sh already
# relies on for JSON validation, so no new dependency is introduced.
#

set -uo pipefail

KIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$KIT_ROOT"

BASE=".claude/settings.json"
OUT=".claude/settings.strict.json"

CHECK_ONLY=0
if [ "${1:-}" = "--check" ]; then
  CHECK_ONLY=1
fi

command -v python3 >/dev/null 2>&1 || { echo "gen-strict-settings.sh requires python3" >&2; exit 2; }
[ -f "$BASE" ] || { echo "gen-strict-settings.sh: missing base settings ($BASE)" >&2; exit 2; }

GENERATED=$(python3 - "$BASE" <<'PY'
import copy, json, sys

with open(sys.argv[1]) as fh:
    base = json.load(fh)

# 1. env flag first, preserving any existing env keys.
strict = {"env": {**base.get("env", {}), "CCK_PROTECT_BUILD_CONFIGS": "1"}}
for key, value in base.items():
    if key == "env":
        continue
    strict[key] = copy.deepcopy(value)

def cmd(name):
    return {"type": "command", "command": f".claude/hooks/{name}"}

hooks = strict.setdefault("hooks", {})

# 2. UserPromptSubmit gains the skill-extract reminder.
ups = hooks.setdefault("UserPromptSubmit", [{"hooks": []}])
ups[0].setdefault("hooks", []).append(cmd("skill-extract-reminder.sh"))

# 3. Edit/Write PostToolUse gains lint/format/skill-compliance before the gate.
extra = [cmd("auto-lint.sh"), cmd("auto-format.sh"), cmd("skill-compliance.sh")]
for group in hooks.get("PostToolUse", []):
    if group.get("matcher") == "Edit|Write|NotebookEdit":
        gh = group["hooks"]
        idx = next(
            (i for i, h in enumerate(gh) if h.get("command", "").endswith("quality-gate.sh")),
            len(gh),
        )
        group["hooks"] = gh[:idx] + extra + gh[idx:]
        break

# 4. Notification gains the out-of-terminal "agent is waiting" ping.
notif = hooks.setdefault("Notification", [{"hooks": []}])
notif[0].setdefault("hooks", []).append(cmd("notify-waiting.sh"))

print(json.dumps(strict, indent=2))
PY
) || { echo "gen-strict-settings.sh: failed to generate strict settings" >&2; exit 1; }

if [ "$CHECK_ONLY" -eq 1 ]; then
  CURRENT=$(cat "$OUT" 2>/dev/null || echo "")
  if [ "$GENERATED" != "$CURRENT" ]; then
    echo "$OUT is out of sync with $BASE + the strict delta." >&2
    echo "" >&2
    echo "Run scripts/gen-strict-settings.sh (no args) to regenerate, then commit." >&2
    echo "" >&2
    echo "--- Drift (committed < ; regenerated >) ---" >&2
    diff <(printf '%s\n' "$CURRENT") <(printf '%s\n' "$GENERATED") >&2 || true
    exit 1
  fi
  echo "$OUT is in sync with $BASE + the strict delta."
  exit 0
fi

printf '%s\n' "$GENERATED" > "$OUT"
echo "Regenerated $OUT from $BASE + the strict delta."
exit 0
