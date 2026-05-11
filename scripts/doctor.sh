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

# Manifest
if [ -f ".kit-manifest" ]; then
  pass ".kit-manifest exists (kit-managed files tracked)"
else
  warn ".kit-manifest missing (run install.sh --upgrade to generate)"
fi

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

  # Run skill validator if available
  if [ -f "scripts/validate-skills.sh" ] && [ -x "scripts/validate-skills.sh" ]; then
    if scripts/validate-skills.sh .claude/skills >/dev/null 2>&1; then
      pass "All skills pass validation"
    else
      warn "Some skills have issues — run ./scripts/validate-skills.sh for details"
    fi
  fi
else
  warn ".claude/skills/ missing"
fi

echo ""

# --- 6. Project Overlay ---
echo "  Project Overlay"
echo "  ---------------"

if [ -f "CLAUDE.project.md" ]; then
  pass "CLAUDE.project.md exists (project overlay active)"
else
  info "CLAUDE.project.md not found (optional — create for project-specific rules)"
fi

if [ -d "agent_docs/project" ]; then
  PROJECT_DOC_COUNT=$(ls -1 agent_docs/project/*.md 2>/dev/null | wc -l | tr -d ' ')
  if [ "$PROJECT_DOC_COUNT" -gt 0 ]; then
    pass "agent_docs/project/ has $PROJECT_DOC_COUNT doc(s)"
  else
    info "agent_docs/project/ exists but is empty"
  fi
else
  info "agent_docs/project/ not found (optional — create for project-specific docs)"
fi

if [ -d ".claude/hooks/project" ]; then
  # find is pipefail-safe when no matches (unlike ls glob)
  PROJECT_HOOK_COUNT=$(find .claude/hooks/project -maxdepth 1 -type f -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$PROJECT_HOOK_COUNT" -gt 0 ]; then
    pass ".claude/hooks/project/ has $PROJECT_HOOK_COUNT hook(s)"
    # Check executability
    for hook in .claude/hooks/project/*.sh; do
      [ -f "$hook" ] || continue
      if [ ! -x "$hook" ]; then
        fail "$(basename "$hook") in project hooks is NOT executable"
      fi
    done
  else
    info ".claude/hooks/project/ exists but is empty"
  fi
else
  info ".claude/hooks/project/ not found (optional — create for project-specific hooks)"
fi

echo ""

# --- 7. Optional Modules ---
echo "  Optional Modules"
echo "  ----------------"

# Knowledge Wiki module
if [ -f "WIKI.md" ]; then
  pass "WIKI.md exists (knowledge wiki module active)"
  if [ -d "raw-sources" ]; then
    RAW_COUNT=$(find raw-sources -mindepth 1 -type f ! -name ".DS_Store" 2>/dev/null | wc -l | tr -d ' ')
    pass "raw-sources/ exists ($RAW_COUNT source file(s))"
  else
    warn "raw-sources/ missing (WIKI.md is present — expected the source directory)"
  fi
  if [ -d "wiki" ]; then
    WIKI_PAGE_COUNT=0
    for sub in summaries entities concepts; do
      [ -d "wiki/$sub" ] || continue
      SUB_COUNT=$(find "wiki/$sub" -mindepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
      WIKI_PAGE_COUNT=$((WIKI_PAGE_COUNT + SUB_COUNT))
    done
    pass "wiki/ exists ($WIKI_PAGE_COUNT wiki page(s))"
    [ -f "wiki/index.md" ] || warn "wiki/index.md missing (catalog)"
    [ -f "wiki/log.md" ]   || warn "wiki/log.md missing (activity log)"
  else
    warn "wiki/ missing (WIKI.md is present — expected the vault directory)"
  fi
else
  info "Wiki module not installed (optional — install with --wiki)"
fi

# HTML Artifacts module
if [ -f "ARTIFACTS.md" ]; then
  pass "ARTIFACTS.md exists (HTML artifacts module active)"
  if [ -d "artifacts" ]; then
    if [ -f "artifacts/design-system.html" ]; then
      pass "artifacts/design-system.html exists (token reference)"
    else
      fail "artifacts/design-system.html missing — artifacts will drift in style"
    fi
    if [ -f "artifacts/index.html" ]; then
      pass "artifacts/index.html exists (catalog)"
    else
      warn "artifacts/index.html missing (catalog page)"
    fi
    ART_COUNT=$(find artifacts -mindepth 1 -maxdepth 1 -type f -name "*.html" \
      ! -name "design-system.html" ! -name "index.html" 2>/dev/null | wc -l | tr -d ' ')
    info "artifacts/ has $ART_COUNT generated artifact(s) beyond the reference files"
  else
    warn "artifacts/ missing (ARTIFACTS.md is present — expected the output directory)"
  fi
else
  info "HTML Artifacts module not installed (optional — install with --html)"
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
