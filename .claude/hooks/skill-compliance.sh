#!/usr/bin/env bash
#
# skill-compliance.sh — PostToolUse hook
# Reminds Claude to check active skills after file edits
#
# This hook scans skill checklists and injects a reminder into Claude's
# context so it can self-verify compliance with project-specific rules.
#
# Optional hook — not enabled by default.
# Enable in .claude/settings.json under PostToolUse.
#

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | grep -oE '"tool_name"\s*:\s*"[^"]*"' | sed 's/.*:\s*"//;s/"$//')

# Only run after file edits
case "$TOOL_NAME" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"\s*:\s*"[^"]*"' | sed 's/.*:\s*"//;s/"$//' || echo "")
[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

SKILLS_DIR=".claude/skills"
[ ! -d "$SKILLS_DIR" ] && exit 0

EXT="${FILE_PATH##*.}"
BASENAME=$(basename "$FILE_PATH")

# Collect matching skill names based on file type
MATCHING_SKILLS=""

for skill_dir in "$SKILLS_DIR"/*/; do
  [ -d "$skill_dir" ] || continue

  SKILL_FILE="$skill_dir/SKILL.md"
  [ -f "$SKILL_FILE" ] || continue

  skill_name=$(basename "$skill_dir")

  # Skip meta-skills
  case "$skill_name" in
    skill-extractor|skill-generator) continue ;;
  esac

  # Check if skill is relevant to this file type
  # Look for file extensions, framework names, or broad patterns in the skill
  SKILL_CONTENT=$(cat "$SKILL_FILE")

  RELEVANT=false

  # Match by file extension mentions in the skill
  case "$EXT" in
    js|jsx|ts|tsx|mjs|cjs)
      if echo "$SKILL_CONTENT" | grep -qiE 'javascript|typescript|react|next\.?js|node|\.tsx?|\.jsx?'; then
        RELEVANT=true
      fi
      ;;
    py)
      if echo "$SKILL_CONTENT" | grep -qiE 'python|django|fastapi|flask|\.py'; then
        RELEVANT=true
      fi
      ;;
    go)
      if echo "$SKILL_CONTENT" | grep -qiE 'golang|go\.mod|\.go'; then
        RELEVANT=true
      fi
      ;;
    rs)
      if echo "$SKILL_CONTENT" | grep -qiE 'rust|cargo|\.rs'; then
        RELEVANT=true
      fi
      ;;
    rb)
      if echo "$SKILL_CONTENT" | grep -qiE 'ruby|rails|\.rb'; then
        RELEVANT=true
      fi
      ;;
    sql)
      if echo "$SKILL_CONTENT" | grep -qiE 'sql|database|query|migration'; then
        RELEVANT=true
      fi
      ;;
  esac

  # Also match broadly applicable skills (security, error handling, testing)
  if echo "$SKILL_CONTENT" | grep -qiE 'all (files|projects|languages)|any (file|project)'; then
    RELEVANT=true
  fi

  # Match by filename patterns mentioned in the skill
  if echo "$SKILL_CONTENT" | grep -qF "$BASENAME"; then
    RELEVANT=true
  fi

  if [ "$RELEVANT" = true ]; then
    MATCHING_SKILLS="${MATCHING_SKILLS}${skill_name}, "
  fi
done

# If no matching skills, exit silently
[ -z "$MATCHING_SKILLS" ] && exit 0

# Trim trailing comma
MATCHING_SKILLS="${MATCHING_SKILLS%, }"

# Collect checklist items from matching skills
CHECKLIST=""
for skill_name in $(echo "$MATCHING_SKILLS" | tr ',' '\n' | tr -d ' '); do
  CHECKLIST_FILE="$SKILLS_DIR/$skill_name/references/checklist.md"
  if [ -f "$CHECKLIST_FILE" ]; then
    ITEMS=$(grep -E '^\s*-\s*\[' "$CHECKLIST_FILE" 2>/dev/null | head -5 || echo "")
    if [ -n "$ITEMS" ]; then
      CHECKLIST="${CHECKLIST}\n  ${skill_name}:\n${ITEMS}\n"
    fi
  fi
done

# Output reminder as additionalContext (visible to Claude, not blocking)
echo "SKILL_COMPLIANCE: Edited $BASENAME — relevant skills: $MATCHING_SKILLS"
if [ -n "$CHECKLIST" ]; then
  echo -e "Checklist items to verify:$CHECKLIST"
fi

exit 0
