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
KEEP_PROJECT=false
KEEP_WIKI=false
KEEP_ARTIFACTS=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

info()  { echo -e "${BLUE}[info]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ok]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC}  $*"; }
error() { echo -e "${RED}[error]${NC} $*"; exit 1; }

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
    --keep-project|-p)
      KEEP_PROJECT=true
      shift
      ;;
    --keep-wiki)
      KEEP_WIKI=true
      shift
      ;;
    --keep-artifacts)
      KEEP_ARTIFACTS=true
      shift
      ;;
    --help|-h)
      echo "Usage: uninstall.sh [--dry-run] [--force] [--keep-tasks] [--keep-project] [--keep-wiki] [--keep-artifacts]"
      echo ""
      echo "Options:"
      echo "  --dry-run, -n       Show what would be removed without deleting"
      echo "  --force, -f         Remove without confirmation"
      echo "  --keep-tasks, -k    Keep tasks/ directory (lessons, decisions, handoffs)"
      echo "  --keep-project, -p  Keep project overlay files (CLAUDE.project.md, agent_docs/project/, .claude/hooks/project/)"
      echo "  --keep-wiki         Keep WIKI.md, raw-sources/, and wiki/ (knowledge wiki module data)"
      echo "  --keep-artifacts    Keep ARTIFACTS.md and artifacts/ (HTML artifacts module data)"
      echo "  --help, -h          Show this help"
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
HAS_WIKI_USER_DATA=false
HAS_ARTIFACTS_USER_DATA=false

# Root files
[ -f "$DEST/VERSION" ] && FILES_TO_REMOVE+=("VERSION")
[ -f "$DEST/.kit-manifest" ] && FILES_TO_REMOVE+=(".kit-manifest")
[ -f "$DEST/CLAUDE.md" ] && FILES_TO_REMOVE+=("CLAUDE.md")
[ -f "$DEST/CODEBASE_MAP.md" ] && FILES_TO_REMOVE+=("CODEBASE_MAP.md")

# Project overlay files
PROJECT_FILES=()
[ -f "$DEST/CLAUDE.project.md" ] && PROJECT_FILES+=("CLAUDE.project.md")
[ -d "$DEST/agent_docs/project" ] && PROJECT_FILES+=("agent_docs/project/")
[ -d "$DEST/.claude/hooks/project" ] && PROJECT_FILES+=(".claude/hooks/project/")

if [ "$KEEP_PROJECT" = true ]; then
  if [ "${#PROJECT_FILES[@]}" -gt 0 ]; then
    warn "Keeping project overlay files (--keep-project)"
  fi
else
  for f in ${PROJECT_FILES[@]+"${PROJECT_FILES[@]}"}; do
    case "$f" in
      */) DIRS_TO_REMOVE+=("$f") ;;
      *)  FILES_TO_REMOVE+=("$f") ;;
    esac
  done
fi

# Directories
if [ -d "$DEST/agent_docs" ]; then
  if [ "$KEEP_PROJECT" = true ] && [ -d "$DEST/agent_docs/project" ]; then
    # Remove kit files only, preserve project/ subdirectory
    DIRS_TO_REMOVE+=("agent_docs/*.md")
  else
    DIRS_TO_REMOVE+=("agent_docs/")
  fi
fi
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
    # find is pipefail-safe when no matches (unlike ls glob)
    HANDOFF_COUNT=$(find "$DEST/tasks" -maxdepth 1 -type f -name "handoff-*.md" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$HANDOFF_COUNT" -gt 0 ]; then
      TASK_FILES=$((TASK_FILES + HANDOFF_COUNT))
    fi

    if [ "$TASK_FILES" -gt 0 ]; then
      HAS_USER_DATA=true
    fi

    DIRS_TO_REMOVE+=("tasks/")
  fi
fi

# Wiki module (optional, installed via --wiki) — may contain user data
WIKI_PRESENT=false
if [ -f "$DEST/WIKI.md" ] || [ -d "$DEST/wiki" ] || [ -d "$DEST/raw-sources" ]; then
  WIKI_PRESENT=true
fi
if [ "$WIKI_PRESENT" = true ]; then
  if [ "$KEEP_WIKI" = true ]; then
    warn "Keeping WIKI.md, wiki/, raw-sources/ (--keep-wiki)"
  else
    # User-data detection: any source file, or wiki pages beyond seed
    WIKI_USER_FILES=0
    if [ -d "$DEST/raw-sources" ]; then
      RAW_COUNT=$(find "$DEST/raw-sources" -mindepth 1 -type f ! -name ".DS_Store" 2>/dev/null | wc -l | tr -d ' ')
      WIKI_USER_FILES=$((WIKI_USER_FILES + RAW_COUNT))
    fi
    if [ -d "$DEST/wiki" ]; then
      for sub in summaries entities concepts; do
        if [ -d "$DEST/wiki/$sub" ]; then
          SUB_COUNT=$(find "$DEST/wiki/$sub" -mindepth 1 -type f ! -name ".DS_Store" 2>/dev/null | wc -l | tr -d ' ')
          WIKI_USER_FILES=$((WIKI_USER_FILES + SUB_COUNT))
        fi
      done
      # log.md beyond seed (template has just the header line)
      if [ -f "$DEST/wiki/log.md" ]; then
        LOG_LINES=$(wc -l < "$DEST/wiki/log.md" | tr -d ' ')
        [ "$LOG_LINES" -gt 1 ] && WIKI_USER_FILES=$((WIKI_USER_FILES + 1))
      fi
    fi
    if [ "$WIKI_USER_FILES" -gt 0 ]; then
      HAS_WIKI_USER_DATA=true
    fi

    [ -f "$DEST/WIKI.md" ] && FILES_TO_REMOVE+=("WIKI.md")
    [ -d "$DEST/wiki" ] && DIRS_TO_REMOVE+=("wiki/")
    [ -d "$DEST/raw-sources" ] && DIRS_TO_REMOVE+=("raw-sources/")
  fi
fi

# HTML artifacts module (optional, installed via --html) — may contain user data
ARTIFACTS_PRESENT=false
if [ -f "$DEST/ARTIFACTS.md" ] || [ -d "$DEST/artifacts" ]; then
  ARTIFACTS_PRESENT=true
fi
if [ "$ARTIFACTS_PRESENT" = true ]; then
  if [ "$KEEP_ARTIFACTS" = true ]; then
    warn "Keeping ARTIFACTS.md, artifacts/ (--keep-artifacts)"
  else
    # User-data detection: any artifact file beyond the two seed templates
    if [ -d "$DEST/artifacts" ]; then
      ART_USER_FILES=$(find "$DEST/artifacts" -mindepth 1 -maxdepth 1 -type f \
        ! -name "design-system.html" ! -name "index.html" ! -name ".DS_Store" 2>/dev/null | wc -l | tr -d ' ')
      if [ "$ART_USER_FILES" -gt 0 ]; then
        HAS_ARTIFACTS_USER_DATA=true
      fi
    fi

    [ -f "$DEST/ARTIFACTS.md" ] && FILES_TO_REMOVE+=("ARTIFACTS.md")
    [ -d "$DEST/artifacts" ] && DIRS_TO_REMOVE+=("artifacts/")
  fi
fi

# .claude/ subdirectories (kit-managed only)
CLAUDE_DIRS_TO_REMOVE=()
if [ -d "$DEST/.claude/hooks" ]; then
  if [ "$KEEP_PROJECT" = true ] && [ -d "$DEST/.claude/hooks/project" ]; then
    # Remove kit hooks only, preserve project/ subdirectory
    CLAUDE_DIRS_TO_REMOVE+=(".claude/hooks/*.sh")
  else
    CLAUDE_DIRS_TO_REMOVE+=(".claude/hooks/")
  fi
fi
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

if [ ${#FILES_TO_REMOVE[@]} -gt 0 ]; then
  for f in "${FILES_TO_REMOVE[@]}"; do
    echo -e "    ${RED}✕${NC} $f"
  done
fi

if [ ${#DIRS_TO_REMOVE[@]} -gt 0 ]; then
  for d in "${DIRS_TO_REMOVE[@]}"; do
    if [ "$d" = "tasks/" ] && [ "$HAS_USER_DATA" = true ]; then
      echo -e "    ${RED}✕${NC} $d ${YELLOW}(contains your data!)${NC}"
    elif { [ "$d" = "wiki/" ] || [ "$d" = "raw-sources/" ]; } && [ "$HAS_WIKI_USER_DATA" = true ]; then
      echo -e "    ${RED}✕${NC} $d ${YELLOW}(contains your data!)${NC}"
    elif [ "$d" = "artifacts/" ] && [ "$HAS_ARTIFACTS_USER_DATA" = true ]; then
      echo -e "    ${RED}✕${NC} $d ${YELLOW}(contains your data!)${NC}"
    else
      echo -e "    ${RED}✕${NC} $d"
    fi
  done
fi

if [ ${#CLAUDE_DIRS_TO_REMOVE[@]} -gt 0 ]; then
  for d in "${CLAUDE_DIRS_TO_REMOVE[@]}"; do
    echo -e "    ${RED}✕${NC} $d"
  done
fi

if [ ${#CLAUDE_FILES_TO_REMOVE[@]} -gt 0 ]; then
  for f in "${CLAUDE_FILES_TO_REMOVE[@]}"; do
    echo -e "    ${RED}✕${NC} $f"
  done
fi

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
      hooks|agents|skills|settings.json|settings.local.json) continue ;;
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

# Warn about wiki user data
if [ "$HAS_WIKI_USER_DATA" = true ]; then
  warn "wiki/ or raw-sources/ contains your knowledge data (ingested sources, wiki pages)"
  echo -e "       Use ${CYAN}--keep-wiki${NC} to preserve WIKI.md + wiki/ + raw-sources/"
  echo ""
fi

# Warn about artifacts user data
if [ "$HAS_ARTIFACTS_USER_DATA" = true ]; then
  warn "artifacts/ contains your generated HTML artifacts (specs, reports, etc.)"
  echo -e "       Use ${CYAN}--keep-artifacts${NC} to preserve ARTIFACTS.md + artifacts/"
  echo ""
fi

# Warn about project overlay files being removed
if [ "$KEEP_PROJECT" = false ] && [ "${#PROJECT_FILES[@]}" -gt 0 ]; then
  warn "Project overlay files will be removed (your project-specific customizations)"
  echo -e "       Use ${CYAN}--keep-project${NC} to preserve them"
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
  read -p "  Remove all listed files? (y/N) " -n 1 -r < /dev/tty
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
if [ ${#FILES_TO_REMOVE[@]} -gt 0 ]; then
  for f in "${FILES_TO_REMOVE[@]}"; do
    rm -f "$DEST/$f"
    ok "Removed $f"
  done
fi

# Directories
if [ ${#DIRS_TO_REMOVE[@]} -gt 0 ]; then
  for d in "${DIRS_TO_REMOVE[@]}"; do
    case "$d" in
      *\*.md|*\*.sh)
        # Glob pattern — remove matching files, then try to rmdir the parent
        local_dir="${d%/*}"
        rm -f "$DEST/"$d 2>/dev/null
        rmdir "$DEST/$local_dir" 2>/dev/null || true
        ok "Removed kit files from $local_dir/"
        ;;
      *)
        rm -rf "$DEST/$d"
        ok "Removed $d"
        ;;
    esac
  done
fi

# .claude/ subdirectories
if [ ${#CLAUDE_DIRS_TO_REMOVE[@]} -gt 0 ]; then
  for d in "${CLAUDE_DIRS_TO_REMOVE[@]}"; do
    case "$d" in
      *\*.sh)
        # Glob pattern — remove matching files, then try to rmdir the parent
        local_dir="${d%/*}"
        rm -f "$DEST/"$d 2>/dev/null
        rmdir "$DEST/$local_dir" 2>/dev/null || true
        ok "Removed kit files from $local_dir/"
        ;;
      *)
        rm -rf "$DEST/$d"
        ok "Removed $d"
        ;;
    esac
  done
fi

# .claude/ files
if [ ${#CLAUDE_FILES_TO_REMOVE[@]} -gt 0 ]; then
  for f in "${CLAUDE_FILES_TO_REMOVE[@]}"; do
    rm -f "$DEST/$f"
    ok "Removed $f"
  done
fi

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
