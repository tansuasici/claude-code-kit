#!/usr/bin/env bash
#
# Claude Code Kit — Doctor
# Checks the health of your Claude Code Kit installation.
#
# Usage: ./scripts/doctor.sh
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "  ${YELLOW}!${NC} $1"; WARN=$((WARN + 1)); }
info() { echo -e "  ${BLUE}—${NC} $1"; }

echo ""
echo "  Claude Code Kit — Doctor"
echo "  ========================"
echo ""

# --- 1. Core files ---
echo "  Core files"
echo "  ----------"

for file in CLAUDE.md CODEBASE_MAP.md; do
  if [ -f "$file" ]; then
    pass "$file exists"
  else
    fail "$file missing"
  fi
done

if [ -d "agent_docs" ]; then
  pass "agent_docs/ exists"
  EXPECTED_DOCS=(workflow.md debugging.md testing.md conventions.md subagents.md hooks.md skills.md contracts.md prompting.md)
  for doc in "${EXPECTED_DOCS[@]}"; do
    if [ ! -f "agent_docs/$doc" ]; then
      warn "agent_docs/$doc missing"
    fi
  done
else
  fail "agent_docs/ missing"
fi

if [ -d "tasks" ]; then
  pass "tasks/ exists"
else
  fail "tasks/ missing"
fi

echo ""

# --- 2. Hooks ---
echo "  Hooks"
echo "  -----"

if [ -d ".claude/hooks" ]; then
  pass ".claude/hooks/ exists"

  HOOK_FILES=(.claude/hooks/*.sh)
  if [ -e "${HOOK_FILES[0]}" ]; then
    for hook in "${HOOK_FILES[@]}"; do
      basename=$(basename "$hook")
      if [ -x "$hook" ]; then
        pass "$basename is executable"
      else
        fail "$basename is NOT executable (run: chmod +x $hook)"
      fi
    done
  else
    warn "No hook files found in .claude/hooks/"
  fi
else
  fail ".claude/hooks/ missing"
fi

echo ""

# --- 3. Settings ---
echo "  Settings"
echo "  --------"

if [ -f ".claude/settings.json" ]; then
  pass ".claude/settings.json exists"

  # Validate JSON
  if command -v python3 &>/dev/null; then
    if python3 -c "import json; json.load(open('.claude/settings.json'))" 2>/dev/null; then
      pass "settings.json is valid JSON"
    else
      fail "settings.json is INVALID JSON"
    fi
  elif command -v node &>/dev/null; then
    if node -e "JSON.parse(require('fs').readFileSync('.claude/settings.json','utf8'))" 2>/dev/null; then
      pass "settings.json is valid JSON"
    else
      fail "settings.json is INVALID JSON"
    fi
  else
    warn "Cannot validate JSON (no python3 or node found)"
  fi

  # Check for orphan hooks (hook files not referenced in settings.json)
  if [ -d ".claude/hooks" ]; then
    SETTINGS_CONTENT=$(cat .claude/settings.json)
    for hook in .claude/hooks/*.sh; do
      [ -f "$hook" ] || continue
      basename=$(basename "$hook")
      if echo "$SETTINGS_CONTENT" | grep -qF "$basename"; then
        pass "$basename is referenced in settings.json"
      else
        warn "$basename exists but is NOT in settings.json (orphan hook)"
      fi
    done
  fi
else
  fail ".claude/settings.json missing"
fi

echo ""

# --- 4. CODEBASE_MAP placeholders ---
echo "  CODEBASE_MAP"
echo "  ------------"

if [ -f "CODEBASE_MAP.md" ]; then
  # Filter out markdown links [text](url) — only count [placeholder] without parens after
  REAL_PLACEHOLDERS=$(grep -E '\[.+\]' CODEBASE_MAP.md 2>/dev/null | grep -cvE '\[.+\]\(' 2>/dev/null || true)
  REAL_PLACEHOLDERS=${REAL_PLACEHOLDERS:-0}
  REAL_PLACEHOLDERS=$(echo "$REAL_PLACEHOLDERS" | tr -d '[:space:]')

  if [ "$REAL_PLACEHOLDERS" -gt 0 ] 2>/dev/null; then
    warn "CODEBASE_MAP.md has ~$REAL_PLACEHOLDERS unfilled placeholder(s) — run ./scripts/validate.sh for details"
  else
    pass "CODEBASE_MAP.md appears filled in"
  fi
else
  info "Skipped (CODEBASE_MAP.md not found)"
fi

echo ""

# --- 5. Agents & Skills ---
echo "  Agents & Skills"
echo "  ---------------"

if [ -d ".claude/agents" ]; then
  AGENT_COUNT=$(ls -1 .claude/agents/*.md 2>/dev/null | wc -l | tr -d ' ')
  pass ".claude/agents/ exists ($AGENT_COUNT agents)"
else
  warn ".claude/agents/ missing"
fi

if [ -d ".claude/skills" ]; then
  SKILL_COUNT=$(find .claude/skills -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
  pass ".claude/skills/ exists ($SKILL_COUNT skills)"
else
  warn ".claude/skills/ missing"
fi

echo ""

# --- Summary ---
echo "  Summary"
echo "  -------"
echo -e "  ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}, ${YELLOW}$WARN warnings${NC}"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "  Some checks failed. Fix the issues above and run doctor again."
  exit 1
else
  echo "  Installation looks healthy!"
fi
echo ""
