#!/usr/bin/env bash
#
# validate-skills.sh — Validate skill files for completeness and quality
#
# Checks:
#   - YAML frontmatter (name, description)
#   - Required sections (Problem, Solution, Verification)
#   - Description quality (length, specificity)
#   - Extended structure consistency (if references/ exists)
#
# Usage: ./scripts/validate-skills.sh [path/to/skills]
#

set -euo pipefail

SKILLS_DIR="${1:-.claude/skills}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "  ${YELLOW}!${NC} $1"; WARN=$((WARN + 1)); }

if [ ! -d "$SKILLS_DIR" ]; then
  echo "No skills directory found at $SKILLS_DIR"
  exit 0
fi

echo ""
echo "  Skill Validator"
echo "  ==============="
echo ""

SKILL_COUNT=0

for skill_dir in "$SKILLS_DIR"/*/; do
  [ -d "$skill_dir" ] || continue

  skill_name=$(basename "$skill_dir")

  # Skip infrastructure directories
  case "$skill_name" in
    _*) continue ;;
  esac
  SKILL_FILE="$skill_dir/SKILL.md"

  echo "  $skill_name/"
  echo "  $(printf '%*s' ${#skill_name} '' | tr ' ' '-')--"

  if [ ! -f "$SKILL_FILE" ]; then
    fail "SKILL.md missing"
    echo ""
    continue
  fi

  SKILL_COUNT=$((SKILL_COUNT + 1))

  # --- Check YAML frontmatter ---
  if head -1 "$SKILL_FILE" | grep -q '^---$'; then
    pass "Has YAML frontmatter"

    # Extract frontmatter (between first --- and second ---)
    FRONTMATTER=$(sed -n '/^---$/,/^---$/p' "$SKILL_FILE" | sed '1d;$d')

    # Check name field
    FM_NAME=$(echo "$FRONTMATTER" | grep -E '^name:' | sed 's/^name:[[:space:]]*//' || echo "")
    if [ -n "$FM_NAME" ]; then
      pass "name: $FM_NAME"
    else
      fail "Missing 'name' in frontmatter"
    fi

    # Check description field
    FM_DESC=$(echo "$FRONTMATTER" | grep -E '^description:' | sed 's/^description:[[:space:]]*//' || echo "")
    if [ -n "$FM_DESC" ]; then
      DESC_LEN=${#FM_DESC}
      if [ "$DESC_LEN" -lt 10 ]; then
        warn "Description too short ($DESC_LEN chars) — may not match semantically"
      elif [ "$DESC_LEN" -gt 200 ]; then
        warn "Description too long ($DESC_LEN chars) — keep under 200 chars"
      else
        pass "description: $FM_DESC"
      fi
    else
      fail "Missing 'description' in frontmatter"
    fi
  else
    fail "No YAML frontmatter (must start with ---)"
  fi

  # --- Check required sections ---
  CONTENT=$(cat "$SKILL_FILE")

  # Detect if skill is user-invocable (audit/guide skills have different sections)
  IS_USER_INVOCABLE=$(echo "$FRONTMATTER" | grep -E '^user-invocable:[[:space:]]*true' || echo "")

  # For skill-extractor, sections are different (it's a meta-skill)
  if [ "$skill_name" = "skill-extractor" ]; then
    for section in "When to Extract" "When NOT to Extract" "Extraction Process" "Quality Gates"; do
      if echo "$CONTENT" | grep -q "## $section"; then
        pass "Has section: $section"
      else
        warn "Missing section: $section"
      fi
    done
  elif [ -n "$IS_USER_INVOCABLE" ]; then
    # User-invocable skills (audits, guides) use When to Use / Process / Output Format
    for section in "When to Use" "Process" "Output Format"; do
      if echo "$CONTENT" | grep -q "## $section"; then
        pass "Has section: $section"
      else
        fail "Missing required section: $section"
      fi
    done

    # Optional but recommended sections for user-invocable skills
    for section in "Notes"; do
      if echo "$CONTENT" | grep -q "## $section"; then
        pass "Has section: $section"
      else
        warn "Missing optional section: $section"
      fi
    done
  else
    for section in "Problem" "Solution" "Verification"; do
      if echo "$CONTENT" | grep -q "## $section"; then
        pass "Has section: $section"
      else
        fail "Missing required section: $section"
      fi
    done

    # Optional but recommended sections
    for section in "Context" "Notes"; do
      if echo "$CONTENT" | grep -q "## $section"; then
        pass "Has section: $section"
      else
        warn "Missing optional section: $section"
      fi
    done
  fi

  # --- Check for unfilled placeholders (excluding code blocks) ---
  PLACEHOLDERS=$(awk '/^```/{skip=!skip;next} !skip && !/`/' "$SKILL_FILE" | grep -cE '<[^>]+(name|description|language|skill|check|command|pattern)>' 2>/dev/null || echo "0")
  PLACEHOLDERS=$(echo "$PLACEHOLDERS" | tr -d '[:space:]')
  if [ "$PLACEHOLDERS" -gt 0 ] 2>/dev/null; then
    warn "$PLACEHOLDERS unfilled placeholder(s) found"
  fi

  # --- Check code examples ---
  CODE_BLOCKS=$(grep -c '```' "$SKILL_FILE" 2>/dev/null || echo "0")
  CODE_BLOCKS=$(echo "$CODE_BLOCKS" | tr -d '[:space:]')
  # Each code block has opening and closing ```, so divide by 2
  if [ "$CODE_BLOCKS" -ge 2 ] 2>/dev/null; then
    pass "Has code examples ($((CODE_BLOCKS / 2)) block(s))"
  else
    warn "No code examples — skills with code examples are more useful"
  fi

  # --- Check extended structure (if references/ exists) ---
  if [ -d "$skill_dir/references" ]; then
    pass "Has references/ directory"

    for ref_file in patterns.md anti-patterns.md checklist.md; do
      if [ -f "$skill_dir/references/$ref_file" ]; then
        # Check it's not empty (more than just a heading)
        LINE_COUNT=$(wc -l < "$skill_dir/references/$ref_file" | tr -d ' ')
        if [ "$LINE_COUNT" -lt 5 ]; then
          warn "references/$ref_file is too short ($LINE_COUNT lines)"
        else
          pass "references/$ref_file ($LINE_COUNT lines)"
        fi
      fi
    done
  fi

  # --- Check resources/ for templates ---
  if [ -d "$skill_dir/resources" ]; then
    RES_COUNT=$(find "$skill_dir/resources" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    pass "Has resources/ ($RES_COUNT template(s))"
  fi

  echo ""
done

# --- Summary ---
echo "  Summary"
echo "  -------"
echo -e "  $SKILL_COUNT skill(s) checked"
echo -e "  ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}, ${YELLOW}$WARN warnings${NC}"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "  Some checks failed. Fix the issues above."
  exit 1
else
  echo "  All skills look good!"
fi
echo ""
