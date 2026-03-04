#!/usr/bin/env bash
#
# Claude Code Kit — Quick Setup
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/tansuasici/claude-code-kit/main/install.sh | bash
#
#   Or clone and run locally:
#   ./install.sh [--template nextjs|node-api|python-fastapi]
#

set -euo pipefail

REPO="https://github.com/tansuasici/claude-code-kit.git"
TEMPLATE=""
DEST="$(pwd)"
TMPDIR=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[info]${NC}  $1"; }
ok()    { echo -e "${GREEN}[ok]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[warn]${NC}  $1"; }
error() { echo -e "${RED}[error]${NC} $1"; exit 1; }

cleanup() {
  if [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ]; then
    rm -rf "$TMPDIR"
  fi
}
trap cleanup EXIT

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --template|-t)
      TEMPLATE="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: install.sh [--template nextjs|node-api|python-fastapi]"
      echo ""
      echo "Options:"
      echo "  --template, -t   Use a stack-specific template (nextjs, node-api, python-fastapi)"
      echo "  --help, -h       Show this help"
      exit 0
      ;;
    *)
      error "Unknown option: $1. Use --help for usage."
      ;;
  esac
done

# Validate template if provided
if [ -n "$TEMPLATE" ]; then
  case "$TEMPLATE" in
    nextjs|node-api|python-fastapi) ;;
    *) error "Unknown template: $TEMPLATE. Options: nextjs, node-api, python-fastapi" ;;
  esac
fi

echo ""
echo "  Claude Code Kit Installer"
echo "  ========================="
echo ""

# Check for existing files
EXISTING=()
[ -f "$DEST/CLAUDE.md" ] && EXISTING+=("CLAUDE.md")
[ -f "$DEST/CODEBASE_MAP.md" ] && EXISTING+=("CODEBASE_MAP.md")

if [ ${#EXISTING[@]} -gt 0 ]; then
  warn "These files already exist and will be SKIPPED:"
  for f in "${EXISTING[@]}"; do
    echo "       - $f"
  done
  echo ""
  read -p "  Continue? (y/N) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Cancelled."
    exit 0
  fi
fi

# Clone to temp directory
info "Downloading Claude Code Kit..."
TMPDIR=$(mktemp -d)
git clone --quiet --depth 1 "$REPO" "$TMPDIR" 2>/dev/null || error "Failed to clone repository"

# Determine source for CLAUDE.md and CODEBASE_MAP.md
if [ -n "$TEMPLATE" ]; then
  SRC_CLAUDE="$TMPDIR/examples/$TEMPLATE/CLAUDE.md"
  SRC_MAP="$TMPDIR/examples/$TEMPLATE/CODEBASE_MAP.md"
  info "Using template: $TEMPLATE"
else
  SRC_CLAUDE="$TMPDIR/CLAUDE.md"
  SRC_MAP="$TMPDIR/CODEBASE_MAP.md"
  info "Using generic template"
fi

# Copy CLAUDE.md
if [ ! -f "$DEST/CLAUDE.md" ]; then
  cp "$SRC_CLAUDE" "$DEST/CLAUDE.md"
  ok "Created CLAUDE.md"
else
  warn "Skipped CLAUDE.md (already exists)"
fi

# Copy CODEBASE_MAP.md
if [ ! -f "$DEST/CODEBASE_MAP.md" ]; then
  cp "$SRC_MAP" "$DEST/CODEBASE_MAP.md"
  ok "Created CODEBASE_MAP.md"
else
  warn "Skipped CODEBASE_MAP.md (already exists)"
fi

# Copy agent_docs/
if [ ! -d "$DEST/agent_docs" ]; then
  cp -r "$TMPDIR/agent_docs" "$DEST/agent_docs"
  ok "Created agent_docs/"
else
  warn "Skipped agent_docs/ (already exists)"
fi

# Copy tasks/
if [ ! -d "$DEST/tasks" ]; then
  cp -r "$TMPDIR/tasks" "$DEST/tasks"
  ok "Created tasks/"
else
  warn "Skipped tasks/ (already exists)"
fi

# Copy validation script
if [ ! -d "$DEST/scripts" ]; then
  mkdir -p "$DEST/scripts"
fi
if [ ! -f "$DEST/scripts/validate.sh" ]; then
  cp "$TMPDIR/scripts/validate.sh" "$DEST/scripts/validate.sh"
  chmod +x "$DEST/scripts/validate.sh"
  ok "Created scripts/validate.sh"
else
  warn "Skipped scripts/validate.sh (already exists)"
fi

# Copy hooks
if [ ! -d "$DEST/.claude/hooks" ]; then
  mkdir -p "$DEST/.claude/hooks"
  cp "$TMPDIR/.claude/hooks/"*.sh "$DEST/.claude/hooks/"
  chmod +x "$DEST/.claude/hooks/"*.sh
  ok "Created .claude/hooks/ (7 hooks)"
else
  warn "Skipped .claude/hooks/ (already exists)"
fi

# Copy settings.json (hooks config)
if [ ! -f "$DEST/.claude/settings.json" ]; then
  cp "$TMPDIR/.claude/settings.json" "$DEST/.claude/settings.json"
  ok "Created .claude/settings.json (hooks config)"
else
  warn "Skipped .claude/settings.json (already exists)"
fi

echo ""
echo "  Done! Next steps:"
echo "  1. Fill in CODEBASE_MAP.md with your project details"
echo "  2. Run ./scripts/validate.sh to check for unfilled placeholders"
echo "  3. Review .claude/settings.json to enable/disable hooks"
echo "  4. Start a Claude Code session"
echo ""
