#!/usr/bin/env bash
#
# check-scaffold.sh — assert scaffold/tasks/ is a clean starting point.
#
# install.sh copies scaffold/tasks/ into a fresh project. This repo dogfoods the
# kit, so its own tasks/ carries a live board, its ADR log and its real lessons —
# those used to ship, handing every new project someone else's project state.
#
# Three invariants:
#   1. No kit-internal markers (issue keys, PR numbers, this repo's ADRs) in the
#      scaffold.
#   2. The templates that exist in both trees stay byte-identical, so improving
#      one never silently leaves the other stale.
#   3. The scaffold lesson graph validates, so a fresh install's _index.md is
#      not born broken.
#
# Usage:
#   ./scripts/check-scaffold.sh
#
# Exit codes: 0 clean · 1 one or more invariants broken
#

set -uo pipefail

KIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$KIT_ROOT"

fails=0
ok()   { echo "  ✓ $1"; }
bad()  { echo "  ✗ $1" >&2; fails=$((fails + 1)); }

echo ""
echo "  Scaffold check"
echo "  =============="

# 1. Kit-internal state must not ship. ADR-001 is the deliberate example; this
#    repo's own ADRs are numbered 002 and up.
leak=$(grep -rlE 'CLA-[0-9]|TAN-[0-9]|PR #[0-9]|release-please cut' scaffold/ 2>/dev/null || true)
if [ -z "$leak" ]; then
  ok "no kit-internal issue/PR references"
else
  bad "kit-internal references in: $(echo "$leak" | tr '\n' ' ')"
fi

adrs=$(grep -cE '^### ADR-[0-9]' scaffold/tasks/decisions.md 2>/dev/null || true)
if [ "${adrs:-0}" = "1" ]; then
  ok "decisions.md carries only the ADR-001 example"
else
  bad "scaffold/tasks/decisions.md has ${adrs:-0} ADRs — expected just the ADR-001 example"
fi

# 1b. The generic map must be a blank template, not this repo's filled-in one.
kitref=$(grep -c 'ClaudeCodeKit' scaffold/CODEBASE_MAP.md 2>/dev/null || true)
if [ "${kitref:-0}" = "0" ]; then
  ok "generic CODEBASE_MAP.md is stack-agnostic"
else
  bad "scaffold/CODEBASE_MAP.md mentions ClaudeCodeKit ${kitref}× — it must be a blank template"
fi

# 2. Templates present in both trees must not drift apart.
for rel in tasks/handoff.md tasks/lessons/_TEMPLATE.md tasks/lessons/2026-04-15-example-tsconfig.md; do
  if cmp -s "scaffold/$rel" "$rel"; then
    ok "in sync with scaffold: $rel"
  else
    bad "scaffold/$rel and $rel have drifted — copy one over the other"
  fi
done

# 3. The scaffold's lesson graph must validate (and its _index.md is generated:
#    ./scripts/lesson-graph.sh --lessons-dir "$PWD/scaffold/tasks/lessons").
if bash scripts/lesson-graph.sh --check --lessons-dir "$KIT_ROOT/scaffold/tasks/lessons" >/dev/null 2>&1; then
  ok "scaffold lesson graph validates"
else
  bad "scaffold lesson graph failed validation"
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "  Scaffold is a clean starting point."
  exit 0
fi
echo "  $fails scaffold problem(s)." >&2
exit 1
