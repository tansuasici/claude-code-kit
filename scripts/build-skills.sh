#!/usr/bin/env bash
#
# build-skills.sh — Template-based skill generator
#
# Reads .tmpl files from .claude/skills/_templates/
# Replaces {{BLOCK_NAME}} placeholders with content from .claude/skills/_shared/blocks/
# Writes generated SKILL.md files to their respective skill directories
#
# Usage:
#   ./scripts/build-skills.sh              # Build all templates
#   ./scripts/build-skills.sh --dry-run    # Show what would be generated
#   ./scripts/build-skills.sh --list       # List available templates and blocks
#   ./scripts/build-skills.sh <name>       # Build a single template
#

set -euo pipefail

SKILLS_DIR=".claude/skills"
TEMPLATES_DIR="$SKILLS_DIR/_templates"
BLOCKS_DIR="$SKILLS_DIR/_shared/blocks"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ok()   { printf "${GREEN}  ✓${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}  ⚠${NC} %s\n" "$1"; }
err()  { printf "${RED}  ✗${NC} %s\n" "$1"; }
info() { printf "${BLUE}  →${NC} %s\n" "$1"; }

# Check directories exist
if [ ! -d "$TEMPLATES_DIR" ]; then
  err "Templates directory not found: $TEMPLATES_DIR"
  exit 1
fi

if [ ! -d "$BLOCKS_DIR" ]; then
  err "Shared blocks directory not found: $BLOCKS_DIR"
  exit 1
fi

# List mode
if [ "${1:-}" = "--list" ]; then
  echo ""
  echo "Available blocks:"
  for block in "$BLOCKS_DIR"/*.md; do
    [ -f "$block" ] || continue
    name=$(basename "$block" .md)
    printf "  {{%s}}\n" "$(echo "$name" | tr '[:lower:]-' '[:upper:]_')"
  done
  echo ""
  echo "Available templates:"
  for tmpl in "$TEMPLATES_DIR"/*.tmpl; do
    [ -f "$tmpl" ] || continue
    name=$(basename "$tmpl" .tmpl)
    printf "  %s\n" "$name"
  done
  echo ""
  exit 0
fi

DRY_RUN=false
SINGLE=""

if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=true
  SINGLE="${2:-}"
elif [ -n "${1:-}" ]; then
  SINGLE="$1"
fi

# Count blocks
BLOCK_COUNT=0
for block_file in "$BLOCKS_DIR"/*.md; do
  [ -f "$block_file" ] || continue
  BLOCK_COUNT=$((BLOCK_COUNT + 1))
done

if [ "$BLOCK_COUNT" -eq 0 ]; then
  err "No blocks found in $BLOCKS_DIR"
  exit 1
fi

info "Loaded $BLOCK_COUNT shared blocks"

# Replace placeholders in content using python3 (reliable, cross-platform)
replace_placeholders() {
  local tmpl_file="$1"
  local blocks_dir="$2"

  python3 -c "
import sys, os, re

tmpl_file = sys.argv[1]
blocks_dir = sys.argv[2]

# Read template
with open(tmpl_file, 'r') as f:
    content = f.read()

# Load blocks
blocks = {}
for fname in os.listdir(blocks_dir):
    if not fname.endswith('.md'):
        continue
    name = fname[:-3]  # remove .md
    placeholder = name.upper().replace('-', '_')
    with open(os.path.join(blocks_dir, fname), 'r') as f:
        blocks[placeholder] = f.read()

# Replace placeholders
for name, block_content in blocks.items():
    tag = '{{' + name + '}}'
    content = content.replace(tag, block_content)

# Check for unreplaced
remaining = re.findall(r'\{\{[A-Z_]+\}\}', content)
if remaining:
    # Print warnings to stderr
    for tag in set(remaining):
        print(f'UNREPLACED:{tag}', file=sys.stderr)

print(content, end='')
" "$tmpl_file" "$blocks_dir"
}

# Process templates
BUILT=0
ERRORS=0

for tmpl_file in "$TEMPLATES_DIR"/*.tmpl; do
  [ -f "$tmpl_file" ] || continue

  tmpl_name=$(basename "$tmpl_file" .tmpl)

  # If single mode, skip non-matching
  if [ -n "$SINGLE" ] && [ "$tmpl_name" != "$SINGLE" ]; then
    continue
  fi

  # Build
  WARNINGS=""
  content=$(replace_placeholders "$tmpl_file" "$BLOCKS_DIR" 2> >(while read -r line; do
    if [[ "$line" == UNREPLACED:* ]]; then
      WARNINGS="${WARNINGS} ${line#UNREPLACED:}"
    fi
  done; [ -n "$WARNINGS" ] && echo "$WARNINGS" > /tmp/build-skills-warnings || true))

  MISSING=$(cat /tmp/build-skills-warnings 2>/dev/null || true)
  rm -f /tmp/build-skills-warnings

  # Determine output path
  output_dir="$SKILLS_DIR/$tmpl_name"
  output_file="$output_dir/SKILL.md"

  if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "--- $tmpl_name ---"
    echo "Source: $tmpl_file"
    echo "Output: $output_file"
    if [ -n "$MISSING" ]; then
      warn "Unreplaced placeholders:$MISSING"
    fi
    echo "Content preview (first 10 lines):"
    echo "$content" | head -10
    echo "..."
    BUILT=$((BUILT + 1))
    continue
  fi

  # Write output
  mkdir -p "$output_dir"
  echo "$content" > "$output_file"

  if [ -n "$MISSING" ]; then
    warn "$tmpl_name — built with unreplaced:$MISSING"
    ERRORS=$((ERRORS + 1))
  else
    ok "$tmpl_name → $output_file"
  fi

  BUILT=$((BUILT + 1))
done

echo ""
if [ "$DRY_RUN" = true ]; then
  info "Dry run: $BUILT templates would be built"
elif [ -n "$SINGLE" ] && [ "$BUILT" -eq 0 ]; then
  err "Template not found: $SINGLE"
  exit 1
else
  ok "Built $BUILT skills ($ERRORS with warnings)"
fi
