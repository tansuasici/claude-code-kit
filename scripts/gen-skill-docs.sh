#!/usr/bin/env bash
#
# gen-skill-docs.sh — Generate web-ready MDX docs from SKILL.md files
#
# Reads each .claude/skills/*/SKILL.md, strips YAML frontmatter,
# and generates a Fumadocs-compatible MDX file for the web docs site.
#
# Usage:
#   ./scripts/gen-skill-docs.sh [--out <dir>] [--agents]
#
# Options:
#   --out <dir>    Output directory (default: ../web/content/docs)
#   --agents       Also generate agent docs from .claude/agents/*.md
#   --dry-run      Show what would be generated without writing files
#
# This prevents drift between kit skills/agents and web documentation.
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SKILLS_DIR=".claude/skills"
AGENTS_DIR=".claude/agents"
OUT_DIR="../web/content/docs"
GEN_AGENTS=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --out) [ $# -ge 2 ] || { echo "Error: --out requires a directory argument"; exit 1; }; OUT_DIR="$2"; shift 2 ;;
    --agents) GEN_AGENTS=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

GENERATED=0
SKIPPED=0

# Extract a YAML frontmatter field value
extract_field() {
  local file="$1" field="$2"
  sed -n '/^---$/,/^---$/p' "$file" | grep -E "^${field}:" | sed "s/^${field}:[[:space:]]*//" | sed 's/^"//;s/"$//' | head -1
}

# Strip YAML frontmatter (everything between first --- and second ---)
strip_frontmatter() {
  local file="$1"
  awk 'BEGIN{c=0} /^---$/{c++;next} c>=2{print}' "$file"
}

# Generate MDX from a SKILL.md or agent .md file
generate_mdx() {
  local src="$1" name="$2" type="$3"
  local title description

  # Extract metadata from frontmatter
  title=$(extract_field "$src" "name")
  description=$(extract_field "$src" "description")

  # Format title for display
  local display_title
  case "$type" in
    skill)
      # Convert kebab-case to Title Case
      display_title=$(echo "$title" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')
      ;;
    agent)
      display_title=$(echo "$title" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')
      display_title="$display_title Agent"
      ;;
  esac

  # Truncate description for MDX frontmatter (remove trailing period if present)
  local short_desc
  short_desc=$(echo "$description" | cut -c1-120 | sed 's/\.$//')

  # Get content without frontmatter and first heading
  local content
  content=$(strip_frontmatter "$src" | awk 'NR==1 && /^$/{next} NR<=2 && /^# /{next} NR<=3 && /^$/{next} {print}')

  local out_file
  case "$type" in
    skill) out_file="$OUT_DIR/${name}.mdx" ;;
    agent) out_file="$OUT_DIR/agents/${name}.mdx" ;;
  esac

  if [ "$DRY_RUN" = true ]; then
    echo -e "  ${BLUE}[dry-run]${NC} Would generate: $out_file"
    GENERATED=$((GENERATED + 1))
    return
  fi

  mkdir -p "$(dirname "$out_file")"

  cat > "$out_file" << MDXEOF
---
title: "${display_title}"
description: "${short_desc}."
---

import { Callout } from 'fumadocs-ui/components/callout'

${content}
MDXEOF

  echo -e "  ${GREEN}✓${NC} Generated: $out_file"
  GENERATED=$((GENERATED + 1))
}

echo ""
echo "  Skill Doc Generator"
echo "  ==================="
echo ""

# Generate skill docs
if [ -d "$SKILLS_DIR" ]; then
  echo -e "  ${BLUE}Skills${NC}"
  echo "  ------"

  for skill_dir in "$SKILLS_DIR"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")

    # Skip infrastructure directories
    case "$skill_name" in
      _*) continue ;;
    esac

    skill_file="$skill_dir/SKILL.md"

    if [ ! -f "$skill_file" ]; then
      echo -e "  ${YELLOW}!${NC} Skipped $skill_name (no SKILL.md)"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi

    generate_mdx "$skill_file" "$skill_name" "skill"
  done
  echo ""
fi

# Generate agent docs (optional)
if [ "$GEN_AGENTS" = true ] && [ -d "$AGENTS_DIR" ]; then
  echo -e "  ${BLUE}Agents${NC}"
  echo "  ------"

  for agent_file in "$AGENTS_DIR"/*.md; do
    [ -f "$agent_file" ] || continue
    agent_name=$(basename "$agent_file" .md)

    generate_mdx "$agent_file" "$agent_name" "agent"
  done
  echo ""
fi

# Summary
echo "  Summary"
echo "  -------"
echo -e "  ${GREEN}$GENERATED generated${NC}, ${YELLOW}$SKIPPED skipped${NC}"
if [ "$DRY_RUN" = true ]; then
  echo "  (dry-run mode — no files written)"
fi
echo ""
