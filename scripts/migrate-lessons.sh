#!/usr/bin/env bash
#
# migrate-lessons.sh — Convert legacy tasks/lessons.md (single-file) to
# tasks/lessons/<YYYY-MM-DD>-<slug>.md (per-file with YAML frontmatter).
#
# Safe by default:
#   - Reads tasks/lessons.md
#   - Writes per-file lessons into tasks/lessons/
#   - Renames tasks/lessons.md to tasks/lessons.md.bak (never deletes)
#   - Never overwrites an existing per-file lesson
#
# Usage:
#   ./scripts/migrate-lessons.sh             # Migrate using today's date for all entries
#   ./scripts/migrate-lessons.sh --dry-run   # Show what would be migrated, write nothing
#   ./scripts/migrate-lessons.sh --date 2026-04-30
#                                            # Use a specific date prefix for all entries
#

set -euo pipefail

DEST="$(pwd)"
LESSONS_FILE="$DEST/tasks/lessons.md"
LESSONS_DIR="$DEST/tasks/lessons"
DRY_RUN=false
DATE_PREFIX="$(date +%Y-%m-%d)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
NC='\033[0m'

info() { echo -e "${BLUE}[info]${NC}  $*"; }
ok()   { echo -e "${GREEN}[ok]${NC}    $*"; }
warn() { echo -e "${YELLOW}[warn]${NC}  $*"; }
err()  { echo -e "${RED}[error]${NC} $*" >&2; }

usage() {
  cat <<'USAGE'
Usage: migrate-lessons.sh [--dry-run] [--date YYYY-MM-DD]

Converts legacy tasks/lessons.md (single-file format) into tasks/lessons/<YYYY-MM-DD>-<slug>.md
(per-file format with YAML frontmatter). The original file is renamed to tasks/lessons.md.bak.

Options:
  --dry-run, -n           Show what would be migrated, write nothing
  --date YYYY-MM-DD, -d   Date prefix for all migrated entries (default: today)
  --help, -h              Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run|-n) DRY_RUN=true; shift ;;
    --date|-d)
      [ $# -ge 2 ] || { err "--date requires an argument"; exit 1; }
      DATE_PREFIX="$2"
      shift 2
      ;;
    --help|-h) usage; exit 0 ;;
    *) err "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# Validate date format
if ! echo "$DATE_PREFIX" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
  err "Invalid date: $DATE_PREFIX (expected YYYY-MM-DD)"
  exit 1
fi

# Preconditions
if [ ! -f "$LESSONS_FILE" ]; then
  info "No legacy tasks/lessons.md found — nothing to migrate"
  exit 0
fi

mkdir -p "$LESSONS_DIR"

# Slugify a title: lowercase, alphanum + dashes only, max 60 chars
slugify() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' \
    | cut -c1-60
}

# Extract a "**Key**: value" line from a block. Portable across BSD/GNU awk.
extract_field() {
  local block="$1" key="$2"
  printf '%s\n' "$block" \
    | grep -iE "[-]?[[:space:]]*\\*\\*${key}\\*\\*:" \
    | head -n 1 \
    | sed -E 's/^[-[:space:]]*\*\*[^*]+\*\*:[[:space:]]*//'
}

# Split lessons.md into per-entry blocks (one per "### Title").
# Use process substitution (not $(...)) because command substitution strips NUL bytes.

MIGRATED=0
SKIPPED=0
INDEX=0

while IFS= read -r -d '' block; do
  # First line of block is "### Title"
  title=$(printf '%s\n' "$block" | head -n1 | sed -E 's/^###[[:space:]]*//')
  [ -z "$title" ] && continue

  slug=$(slugify "$title")
  [ -z "$slug" ] && {
    warn "Skipping unnamed entry: $title"
    SKIPPED=$((SKIPPED + 1))
    continue
  }

  # Disambiguate if multiple entries have the same slug on the same day
  filename="${DATE_PREFIX}-${slug}.md"
  target="$LESSONS_DIR/$filename"
  suffix=0
  while [ -f "$target" ]; do
    suffix=$((suffix + 1))
    target="$LESSONS_DIR/${DATE_PREFIX}-${slug}-${suffix}.md"
  done

  issue=$(extract_field "$block" "Issue")
  root_cause=$(extract_field "$block" "Root Cause")
  rule=$(extract_field "$block" "Rule")

  [ -z "$issue" ] && issue="(migrated from legacy lessons.md — please fill in)"
  [ -z "$root_cause" ] && root_cause="(migrated from legacy lessons.md — please fill in)"
  [ -z "$rule" ] && rule="(migrated from legacy lessons.md — please fill in)"

  INDEX=$((INDEX + 1))
  info "[$INDEX] $title -> $(basename "$target")"

  if [ "$DRY_RUN" = true ]; then
    continue
  fi

  cat > "$target" <<EOF
---
title: $title
created: $DATE_PREFIX
updated: $DATE_PREFIX
tags: [migrated]
problem_type: tool
source: correction
confidence: medium
top_rule: false
status: active
related: []
---

> Migrated from legacy \`tasks/lessons.md\`. Review fields and tags, then remove this note. The lesson title lives in the YAML frontmatter above — no body H1 (markdownlint MD025).

## Issue

$issue

## Root Cause

$root_cause

## Rule

$rule
EOF
  MIGRATED=$((MIGRATED + 1))
done < <(awk '
  /^### / {
    if (block != "") printf "%s%c", block, 0
    block = $0 "\n"
    next
  }
  /^## / {
    if (block != "") printf "%s%c", block, 0
    block = ""
    next
  }
  { if (block != "") block = block $0 "\n" }
  END { if (block != "") printf "%s%c", block, 0 }
' "$LESSONS_FILE")

# Promote Top Rules from the old lessons.md (if any present) into _index.md.
# We do this by appending — the user can deduplicate manually.
if [ "$DRY_RUN" = false ] && [ "$MIGRATED" -gt 0 ]; then
  TOP_RULES=$(awk '
    /^## Top Rules/ { flag=1; next }
    /^---/ { flag=0 }
    /^## / && !/^## Top Rules/ { flag=0 }
    flag && /^[^[:space:]<]/ { print }
  ' "$LESSONS_FILE" | sed '/^$/d')

  if [ -n "$TOP_RULES" ] && [ -f "$LESSONS_DIR/_index.md" ]; then
    info "Appending Top Rules from legacy file to _index.md (review for duplicates)"
    # Insert after the "## Top Rules" line in _index.md
    awk -v rules="$TOP_RULES" '
      /^## Top Rules$/ {
        print
        print ""
        print "<!-- Migrated from legacy lessons.md — review and dedupe -->"
        print rules
        next
      }
      { print }
    ' "$LESSONS_DIR/_index.md" > "$LESSONS_DIR/_index.md.tmp"
    mv "$LESSONS_DIR/_index.md.tmp" "$LESSONS_DIR/_index.md"
  fi

  # Rename the old file as a backup (never delete user content)
  mv "$LESSONS_FILE" "$LESSONS_FILE.bak"
  ok "Renamed legacy file to tasks/lessons.md.bak"
fi

echo ""
if [ "$DRY_RUN" = true ]; then
  info "Dry run complete. $INDEX entries would be migrated, $SKIPPED skipped."
  info "Re-run without --dry-run to apply."
else
  ok "Migration complete: $MIGRATED migrated, $SKIPPED skipped."
  echo ""
  echo "Next steps:"
  echo "  1. Review files in tasks/lessons/ — adjust frontmatter (tags, problem_type, top_rule)"
  echo "  2. Review tasks/lessons/_index.md → ## Top Rules for duplicates from the legacy file"
  echo "  3. When satisfied, delete tasks/lessons.md.bak"
fi
