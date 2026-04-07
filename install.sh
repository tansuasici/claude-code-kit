#!/usr/bin/env bash
#
# Claude Code Kit — Quick Setup
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/tansuasici/claude-code-kit/main/install.sh | bash
#
#   Or clone and run locally:
#   ./install.sh [--template nextjs|node-api|python-fastapi] [--profile minimal|standard|strict]
#

set -euo pipefail

REPO="https://github.com/tansuasici/claude-code-kit.git"
TEMPLATE=""
PROFILE="standard"
UPGRADE=false
DIFF_MODE=false
GITIGNORE=false
TARGET_VERSION=""
DEST="$(pwd)"
CLONE_DIR=""
MANIFEST_FILE=".kit-manifest"
MANIFEST_ENTRIES=()

# Track a file in the manifest (kit-managed)
manifest_add() {
  MANIFEST_ENTRIES+=("$1")
}

# Write manifest to disk
manifest_write() {
  local dest="$1"
  if [ ${#MANIFEST_ENTRIES[@]} -gt 0 ]; then
    printf '%s\n' "${MANIFEST_ENTRIES[@]}" | sort -u > "$dest/$MANIFEST_FILE"
  fi
}

# Check if a path is a project overlay (never touched by kit)
is_project_overlay() {
  local path="$1"
  case "$path" in
    *.project.*|*/project/*|*/project) return 0 ;;
    *) return 1 ;;
  esac
}

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

# --- Diff mode helpers ---

DIFF_NEW=0
DIFF_MODIFIED=0
DIFF_UPTODATE=0

# Show a colored unified diff, limited to MAX_DIFF_LINES lines
show_diff() {
  local src="$1" dest="$2"
  local max_lines=30
  local full_diff
  full_diff=$(diff -u "$dest" "$src" 2>/dev/null || true)
  [ -z "$full_diff" ] && return

  local total_lines
  total_lines=$(printf '%s\n' "$full_diff" | wc -l | tr -d ' ')
  local shown_lines=$total_lines
  if [ "$shown_lines" -gt "$max_lines" ]; then
    shown_lines=$max_lines
  fi

  printf '%s\n' "$full_diff" | head -n "$shown_lines" | while IFS= read -r line; do
    case "$line" in
      ---*|+++*) echo -e "    ${DIM}${line}${NC}" ;;
      @@*)       echo -e "    ${CYAN}${line}${NC}" ;;
      +*)        echo -e "    ${GREEN}${line}${NC}" ;;
      -*)        echo -e "    ${RED}${line}${NC}" ;;
      *)         echo "    $line" ;;
    esac
  done

  if [ "$total_lines" -gt "$max_lines" ]; then
    local remaining=$((total_lines - max_lines))
    echo -e "    ${DIM}... $remaining more lines${NC}"
  fi
  echo ""
}

# Compare a single file: new / modified / up-to-date
diff_file() {
  local src="$1" dest="$2" label="$3"
  if [ ! -f "$dest" ]; then
    echo -e "  ${GREEN}+${NC} ${label} ${GREEN}(new)${NC}"
    DIFF_NEW=$((DIFF_NEW + 1))
  elif diff -q "$src" "$dest" >/dev/null 2>&1; then
    echo -e "  ${DIM}✓${NC} ${DIM}${label} (up to date)${NC}"
    DIFF_UPTODATE=$((DIFF_UPTODATE + 1))
  else
    echo -e "  ${YELLOW}~${NC} ${label} ${YELLOW}(modified)${NC}"
    DIFF_MODIFIED=$((DIFF_MODIFIED + 1))
    show_diff "$src" "$dest"
  fi
}

# Compare all files in a directory (non-recursive)
diff_dir() {
  local src_dir="$1" dest_dir="$2" pattern="${3:-*}" label="$4"
  for src_file in "$src_dir"/$pattern; do
    [ -f "$src_file" ] || continue
    local basename
    basename=$(basename "$src_file")
    diff_file "$src_file" "$dest_dir/$basename" "$label/$basename"
  done
}

# Compare skill subdirectories
diff_skills() {
  local src_dir="$1" dest_dir="$2"
  for skill_dir in "$src_dir"/*/; do
    [ -d "$skill_dir" ] || continue
    local skill_name
    skill_name=$(basename "$skill_dir")
    if [ ! -d "$dest_dir/$skill_name" ]; then
      echo -e "  ${GREEN}+${NC} .claude/skills/${skill_name}/ ${GREEN}(new)${NC}"
      DIFF_NEW=$((DIFF_NEW + 1))
    else
      # Compare files inside the skill directory
      for src_file in "$skill_dir"*; do
        [ -f "$src_file" ] || continue
        local basename
        basename=$(basename "$src_file")
        diff_file "$src_file" "$dest_dir/$skill_name/$basename" ".claude/skills/$skill_name/$basename"
      done
      # Compare subdirectories (e.g., resources/)
      for sub_dir in "$skill_dir"*/; do
        [ -d "$sub_dir" ] || continue
        local sub_name
        sub_name=$(basename "$sub_dir")
        for src_file in "$sub_dir"*; do
          [ -f "$src_file" ] || continue
          local basename
          basename=$(basename "$src_file")
          diff_file "$src_file" "$dest_dir/$skill_name/$sub_name/$basename" ".claude/skills/$skill_name/$sub_name/$basename"
        done
      done
    fi
  done
}

# Main diff runner — read-only comparison against latest kit
run_diff() {
  echo ""
  echo "  Claude Code Kit — Diff Report"
  echo "  =============================="
  echo ""

  # Clone latest kit
  info "Downloading latest Claude Code Kit..."
  CLONE_DIR=$(mktemp -d)
  git clone --quiet --depth 1 "$REPO" "$CLONE_DIR" 2>/dev/null || error "Failed to clone repository"

  # Show version comparison
  REMOTE_VERSION="unknown"
  [ -f "$CLONE_DIR/VERSION" ] && REMOTE_VERSION=$(cat "$CLONE_DIR/VERSION" | sed 's/ *#.*//' | tr -d '[:space:]')
  LOCAL_VERSION="not installed"
  [ -f "$DEST/VERSION" ] && LOCAL_VERSION=$(cat "$DEST/VERSION" | sed 's/ *#.*//' | tr -d '[:space:]')
  echo ""
  echo -e "  Local:  ${YELLOW}v${LOCAL_VERSION}${NC}"
  echo -e "  Latest: ${GREEN}v${REMOTE_VERSION}${NC}"
  echo ""

  # Root files
  echo -e "  ${CYAN}Root Files${NC}"
  echo "  ----------"
  diff_file "$CLONE_DIR/CLAUDE.md" "$DEST/CLAUDE.md" "CLAUDE.md"
  diff_file "$CLONE_DIR/CODEBASE_MAP.md" "$DEST/CODEBASE_MAP.md" "CODEBASE_MAP.md"
  echo ""

  # agent_docs/
  echo -e "  ${CYAN}Agent Docs${NC}"
  echo "  ----------"
  diff_dir "$CLONE_DIR/agent_docs" "$DEST/agent_docs" "*.md" "agent_docs"
  echo ""

  # tasks/
  echo -e "  ${CYAN}Tasks${NC}"
  echo "  -----"
  diff_dir "$CLONE_DIR/tasks" "$DEST/tasks" "*.md" "tasks"
  echo ""

  # scripts/
  echo -e "  ${CYAN}Scripts${NC}"
  echo "  -------"
  diff_dir "$CLONE_DIR/scripts" "$DEST/scripts" "*.sh" "scripts"
  echo ""

  # .claude/hooks/
  echo -e "  ${CYAN}Hooks${NC}"
  echo "  -----"
  diff_dir "$CLONE_DIR/.claude/hooks" "$DEST/.claude/hooks" "*.sh" ".claude/hooks"
  echo ""

  # .claude/agents/
  echo -e "  ${CYAN}Agents${NC}"
  echo "  ------"
  diff_dir "$CLONE_DIR/.claude/agents" "$DEST/.claude/agents" "*.md" ".claude/agents"
  echo ""

  # .claude/skills/
  echo -e "  ${CYAN}Skills${NC}"
  echo "  ------"
  diff_skills "$CLONE_DIR/.claude/skills" "$DEST/.claude/skills"
  echo ""

  # .claude/settings.json
  echo -e "  ${CYAN}Settings${NC}"
  echo "  --------"
  if [ -f "$DEST/.claude/settings.json" ]; then
    if diff -q "$CLONE_DIR/.claude/settings.json" "$DEST/.claude/settings.json" >/dev/null 2>&1; then
      echo -e "  ${DIM}✓${NC} ${DIM}.claude/settings.json (up to date)${NC}"
      DIFF_UPTODATE=$((DIFF_UPTODATE + 1))
    else
      echo -e "  ${YELLOW}~${NC} .claude/settings.json ${YELLOW}(modified — manual review recommended)${NC}"
      DIFF_MODIFIED=$((DIFF_MODIFIED + 1))
      show_diff "$CLONE_DIR/.claude/settings.json" "$DEST/.claude/settings.json"
    fi
  else
    echo -e "  ${GREEN}+${NC} .claude/settings.json ${GREEN}(new)${NC}"
    DIFF_NEW=$((DIFF_NEW + 1))
  fi
  echo ""

  # .gitignore check
  if [ -f "$CLONE_DIR/.gitignore" ]; then
    echo -e "  ${CYAN}Git Ignore${NC}"
    echo "  ----------"
    diff_file "$CLONE_DIR/.gitignore" "$DEST/.gitignore" ".gitignore"
    echo ""
  fi

  # Project Overlay status (informational, not diffed)
  echo -e "  ${CYAN}Project Overlay${NC}"
  echo "  ---------------"
  if [ -f "$DEST/CLAUDE.project.md" ]; then
    echo -e "  ${DIM}✓${NC} ${DIM}CLAUDE.project.md (project-managed, not compared)${NC}"
  else
    echo -e "  ${DIM}—${NC} ${DIM}CLAUDE.project.md (not created yet)${NC}"
  fi
  if [ -d "$DEST/agent_docs/project" ]; then
    local proj_doc_count
    proj_doc_count=$(ls -1 "$DEST/agent_docs/project/"*.md 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  ${DIM}✓${NC} ${DIM}agent_docs/project/ ($proj_doc_count docs, project-managed)${NC}"
  fi
  if [ -d "$DEST/.claude/hooks/project" ]; then
    local proj_hook_count
    proj_hook_count=$(ls -1 "$DEST/.claude/hooks/project/"*.sh 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  ${DIM}✓${NC} ${DIM}.claude/hooks/project/ ($proj_hook_count hooks, project-managed)${NC}"
  fi
  echo ""

  # Summary
  echo "  =============================="
  echo -e "  ${GREEN}${DIFF_UPTODATE} up to date${NC}, ${YELLOW}${DIFF_MODIFIED} modified${NC}, ${GREEN}${DIFF_NEW} new${NC}"
  echo ""
  if [ "$DIFF_NEW" -gt 0 ]; then
    echo "  Run with --upgrade to add new files."
  fi
  if [ "$DIFF_MODIFIED" -gt 0 ]; then
    echo "  Modified files need manual review — diffs shown above."
  fi
  if [ "$DIFF_NEW" -eq 0 ] && [ "$DIFF_MODIFIED" -eq 0 ]; then
    echo "  Your installation is up to date!"
  fi
  echo ""
}

# Copy a single file if it doesn't exist. Returns 0 if copied, 1 if skipped.
copy_if_new() {
  local src="$1" dest="$2" label="$3"
  if [ ! -f "$dest" ]; then
    cp "$src" "$dest"
    ok "Added $label"
    return 0
  fi
  return 1
}

# Copy new files from src_dir into dest_dir (non-recursive, won't overwrite)
# Skips project overlay files. Tracks installed files in manifest.
upgrade_dir() {
  local src_dir="$1" dest_dir="$2" pattern="${3:-*}" label="$4"
  local added=0
  mkdir -p "$dest_dir"
  for src_file in "$src_dir"/$pattern; do
    [ -f "$src_file" ] || continue
    local basename
    basename=$(basename "$src_file")
    # Skip project overlay files
    if is_project_overlay "$basename"; then
      continue
    fi
    manifest_add "$label/$basename"
    if [ ! -f "$dest_dir/$basename" ]; then
      cp "$src_file" "$dest_dir/$basename"
      added=$((added + 1))
      ok "Added $label/$basename"
    fi
  done
  if [ "$added" -eq 0 ]; then
    info "No new files in $label/"
  fi
  return 0
}

generate_strict_settings() {
  cat <<'SETTINGS_EOF'
{
  "permissions": {
    "allow": [
      "Bash(npm test*)",
      "Bash(npm run lint*)",
      "Bash(npm run build*)",
      "Bash(npx tsc*)",
      "Bash(npx jest*)",
      "Bash(npx vitest*)",
      "Bash(npx playwright*)",
      "Bash(pytest*)",
      "Bash(mypy*)",
      "Bash(ruff*)",
      "Bash(go test*)",
      "Bash(cargo test*)",
      "Bash(cargo clippy*)",
      "Bash(git status*)",
      "Bash(git diff*)",
      "Bash(git log*)",
      "Bash(git branch*)",
      "Bash(git show*)",
      "Bash(ls*)",
      "Bash(pwd)",
      "Bash(which*)",
      "Bash(cat package.json)",
      "Bash(cat pyproject.toml)"
    ],
    "deny": [
      "Bash(curl*)",
      "Bash(wget*)",
      "Bash(ssh*)",
      "Bash(scp*)",
      "Bash(cat .env*)",
      "Bash(cat *credentials*)",
      "Bash(cat *secret*)",
      "Bash(cat *id_rsa*)",
      "Bash(cat *id_ed25519*)",
      "Bash(npm publish*)",
      "Bash(pip upload*)",
      "Bash(twine upload*)",
      "Bash(docker push*)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/protect-files.sh"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/branch-protect.sh"
          },
          {
            "type": "command",
            "command": ".claude/hooks/block-dangerous-commands.sh"
          },
          {
            "type": "command",
            "command": ".claude/hooks/conventional-commit.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/secret-scan.sh"
          },
          {
            "type": "command",
            "command": ".claude/hooks/unicode-scan.sh"
          },
          {
            "type": "command",
            "command": ".claude/hooks/loop-detect.sh"
          },
          {
            "type": "command",
            "command": ".claude/hooks/auto-lint.sh"
          },
          {
            "type": "command",
            "command": ".claude/hooks/auto-format.sh"
          },
          {
            "type": "command",
            "command": ".claude/hooks/skill-compliance.sh"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/skill-extract-reminder.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/task-complete-notify.sh"
          }
        ]
      }
    ]
  }
}
SETTINGS_EOF
}

cleanup() {
  if [ -n "$CLONE_DIR" ] && [ -d "$CLONE_DIR" ]; then
    rm -rf "$CLONE_DIR"
  fi
}
trap cleanup EXIT

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --template|-t)
      [ $# -ge 2 ] || error "--template requires an argument"
      TEMPLATE="$2"
      shift 2
      ;;
    --profile|-p)
      [ $# -ge 2 ] || error "--profile requires an argument"
      PROFILE="$2"
      shift 2
      ;;
    --upgrade|-u)
      UPGRADE=true
      shift
      ;;
    --diff|-d)
      DIFF_MODE=true
      shift
      ;;
    --gitignore|-g)
      GITIGNORE=true
      shift
      ;;
    --version|-v)
      [ $# -ge 2 ] || error "--version requires an argument"
      TARGET_VERSION="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: install.sh [--template nextjs|node-api|python-fastapi] [--profile minimal|standard|strict] [--upgrade] [--diff]"
      echo ""
      echo "Options:"
      echo "  --template, -t   Use a stack-specific template (nextjs, node-api, python-fastapi)"
      echo "  --profile, -p    Installation profile (default: standard)"
      echo "                     minimal  — hooks only, no CLAUDE.md or docs"
      echo "                     standard — full kit with default hooks"
      echo "                     strict   — full kit with all hooks enabled"
      echo "  --upgrade, -u    Update kit-managed files (skips project overlay files)"
      echo "  --diff, -d       Compare local installation against latest kit (read-only)"
      echo "  --gitignore, -g  Add kit files to .gitignore (keep kit local, don't push to repo)"
      echo "  --version, -v    Install a specific version (e.g., --version v1.0.0)"
      echo "  --help, -h       Show this help"
      echo ""
      echo "To uninstall: ./uninstall.sh (or curl -fsSL .../uninstall.sh | bash)"
      exit 0
      ;;
    --local)
      [ $# -ge 2 ] || error "--local requires a path argument"
      CLONE_DIR="$2"
      shift 2
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

# Validate profile
case "$PROFILE" in
  minimal|standard|strict) ;;
  *) error "Unknown profile: $PROFILE. Options: minimal, standard, strict" ;;
esac

# Auto-detect template if not specified
auto_detect_template() {
  local dest="$1"
  # Next.js
  for f in "next.config.js" "next.config.mjs" "next.config.ts"; do
    [ -f "$dest/$f" ] && echo "nextjs" && return
  done
  # Python
  for f in "requirements.txt" "pyproject.toml" "Pipfile" "setup.py"; do
    [ -f "$dest/$f" ] && echo "python-fastapi" && return
  done
  # Node API (package.json exists but no next.config)
  [ -f "$dest/package.json" ] && echo "node-api" && return
  echo ""
}

if [ -z "$TEMPLATE" ] && [ "$PROFILE" != "minimal" ]; then
  DETECTED_TEMPLATE=$(auto_detect_template "$DEST")
  if [ -n "$DETECTED_TEMPLATE" ]; then
    TEMPLATE="$DETECTED_TEMPLATE"
    info "Auto-detected template: $TEMPLATE"
  fi
fi

# Warn if minimal + template (template is ignored for minimal)
if [ "$PROFILE" = "minimal" ] && [ -n "$TEMPLATE" ]; then
  warn "Template is ignored with minimal profile (no CLAUDE.md or docs installed)"
  TEMPLATE=""
fi

# Diff mode — compare and exit (no changes made)
if [ "$DIFF_MODE" = true ]; then
  run_diff
  exit 0
fi

echo ""
echo "  Claude Code Kit Installer"
echo "  ========================="
echo "  Profile: $PROFILE"
if [ -n "$TARGET_VERSION" ]; then
  echo "  Version: $TARGET_VERSION"
fi
echo ""

# Check for existing files (skip for minimal — it doesn't copy these)
if [ "$UPGRADE" = true ]; then
  info "Upgrade mode — existing files will be kept, new files will be added"
else
  EXISTING=()
  if [ "$PROFILE" != "minimal" ]; then
    [ -f "$DEST/CLAUDE.md" ] && EXISTING+=("CLAUDE.md")
    [ -f "$DEST/CODEBASE_MAP.md" ] && EXISTING+=("CODEBASE_MAP.md")
  fi

  if [ ${#EXISTING[@]} -gt 0 ]; then
    warn "These files already exist and will be SKIPPED:"
    for f in ${EXISTING[@]+"${EXISTING[@]}"}; do
      echo "       - $f"
    done
    echo ""
    if [ ! -e /dev/tty ]; then
      error "Non-interactive environment detected. Use --upgrade to skip confirmation."
    fi
    read -p "  Continue? (y/N) " -n 1 -r < /dev/tty
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      info "Cancelled."
      exit 0
    fi
  fi
fi

# Clone to temp directory
# Use local source if provided (npx mode), otherwise clone from git
if [ -n "$CLONE_DIR" ]; then
  info "Using local kit source: $CLONE_DIR"
else
  CLONE_DIR=$(mktemp -d)
  if [ -n "$TARGET_VERSION" ]; then
    # Ensure version tag has v prefix
    case "$TARGET_VERSION" in
      v*) ;;
      *) TARGET_VERSION="v$TARGET_VERSION" ;;
    esac
    info "Downloading Claude Code Kit ($TARGET_VERSION)..."
    git clone --quiet --depth 1 --branch "$TARGET_VERSION" "$REPO" "$CLONE_DIR" 2>/dev/null || error "Version $TARGET_VERSION not found. Check available versions at https://github.com/tansuasici/claude-code-kit/releases"
  else
    info "Downloading Claude Code Kit (latest)..."
    git clone --quiet --depth 1 "$REPO" "$CLONE_DIR" 2>/dev/null || error "Failed to clone repository"
  fi
fi

# Read version from downloaded kit
KIT_VERSION="unknown"
if [ -f "$CLONE_DIR/VERSION" ]; then
  KIT_VERSION=$(cat "$CLONE_DIR/VERSION" | sed 's/ *#.*//' | tr -d '[:space:]')
fi

# Determine source for CLAUDE.md and CODEBASE_MAP.md
if [ -n "$TEMPLATE" ]; then
  SRC_CLAUDE="$CLONE_DIR/examples/$TEMPLATE/CLAUDE.md"
  SRC_MAP="$CLONE_DIR/examples/$TEMPLATE/CODEBASE_MAP.md"
  info "Using template: $TEMPLATE"
else
  SRC_CLAUDE="$CLONE_DIR/CLAUDE.md"
  SRC_MAP="$CLONE_DIR/CODEBASE_MAP.md"
  info "Using generic template"
fi

# Copy VERSION file (always, all profiles)
cp "$CLONE_DIR/VERSION" "$DEST/VERSION"
manifest_add "VERSION"

# --- Profile: standard and strict get docs, tasks, scripts ---
if [ "$PROFILE" != "minimal" ]; then

  # Copy CLAUDE.md
  manifest_add "CLAUDE.md"
  if [ ! -f "$DEST/CLAUDE.md" ]; then
    cp "$SRC_CLAUDE" "$DEST/CLAUDE.md"
    ok "Created CLAUDE.md"
  else
    warn "Skipped CLAUDE.md (already exists)"
  fi

  # Copy CODEBASE_MAP.md
  manifest_add "CODEBASE_MAP.md"
  if [ ! -f "$DEST/CODEBASE_MAP.md" ]; then
    cp "$SRC_MAP" "$DEST/CODEBASE_MAP.md"
    ok "Created CODEBASE_MAP.md"
  else
    warn "Skipped CODEBASE_MAP.md (already exists)"
  fi

  # Create project overlay template (never overwritten)
  if [ ! -f "$DEST/CLAUDE.project.md" ]; then
    if [ -f "$CLONE_DIR/CLAUDE.project.md" ]; then
      cp "$CLONE_DIR/CLAUDE.project.md" "$DEST/CLAUDE.project.md"
      ok "Created CLAUDE.project.md (project overlay — customize for your project)"
    fi
  else
    info "Kept CLAUDE.project.md (project overlay)"
  fi

  # Copy agent_docs/
  if [ ! -d "$DEST/agent_docs" ]; then
    cp -r "$CLONE_DIR/agent_docs" "$DEST/agent_docs"
    ok "Created agent_docs/"
    # Track all copied files in manifest
    for f in "$DEST/agent_docs/"*.md; do
      [ -f "$f" ] && manifest_add "agent_docs/$(basename "$f")"
    done
  elif [ "$UPGRADE" = true ]; then
    upgrade_dir "$CLONE_DIR/agent_docs" "$DEST/agent_docs" "*.md" "agent_docs"
  else
    warn "Skipped agent_docs/ (already exists)"
    for f in "$DEST/agent_docs/"*.md; do
      [ -f "$f" ] || continue
      local_name=$(basename "$f")
      is_project_overlay "$local_name" || manifest_add "agent_docs/$local_name"
    done
  fi

  # Create agent_docs/project/ overlay directory
  if [ ! -d "$DEST/agent_docs/project" ]; then
    mkdir -p "$DEST/agent_docs/project"
    ok "Created agent_docs/project/ (project-specific docs go here)"
  fi

  # Copy tasks/
  if [ ! -d "$DEST/tasks" ]; then
    cp -r "$CLONE_DIR/tasks" "$DEST/tasks"
    ok "Created tasks/"
    for f in "$DEST/tasks/"*.md; do
      [ -f "$f" ] && manifest_add "tasks/$(basename "$f")"
    done
  elif [ "$UPGRADE" = true ]; then
    upgrade_dir "$CLONE_DIR/tasks" "$DEST/tasks" "*.md" "tasks"
  else
    warn "Skipped tasks/ (already exists)"
    for f in "$DEST/tasks/"*.md; do
      [ -f "$f" ] && manifest_add "tasks/$(basename "$f")"
    done
  fi

  # Copy scripts
  if [ ! -d "$DEST/scripts" ]; then
    mkdir -p "$DEST/scripts"
    for f in "$CLONE_DIR/scripts/"*.sh; do
      [ -f "$f" ] || continue
      cp "$f" "$DEST/scripts/"
      manifest_add "scripts/$(basename "$f")"
    done
    chmod +x "$DEST/scripts/"*.sh 2>/dev/null || true
    SCRIPT_COUNT=$(ls -1 "$DEST/scripts/"*.sh 2>/dev/null | wc -l | tr -d ' ')
    ok "Created scripts/ ($SCRIPT_COUNT scripts)"
  elif [ "$UPGRADE" = true ]; then
    upgrade_dir "$CLONE_DIR/scripts" "$DEST/scripts" "*.sh" "scripts"
    chmod +x "$DEST/scripts/"*.sh 2>/dev/null
  else
    warn "Skipped scripts/ (already exists)"
    for f in "$DEST/scripts/"*.sh; do
      [ -f "$f" ] && manifest_add "scripts/$(basename "$f")"
    done
  fi

fi

# Copy hooks
if [ ! -d "$DEST/.claude/hooks" ]; then
  mkdir -p "$DEST/.claude/hooks"
  for f in "$CLONE_DIR/.claude/hooks/"*.sh; do
    [ -f "$f" ] || continue
    cp "$f" "$DEST/.claude/hooks/"
    manifest_add ".claude/hooks/$(basename "$f")"
  done
  # Copy shared hook library
  if [ -d "$CLONE_DIR/.claude/hooks/lib" ]; then
    mkdir -p "$DEST/.claude/hooks/lib"
    cp "$CLONE_DIR/.claude/hooks/lib/"*.sh "$DEST/.claude/hooks/lib/" 2>/dev/null || true
    manifest_add ".claude/hooks/lib"
  fi
  chmod +x "$DEST/.claude/hooks/"*.sh 2>/dev/null || true
  HOOK_COUNT=$(ls -1 "$DEST/.claude/hooks/"*.sh 2>/dev/null | wc -l | tr -d ' ')
  ok "Created .claude/hooks/ ($HOOK_COUNT hooks)"
elif [ "$UPGRADE" = true ]; then
  upgrade_dir "$CLONE_DIR/.claude/hooks" "$DEST/.claude/hooks" "*.sh" ".claude/hooks"
  # Also upgrade hook library (lib/ is not caught by *.sh glob)
  if [ -d "$CLONE_DIR/.claude/hooks/lib" ]; then
    mkdir -p "$DEST/.claude/hooks/lib"
    for lib_file in "$CLONE_DIR/.claude/hooks/lib/"*.sh; do
      [ -f "$lib_file" ] || continue
      cp "$lib_file" "$DEST/.claude/hooks/lib/"
    done
    manifest_add ".claude/hooks/lib"
    info "Updated .claude/hooks/lib/"
  fi
  chmod +x "$DEST/.claude/hooks/"*.sh 2>/dev/null
else
  warn "Skipped .claude/hooks/ (already exists)"
  for f in "$DEST/.claude/hooks/"*.sh; do
    [ -f "$f" ] && manifest_add ".claude/hooks/$(basename "$f")"
  done
fi

# Create project hooks overlay directory
if [ ! -d "$DEST/.claude/hooks/project" ]; then
  mkdir -p "$DEST/.claude/hooks/project"
  ok "Created .claude/hooks/project/ (project-specific hooks go here)"
fi

# --- Profile: standard and strict get agents and skills ---
if [ "$PROFILE" != "minimal" ]; then

  # Copy agents
  if [ ! -d "$DEST/.claude/agents" ]; then
    mkdir -p "$DEST/.claude/agents"
    for f in "$CLONE_DIR/.claude/agents/"*.md; do
      [ -f "$f" ] || continue
      cp "$f" "$DEST/.claude/agents/"
      manifest_add ".claude/agents/$(basename "$f")"
    done
    AGENT_COUNT=$(ls -1 "$DEST/.claude/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')
    ok "Created .claude/agents/ ($AGENT_COUNT agents)"
  elif [ "$UPGRADE" = true ]; then
    upgrade_dir "$CLONE_DIR/.claude/agents" "$DEST/.claude/agents" "*.md" ".claude/agents"
  else
    warn "Skipped .claude/agents/ (already exists)"
    for f in "$DEST/.claude/agents/"*.md; do
      [ -f "$f" ] && manifest_add ".claude/agents/$(basename "$f")"
    done
  fi

  # Copy skills
  if [ ! -d "$DEST/.claude/skills" ]; then
    mkdir -p "$DEST/.claude/skills"
    for f in "$CLONE_DIR/.claude/skills/"*; do [ -e "$f" ] && cp -r "$f" "$DEST/.claude/skills/"; done
    ok "Created .claude/skills/ (skill-extractor)"
    # Track skill files in manifest
    for skill_dir in "$DEST/.claude/skills/"*/; do
      [ -d "$skill_dir" ] || continue
      local_name=$(basename "$skill_dir")
      manifest_add ".claude/skills/$local_name"
    done
  elif [ "$UPGRADE" = true ]; then
    # Skills have subdirectories — copy new skill dirs only
    for skill_dir in "$CLONE_DIR/.claude/skills/"*/; do
      [ -d "$skill_dir" ] || continue
      local_name=$(basename "$skill_dir")
      manifest_add ".claude/skills/$local_name"
      if [ ! -d "$DEST/.claude/skills/$local_name" ]; then
        cp -r "$skill_dir" "$DEST/.claude/skills/$local_name"
        ok "Added .claude/skills/$local_name"
      fi
    done
  else
    warn "Skipped .claude/skills/ (already exists)"
    for skill_dir in "$DEST/.claude/skills/"*/; do
      [ -d "$skill_dir" ] || continue
      manifest_add ".claude/skills/$(basename "$skill_dir")"
    done
  fi

fi

# Copy settings.json (hooks + permissions config)
manifest_add ".claude/settings.json"
if [ ! -f "$DEST/.claude/settings.json" ]; then
  if [ "$PROFILE" = "strict" ]; then
    generate_strict_settings > "$DEST/.claude/settings.json"
    ok "Created .claude/settings.json (strict — all hooks enabled)"
  else
    cp "$CLONE_DIR/.claude/settings.json" "$DEST/.claude/settings.json"
    ok "Created .claude/settings.json (hooks + permissions config)"
  fi
elif [ "$UPGRADE" = true ]; then
  warn "Kept .claude/settings.json (not auto-merged — review new hooks manually)"
else
  warn "Skipped .claude/settings.json (already exists)"
fi

# Write manifest
manifest_add "$MANIFEST_FILE"
manifest_write "$DEST"

# --- Add kit files to .gitignore if requested ---
if [ "$GITIGNORE" = true ]; then
  GITIGNORE_FILE="$DEST/.gitignore"
  MARKER="# Claude Code Kit (local-only)"

  # Check if we already added kit entries
  if [ -f "$GITIGNORE_FILE" ] && grep -qF "$MARKER" "$GITIGNORE_FILE"; then
    warn ".gitignore already has Claude Code Kit entries — skipping"
  else
    {
      echo ""
      echo "$MARKER"
      echo "VERSION"
      echo ".kit-manifest"
      echo "CLAUDE.md"
      echo "CLAUDE.project.md"
      echo "CODEBASE_MAP.md"
      echo "agent_docs/"
      echo "tasks/"
      echo "scripts/doctor.sh"
      echo "scripts/validate.sh"
      echo "scripts/statusline.sh"
      echo "scripts/convert.sh"
      echo "scripts/validate-skills.sh"
      echo "scripts/build-skills.sh"
      echo "scripts/gen-skill-docs.sh"
      echo ".claude/"
    } >> "$GITIGNORE_FILE"
    ok "Added kit files to .gitignore (kit stays local, won't be pushed)"
  fi
fi

echo ""
if [ "$UPGRADE" = true ]; then
  echo "  Upgrade complete! (v${KIT_VERSION}, $PROFILE profile)"
  echo ""
  echo "  Next steps:"
  echo "  1. Review new hook files in .claude/hooks/"
  echo "  2. Update .claude/settings.json to enable any new hooks"
  echo "  3. Start a Claude Code session"
elif [ "$PROFILE" = "minimal" ]; then
  echo "  Done! (v${KIT_VERSION}, $PROFILE profile)"
  echo ""
  echo "  Next steps:"
  echo "  1. Review .claude/settings.json to enable/disable hooks"
  echo "  2. Start a Claude Code session"
else
  echo "  Done! (v${KIT_VERSION}, $PROFILE profile)"
  echo ""
  echo "  Next steps:"
  echo "  1. Fill in CODEBASE_MAP.md with your project details"
  echo "  2. Customize CLAUDE.project.md with project-specific rules"
  echo "  3. Run ./scripts/validate.sh to check for unfilled placeholders"
  echo "  4. Review .claude/settings.json to enable/disable hooks"
  echo "  5. Start a Claude Code session"
fi
echo ""
