#!/usr/bin/env bash
#
# Claude Code Kit — Agent Converter
# Converts .claude/agents/*.md files to other tool formats.
#
# Usage:
#   ./scripts/convert.sh              # Convert to all formats
#   ./scripts/convert.sh cursor       # Convert to Cursor only
#   ./scripts/convert.sh windsurf     # Convert to Windsurf only
#   ./scripts/convert.sh aider        # Convert to Aider only
#
# Output: exports/{cursor,windsurf,aider}/
#

set -euo pipefail

AGENTS_DIR=".claude/agents"
EXPORT_DIR="exports"

# --- Helpers ---

# Extract a YAML frontmatter field value
get_field() {
  local file="$1"
  local field="$2"
  awk -v field="$field" '
    /^---$/ { fm++; next }
    fm == 1 && $0 ~ "^" field ":" {
      sub("^" field ":[ ]*", "")
      print
      exit
    }
    fm >= 2 { exit }
  ' "$file"
}

# Extract body content (everything after frontmatter)
get_body() {
  local file="$1"
  awk '
    /^---$/ { fm++; next }
    fm >= 2 { print }
  ' "$file"
}

# --- Converters ---

convert_cursor() {
  local outdir="$EXPORT_DIR/cursor"
  mkdir -p "$outdir"

  for agent in "$AGENTS_DIR"/*.md; do
    [ -f "$agent" ] || continue

    local name
    name=$(get_field "$agent" "name")
    local description
    description=$(get_field "$agent" "description")
    local body
    body=$(get_body "$agent")

    if [ -z "$name" ]; then
      name=$(basename "$agent" .md)
    fi

    local outfile="$outdir/${name}.mdc"

    cat > "$outfile" <<CURSOR_EOF
---
description: ${description:-Agent converted from Claude Code Kit}
globs:
alwaysApply: false
---

${body}
CURSOR_EOF

    echo "  Cursor: $outfile"
  done
}

convert_windsurf() {
  local outdir="$EXPORT_DIR/windsurf"
  mkdir -p "$outdir"
  local outfile="$outdir/.windsurfrules"

  cat > "$outfile" <<'HEADER'
# Windsurf Rules
# Generated from Claude Code Kit agents
# Do not edit — regenerate with: ./scripts/convert.sh windsurf

HEADER

  for agent in "$AGENTS_DIR"/*.md; do
    [ -f "$agent" ] || continue

    local name
    name=$(get_field "$agent" "name")
    local body
    body=$(get_body "$agent")

    if [ -z "$name" ]; then
      name=$(basename "$agent" .md)
    fi

    cat >> "$outfile" <<AGENT_EOF

---

## Agent: ${name}

${body}
AGENT_EOF
  done

  echo "  Windsurf: $outfile"
}

convert_aider() {
  local outdir="$EXPORT_DIR/aider"
  mkdir -p "$outdir"
  local outfile="$outdir/CONVENTIONS.md"

  cat > "$outfile" <<'HEADER'
# Conventions
# Generated from Claude Code Kit agents
# Do not edit — regenerate with: ./scripts/convert.sh aider

HEADER

  for agent in "$AGENTS_DIR"/*.md; do
    [ -f "$agent" ] || continue

    local name
    name=$(get_field "$agent" "name")
    local body
    body=$(get_body "$agent")

    if [ -z "$name" ]; then
      name=$(basename "$agent" .md)
    fi

    cat >> "$outfile" <<AGENT_EOF

---

## ${name}

${body}
AGENT_EOF
  done

  echo "  Aider: $outfile"
}

# --- Main ---

echo ""
echo "  Claude Code Kit — Agent Converter"
echo "  ================================="
echo ""

# Check agents exist
if [ ! -d "$AGENTS_DIR" ] || [ -z "$(ls -A "$AGENTS_DIR"/*.md 2>/dev/null)" ]; then
  echo "  No agent files found in $AGENTS_DIR/"
  exit 1
fi

AGENT_COUNT=$(ls -1 "$AGENTS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
echo "  Found $AGENT_COUNT agent(s) in $AGENTS_DIR/"
echo ""

TARGET="${1:-all}"

case "$TARGET" in
  cursor)
    convert_cursor
    ;;
  windsurf)
    convert_windsurf
    ;;
  aider)
    convert_aider
    ;;
  all)
    convert_cursor
    convert_windsurf
    convert_aider
    ;;
  *)
    echo "  Unknown target: $TARGET"
    echo "  Usage: $0 [cursor|windsurf|aider|all]"
    exit 1
    ;;
esac

echo ""
echo "  Done! Output in $EXPORT_DIR/"
echo ""
