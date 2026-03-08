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
# Returns the count of newly added files.
upgrade_dir() {
  local src_dir="$1" dest_dir="$2" pattern="${3:-*}" label="$4"
  local added=0
  mkdir -p "$dest_dir"
  for src_file in "$src_dir"/$pattern; do
    [ -f "$src_file" ] || continue
    local basename
    basename=$(basename "$src_file")
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
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/secret-scan.sh"
          },
          {
            "type": "command",
            "command": ".claude/hooks/auto-lint.sh"
          },
          {
            "type": "command",
            "command": ".claude/hooks/auto-format.sh"
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
    --profile|-p)
      PROFILE="$2"
      shift 2
      ;;
    --upgrade|-u)
      UPGRADE=true
      shift
      ;;
    --help|-h)
      echo "Usage: install.sh [--template nextjs|node-api|python-fastapi] [--profile minimal|standard|strict] [--upgrade]"
      echo ""
      echo "Options:"
      echo "  --template, -t   Use a stack-specific template (nextjs, node-api, python-fastapi)"
      echo "  --profile, -p    Installation profile (default: standard)"
      echo "                     minimal  — hooks only, no CLAUDE.md or docs"
      echo "                     standard — full kit with default hooks"
      echo "                     strict   — full kit with all hooks enabled"
      echo "  --upgrade, -u    Update existing installation (adds new files, skips existing)"
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

# Validate profile
case "$PROFILE" in
  minimal|standard|strict) ;;
  *) error "Unknown profile: $PROFILE. Options: minimal, standard, strict" ;;
esac

# Warn if minimal + template (template is ignored for minimal)
if [ "$PROFILE" = "minimal" ] && [ -n "$TEMPLATE" ]; then
  warn "Template is ignored with minimal profile (no CLAUDE.md or docs installed)"
  TEMPLATE=""
fi

echo ""
echo "  Claude Code Kit Installer"
echo "  ========================="
echo "  Profile: $PROFILE"
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

# --- Profile: standard and strict get docs, tasks, scripts ---
if [ "$PROFILE" != "minimal" ]; then

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
  elif [ "$UPGRADE" = true ]; then
    upgrade_dir "$TMPDIR/agent_docs" "$DEST/agent_docs" "*.md" "agent_docs"
  else
    warn "Skipped agent_docs/ (already exists)"
  fi

  # Copy tasks/
  if [ ! -d "$DEST/tasks" ]; then
    cp -r "$TMPDIR/tasks" "$DEST/tasks"
    ok "Created tasks/"
  elif [ "$UPGRADE" = true ]; then
    upgrade_dir "$TMPDIR/tasks" "$DEST/tasks" "*.md" "tasks"
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
  if [ ! -f "$DEST/scripts/statusline.sh" ]; then
    cp "$TMPDIR/scripts/statusline.sh" "$DEST/scripts/statusline.sh"
    chmod +x "$DEST/scripts/statusline.sh"
    ok "Created scripts/statusline.sh"
  else
    warn "Skipped scripts/statusline.sh (already exists)"
  fi

fi

# Copy hooks
if [ ! -d "$DEST/.claude/hooks" ]; then
  mkdir -p "$DEST/.claude/hooks"
  cp "$TMPDIR/.claude/hooks/"*.sh "$DEST/.claude/hooks/"
  chmod +x "$DEST/.claude/hooks/"*.sh
  HOOK_COUNT=$(ls -1 "$DEST/.claude/hooks/"*.sh 2>/dev/null | wc -l | tr -d ' ')
  ok "Created .claude/hooks/ ($HOOK_COUNT hooks)"
elif [ "$UPGRADE" = true ]; then
  upgrade_dir "$TMPDIR/.claude/hooks" "$DEST/.claude/hooks" "*.sh" ".claude/hooks"
  chmod +x "$DEST/.claude/hooks/"*.sh 2>/dev/null
else
  warn "Skipped .claude/hooks/ (already exists)"
fi

# --- Profile: standard and strict get agents and skills ---
if [ "$PROFILE" != "minimal" ]; then

  # Copy agents
  if [ ! -d "$DEST/.claude/agents" ]; then
    mkdir -p "$DEST/.claude/agents"
    cp "$TMPDIR/.claude/agents/"*.md "$DEST/.claude/agents/"
    ok "Created .claude/agents/ (security-reviewer, code-reviewer, planner)"
  elif [ "$UPGRADE" = true ]; then
    upgrade_dir "$TMPDIR/.claude/agents" "$DEST/.claude/agents" "*.md" ".claude/agents"
  else
    warn "Skipped .claude/agents/ (already exists)"
  fi

  # Copy skills
  if [ ! -d "$DEST/.claude/skills" ]; then
    mkdir -p "$DEST/.claude/skills"
    cp -r "$TMPDIR/.claude/skills/"* "$DEST/.claude/skills/"
    ok "Created .claude/skills/ (skill-extractor)"
  elif [ "$UPGRADE" = true ]; then
    # Skills have subdirectories — copy new skill dirs only
    for skill_dir in "$TMPDIR/.claude/skills/"*/; do
      [ -d "$skill_dir" ] || continue
      local_name=$(basename "$skill_dir")
      if [ ! -d "$DEST/.claude/skills/$local_name" ]; then
        cp -r "$skill_dir" "$DEST/.claude/skills/$local_name"
        ok "Added .claude/skills/$local_name"
      fi
    done
  else
    warn "Skipped .claude/skills/ (already exists)"
  fi

fi

# Copy settings.json (hooks + permissions config)
if [ ! -f "$DEST/.claude/settings.json" ]; then
  if [ "$PROFILE" = "strict" ]; then
    generate_strict_settings > "$DEST/.claude/settings.json"
    ok "Created .claude/settings.json (strict — all hooks enabled)"
  else
    cp "$TMPDIR/.claude/settings.json" "$DEST/.claude/settings.json"
    ok "Created .claude/settings.json (hooks + permissions config)"
  fi
elif [ "$UPGRADE" = true ]; then
  warn "Kept .claude/settings.json (not auto-merged — review new hooks manually)"
else
  warn "Skipped .claude/settings.json (already exists)"
fi

echo ""
if [ "$UPGRADE" = true ]; then
  echo "  Upgrade complete! ($PROFILE profile)"
  echo ""
  echo "  Next steps:"
  echo "  1. Review new hook files in .claude/hooks/"
  echo "  2. Update .claude/settings.json to enable any new hooks"
  echo "  3. Start a Claude Code session"
elif [ "$PROFILE" = "minimal" ]; then
  echo "  Done! ($PROFILE profile)"
  echo ""
  echo "  Next steps:"
  echo "  1. Review .claude/settings.json to enable/disable hooks"
  echo "  2. Start a Claude Code session"
else
  echo "  Done! ($PROFILE profile)"
  echo ""
  echo "  Next steps:"
  echo "  1. Fill in CODEBASE_MAP.md with your project details"
  echo "  2. Run ./scripts/validate.sh to check for unfilled placeholders"
  echo "  3. Review .claude/settings.json to enable/disable hooks"
  echo "  4. Start a Claude Code session"
fi
echo ""
