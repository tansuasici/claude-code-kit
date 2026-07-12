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
EXPECTED_HOOKS=28
EXPECTED_AGENTS=6

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

echo ""
echo "  Kit inventory counts"
echo "  ===================="
check "core skills" "$EXPECTED_CORE_SKILLS" "$core_skills"
check "wiki skills" "$EXPECTED_WIKI_SKILLS" "$wiki_skills"
check "hooks"       "$EXPECTED_HOOKS"       "$hooks"
check "agents"      "$EXPECTED_AGENTS"      "$agents"
echo ""

if [ "$fails" -gt 0 ]; then
  echo "  $fails count(s) drifted from the declared canonical totals." >&2
  exit 1
fi
echo "  All counts match the declared canonical totals."
exit 0
