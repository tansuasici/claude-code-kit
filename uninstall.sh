#!/usr/bin/env bash
#
# Claude Code Kit — Uninstaller
#
# Usage:
#   ./uninstall.sh              # Interactive — shows what will be removed, asks for confirmation
#   ./uninstall.sh --dry-run    # Show what would be removed without deleting anything
#   ./uninstall.sh --force      # Remove everything without confirmation
#   ./uninstall.sh --keep-tasks # Keep tasks/ directory (lessons, decisions, handoffs)
#

set -euo pipefail

DEST="$(pwd)"
DRY_RUN=false
FORCE=false
KEEP_TASKS=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

info()  { echo -e "${BLUE}[info]${NC}  $1"; }
ok()    { echo -e "${GREEN}[ok]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[warn]${NC}  $1"; }
error() { echo -e "${RED}[error]${NC} $1"; exit 1; }

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run|-n)
      DRY_RUN=true
      shift
      ;;
    --force|-f)
      FORCE=true
      shift
      ;;
    --keep-tasks|-k)
      KEEP_TASKS=true
      shift
      ;;
    --help|-h)
      echo "Usage: uninstall.sh [--dry-run] [--force] [--keep-tasks]"
      echo ""
      echo "Options:"
      echo "  --dry-run, -n     Show what would be removed without deleting"
      echo "  --force, -f       Remove without confirmation"
      echo "  --keep-tasks, -k  Keep tasks/ directory (lessons, decisions, handoffs)"
      echo "  --help, -h        Show this help"
      exit 0
      ;;
    *)
      error "Unknown option: $1. Use --help for usage."
      ;;
  esac
done

echo ""
echo "  Claude Code Kit — Uninstaller"
echo "  =============================="
echo ""

# --- Detect what was installed ---

FILES_TO_REMOVE=()
DIRS_TO_REMOVE=()
HAS_USER_DATA=false

# Root files
[ -f "$DEST/VERSION" ] && FILES_TO_REMOVE+=("VERSION")
[ -f "$DEST/CLAUDE.md" ] && FILES_TO_REMOVE+=("CLAUDE.md")
[ -f "$DEST/CODEBASE_MAP.md" ] && FILES_TO_REMOVE+=("CODEBASE_MAP.md")

# Directories
[ -d "$DEST/agent_docs" ] && DIRS_TO_REMOVE+=("agent_docs/")
[ -d "$DEST/scripts" ] && DIRS_TO_REMOVE+=("scripts/")

# tasks/ — may contain user data
if [ -d "$DEST/tasks" ]; then
  if [ "$KEEP_TASKS" = true ]; then
    warn "Keeping tasks/ (--keep-tasks)"
  else
    # Check for user-generated content
    TASK_FILES=0
    if [ -f "$DEST/tasks/lessons.md" ]; then
      # Check if lessons.md has content beyond the template
      LESSON_LINES=$(grep -c "^### " "$DEST/tasks/lessons.md" 2>/dev/null || echo "0")
      # Template has 1 example entry — anything beyond that is user data
      if [ "$LESSON_LINES" -gt 1 ]; then
        TASK_FILES=$((TASK_FILES + 1))
      fi
    fi
    if [ -f "$DEST/tasks/decisions.md" ]; then
      DECISION_LINES=$(grep -c "^### ADR-" "$DEST/tasks/decisions.md" 2>/dev/null || echo "0")
      if [ "$DECISION_LINES" -gt 1 ]; then
        TASK_FILES=$((TASK_FILES + 1))
      fi
    fi
    HANDOFF_COUNT=$(ls -1 "$DEST/tasks/handoff-"*.md 2>/dev/null | wc -l | tr -d ' ')
    if [ "$HANDOFF_COUNT" -gt 0 ]; then
      TASK_FILES=$((TASK_FILES + HANDOFF_COUNT))
    fi

    if [ "$TASK_FILES" -gt 0 ]; then
      HAS_USER_DATA=true
    fi

    DIRS_TO_REMOVE+=("tasks/")
  fi
fi

# .claude/ subdirectories (kit-managed only)
CLAUDE_DIRS_TO_REMOVE=()
[ -d "$DEST/.claude/hooks" ] && CLAUDE_DIRS_TO_REMOVE+=(".claude/hooks/")
[ -d "$DEST/.claude/agents" ] && CLAUDE_DIRS_TO_REMOVE+=(".claude/agents/")
[ -d "$DEST/.claude/skills" ] && CLAUDE_DIRS_TO_REMOVE+=(".claude/skills/")

CLAUDE_FILES_TO_REMOVE=()
[ -f "$DEST/.claude/settings.json" ] && CLAUDE_FILES_TO_REMOVE+=(".claude/settings.json")

# --- Nothing to remove? ---

TOTAL=$(( ${#FILES_TO_REMOVE[@]} + ${#DIRS_TO_REMOVE[@]} + ${#CLAUDE_DIRS_TO_REMOVE[@]} + ${#CLAUDE_FILES_TO_REMOVE[@]} ))

if [ "$TOTAL" -eq 0 ]; then
  info "No Claude Code Kit files found in $(pwd)"
  echo "  Nothing to remove."
  echo ""
  exit 0
fi

# --- Show what will be removed ---

echo -e "  ${CYAN}Files to remove:${NC}"
echo ""

for f in "${FILES_TO_REMOVE[@]}"; do
  echo -e "    ${RED}✕${NC} $f"
done

for d in "${DIRS_TO_REMOVE[@]}"; do
  if [ "$d" = "tasks/" ] && [ "$HAS_USER_DATA" = true ]; then
    echo -e "    ${RED}✕${NC} $d ${YELLOW}(contains your data!)${NC}"
  else
    echo -e "    ${RED}✕${NC} $d"
  fi
done

for d in "${CLAUDE_DIRS_TO_REMOVE[@]}"; do
  echo -e "    ${RED}✕${NC} $d"
done

for f in "${CLAUDE_FILES_TO_REMOVE[@]}"; do
  echo -e "    ${RED}✕${NC} $f"
done

# Check if .claude/ will be empty after removal
CLAUDE_WILL_BE_EMPTY=false
if [ -d "$DEST/.claude" ]; then
  # Count items that will remain in .claude/ after removal
  REMAINING=0
  for item in "$DEST/.claude/"*; do
    [ -e "$item" ] || continue
    basename=$(basename "$item")
    # Skip items we're removing
    case "$basename" in
      hooks|agents|skills|settings.json) continue ;;
      .DS_Store) continue ;;
      *) REMAINING=$((REMAINING + 1)) ;;
    esac
  done
  if [ "$REMAINING" -eq 0 ]; then
    CLAUDE_WILL_BE_EMPTY=true
    echo -e "    ${DIM}(will also remove empty .claude/ directory)${NC}"
  fi
fi

echo ""

# Warn about user data
if [ "$HAS_USER_DATA" = true ]; then
  warn "tasks/ contains your session data (lessons, decisions, or handoffs)"
  echo -e "       Use ${CYAN}--keep-tasks${NC} to preserve it"
  echo ""
fi

# --- Dry run exits here ---

if [ "$DRY_RUN" = true ]; then
  info "Dry run — nothing was removed"
  echo ""
  exit 0
fi

# --- Confirm ---

if [ "$FORCE" != true ]; then
  read -p "  Remove all listed files? (y/N) " -n 1 -r
  echo ""
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Cancelled."
    echo ""
    exit 0
  fi
fi

# --- Remove ---

# Root files
for f in "${FILES_TO_REMOVE[@]}"; do
  rm -f "$DEST/$f"
  ok "Removed $f"
done

# Directories
for d in "${DIRS_TO_REMOVE[@]}"; do
  rm -rf "$DEST/$d"
  ok "Removed $d"
done

# .claude/ subdirectories
for d in "${CLAUDE_DIRS_TO_REMOVE[@]}"; do
  rm -rf "$DEST/$d"
  ok "Removed $d"
done

# .claude/ files
for f in "${CLAUDE_FILES_TO_REMOVE[@]}"; do
  rm -f "$DEST/$f"
  ok "Removed $f"
done

# Clean up empty .claude/ directory
if [ "$CLAUDE_WILL_BE_EMPTY" = true ] && [ -d "$DEST/.claude" ]; then
  # Remove .DS_Store if it's the only thing left
  rm -f "$DEST/.claude/.DS_Store"
  rmdir "$DEST/.claude" 2>/dev/null && ok "Removed empty .claude/" || true
fi

echo ""
echo "  Claude Code Kit has been removed."
echo ""
echo "  Note: Your .gitignore was not modified."
echo "  You may want to remove kit-related entries manually."
echo ""
