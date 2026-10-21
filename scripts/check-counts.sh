#!/usr/bin/env bash
#
# check-counts.sh — assert the kit's live skill/hook/agent totals match the
# declared canonical counts.
#
# This is the single declared source for "how many X the kit ships". Bump the
# EXPECTED_* values below when you add or remove a skill/hook/agent; CI fails
# loudly if the tree drifts from them, so counts stated in hand-edited docs
# (README, tasks/todo.md, CHANGELOG) can't silently rot the way tasks/todo.md's
# "30 skills" did. (The web side regenerates lib/skills-data.ts from the same
# tree, so it tracks the count automatically — this guards the kit's own docs.)
#
# Usage:
#   ./scripts/check-counts.sh          # print the totals and assert they match
#
# Exit codes: 0 all counts match · 1 one or more drifted
#

set -uo pipefail

KIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$KIT_ROOT"

# --- Canonical counts — bump when you add/remove a skill/hook/agent ----------
EXPECTED_CORE_SKILLS=37
EXPECTED_WIKI_SKILLS=3
EXPECTED_HOOKS=33
EXPECTED_AGENTS=6
EXPECTED_BENCH_SCENARIOS=143

fails=0
check() { # label expected actual
  if [ "$2" = "$3" ]; then
    echo "  ✓ $1: $3"
  else
    echo "  ✗ $1: expected $2, tree has $3 — bump EXPECTED_* in scripts/check-counts.sh and update the docs/CHANGELOG that state this count" >&2
    fails=$((fails + 1))
  fi
}

# Core skills: .claude/skills/<name>/ excluding build-only _shared / _templates.
core_skills=$(find .claude/skills -mindepth 1 -maxdepth 1 -type d ! -name '_*' 2>/dev/null | wc -l | tr -d ' ')
# Wiki-module skills (shipped only with --wiki).
wiki_skills=$(find wiki-module/.claude/skills -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
# Top-level hook scripts (lib/ helpers and project/ overlay excluded).
hooks=$(find .claude/hooks -maxdepth 1 -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')
# Subagents.
agents=$(find .claude/agents -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
# KitBench scenarios — README states this total, and bench/README.md tables them.
scenarios=$(find bench/scenarios -maxdepth 1 -name '*.json' 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "  Kit inventory counts"
echo "  ===================="
check "core skills" "$EXPECTED_CORE_SKILLS" "$core_skills"
check "wiki skills" "$EXPECTED_WIKI_SKILLS" "$wiki_skills"
check "hooks"       "$EXPECTED_HOOKS"       "$hooks"
check "agents"      "$EXPECTED_AGENTS"      "$agents"
check "bench scenarios" "$EXPECTED_BENCH_SCENARIOS" "$scenarios"

# The README states the scenario total twice (prose + sample run). check() above
# doesn't read it, which let "50 scenarios" outlive 18 new ones.
check_doc() { # label stated actual
  if [ "$2" = "$3" ]; then
    echo "  ✓ $1: $2"
  else
    echo "  ✗ $1: README.md states $2, tree has $3 — update README.md" >&2
    fails=$((fails + 1))
  fi
}
readme=$(cat README.md 2>/dev/null)
re_prose='harness with ([0-9]+) scenarios'
re_run='([0-9]+)/([0-9]+) PASS'
# The README states the hook total twice as well — in the Hooks intro and in
# the "What's Inside" tree — and neither was read here, which is how "28 hooks"
# and "30 deterministic hook scripts" outlived five new ones.
re_hooks='ships \*\*([0-9]+)\*\* hooks; the standard profile wires up ([0-9]+)'
re_hooks_tree='# ([0-9]+) deterministic hook scripts'
if [[ $readme =~ $re_prose ]]; then
  check_doc "README scenario total" "${BASH_REMATCH[1]}" "$scenarios"
else
  check_doc "README scenario total" "missing" "$scenarios"
fi
if [[ $readme =~ $re_run ]]; then
  check_doc "README sample run" "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}" "$scenarios/$scenarios"
else
  check_doc "README sample run" "missing" "$scenarios/$scenarios"
fi
# The wired count is whatever settings.json registers, not a second constant to
# bump: the opt-in five are the difference, and that is the number the README
# promises a reader who installs without --profile strict.
wired=$(grep -oE 'hooks/[a-z0-9-]+\.sh' .claude/settings.json 2>/dev/null | sort -u | wc -l | tr -d ' ')
if [[ $readme =~ $re_hooks ]]; then
  check_doc "README hook total" "${BASH_REMATCH[1]}" "$hooks"
  check_doc "README wired hooks" "${BASH_REMATCH[2]}" "$wired"
else
  check_doc "README hook total" "missing" "$hooks"
fi
if [[ $readme =~ $re_hooks_tree ]]; then
  check_doc "README tree hook count" "${BASH_REMATCH[1]}" "$hooks"
else
  check_doc "README tree hook count" "missing" "$hooks"
fi
echo ""

if [ "$fails" -gt 0 ]; then
  echo "  $fails count(s) drifted from the declared canonical totals." >&2
  exit 1
fi
echo "  All counts match the declared canonical totals."
exit 0
