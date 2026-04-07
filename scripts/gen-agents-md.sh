#!/usr/bin/env bash
#
# gen-agents-md.sh — Generate AGENTS.md from kit sources
#
# Produces a cross-tool AGENTS.md (Linux Foundation standard) from:
#   - CLAUDE.md (core rules)
#   - CLAUDE.project.md (project-specific overrides)
#   - CODEBASE_MAP.md (architecture summary)
#   - agent_docs/conventions.md (code style)
#
# AGENTS.md is a ONE-WAY derived output. Do not edit it directly.
# Source of truth remains CLAUDE.md + CLAUDE.project.md.
#
# Usage:
#   ./scripts/gen-agents-md.sh              # Generate AGENTS.md in project root
#   ./scripts/gen-agents-md.sh /path/to/dir # Generate in specified directory
#

set -euo pipefail

DEST="${1:-.}"
OUTFILE="$DEST/AGENTS.md"

# --- Helpers ---

# Extract section content between ## headings (returns body without the heading)
extract_section() {
  local file="$1"
  local heading="$2"
  [ -f "$file" ] || return 0
  awk -v h="$heading" '
    $0 ~ "^## " h { found=1; next }
    found && /^## / { exit }
    found { print }
  ' "$file" | sed '/^$/{ N; /^\n$/d; }' | sed '1{ /^$/d; }' | sed '${ /^$/d; }'
}

# Extract non-comment, non-empty lines from CLAUDE.project.md sections
extract_project_section() {
  local file="$1"
  local heading="$2"
  [ -f "$file" ] || return 0
  extract_section "$file" "$heading" | grep -v '^<!--' | grep -v -e '-->' | grep -v '^$' || true
}

# --- Check sources exist ---

if [ ! -f "$DEST/CLAUDE.md" ]; then
  echo "Error: CLAUDE.md not found in $DEST"
  echo "Run this from the project root or pass the project directory."
  exit 1
fi

# --- Generate ---

cat > "$OUTFILE" << 'HEADER'
<!-- GENERATED FILE — do not edit directly -->
<!-- Regenerate with: ./scripts/gen-agents-md.sh -->
<!-- Source of truth: CLAUDE.md + CLAUDE.project.md -->

# AGENTS.md

HEADER

# --- Project overview (from CODEBASE_MAP.md) ---
if [ -f "$DEST/CODEBASE_MAP.md" ]; then
  WHAT=$(extract_section "$DEST/CODEBASE_MAP.md" "What")
  WHY=$(extract_section "$DEST/CODEBASE_MAP.md" "Why")
  STACK=$(extract_section "$DEST/CODEBASE_MAP.md" "Tech Stack")

  if [ -n "$WHAT" ] || [ -n "$WHY" ]; then
    {
      echo "## Project Overview"
      echo ""
      [ -n "$WHAT" ] && echo "$WHAT" && echo ""
      [ -n "$WHY" ] && echo "$WHY" && echo ""
    } >> "$OUTFILE"
  fi

  if [ -n "$STACK" ]; then
    {
      echo "## Tech Stack"
      echo ""
      echo "$STACK"
      echo ""
    } >> "$OUTFILE"
  fi
fi

# --- Key commands (from CODEBASE_MAP.md) ---
if [ -f "$DEST/CODEBASE_MAP.md" ]; then
  COMMANDS=$(extract_section "$DEST/CODEBASE_MAP.md" "Key Commands")
  if [ -n "$COMMANDS" ]; then
    {
      echo "## Key Commands"
      echo ""
      echo "$COMMANDS"
      echo ""
    } >> "$OUTFILE"
  fi
fi

# --- Core workflow rules (from CLAUDE.md) ---
{
  echo "## Workflow"
  echo ""
  echo "- Plan before implementing. For tasks touching 3+ files, write a plan first."
  echo "- Verify every task: typecheck, lint, test, smoke test — in that order."
  echo "- Touch only files directly required by the task. No opportunistic refactoring."
  echo "- State assumptions explicitly. If 2+ valid approaches exist, present them."
  echo ""
} >> "$OUTFILE"

# --- Protected changes (from CLAUDE.md) ---
{
  echo "## Protected Changes (Approval Required)"
  echo ""
  echo "Stop and request approval before:"
  echo "- New dependencies"
  echo "- Database schema changes"
  echo "- API contract changes"
  echo "- Auth / permission logic"
  echo "- Build system or core architecture changes"
  echo ""
} >> "$OUTFILE"

# --- Project-specific context (from CLAUDE.project.md) ---
if [ -f "$DEST/CLAUDE.project.md" ]; then
  PROJECT_CTX=$(extract_project_section "$DEST/CLAUDE.project.md" "Project Context")
  STACK_RULES=$(extract_project_section "$DEST/CLAUDE.project.md" "Stack-Specific Rules")
  EXTRA_PROTECTED=$(extract_project_section "$DEST/CLAUDE.project.md" "Project-Specific Protected Changes")

  # Only emit sections that have real content (not just --- separators)
  PROJECT_CTX_CLEAN=$(echo "$PROJECT_CTX" | grep -v '^-*$' | tr -d '[:space:]' || true)
  if [ -n "$PROJECT_CTX_CLEAN" ]; then
    {
      echo "## Project-Specific Context"
      echo ""
      echo "$PROJECT_CTX"
      echo ""
    } >> "$OUTFILE"
  fi

  STACK_RULES_CLEAN=$(echo "$STACK_RULES" | grep -v '^-*$' | tr -d '[:space:]' || true)
  if [ -n "$STACK_RULES_CLEAN" ]; then
    {
      echo "## Stack-Specific Rules"
      echo ""
      echo "$STACK_RULES"
      echo ""
    } >> "$OUTFILE"
  fi

  EXTRA_PROTECTED_CLEAN=$(echo "$EXTRA_PROTECTED" | grep -v '^-*$' | tr -d '[:space:]' || true)
  if [ -n "$EXTRA_PROTECTED_CLEAN" ]; then
    {
      echo "## Additional Protected Changes"
      echo ""
      echo "$EXTRA_PROTECTED"
      echo ""
    } >> "$OUTFILE"
  fi
fi

# --- Code conventions (from conventions.md) ---
if [ -f "$DEST/agent_docs/conventions.md" ]; then
  {
    echo "## Code Conventions"
    echo ""
    echo "- Group by feature/domain, not by type."
    echo "- Names describe **what**, not **how**. Booleans: \`is\`, \`has\`, \`should\` prefix."
    echo "- Comments explain **why**, not **what**. No commented-out code."
    echo "- Fail fast — don't swallow errors. Handle them at the right level."
    echo "- Group imports: stdlib → external → internal. No circular imports."
    echo "- One logical change per commit. Message explains **why**, diff shows **what**."
    echo ""
  } >> "$OUTFILE"
fi

# --- Architecture (from CODEBASE_MAP.md) ---
if [ -f "$DEST/CODEBASE_MAP.md" ]; then
  ARCH=$(extract_section "$DEST/CODEBASE_MAP.md" "Architecture")
  if [ -n "$ARCH" ]; then
    {
      echo "## Architecture"
      echo ""
      echo "$ARCH"
      echo ""
    } >> "$OUTFILE"
  fi
fi

# --- Directory structure (from CODEBASE_MAP.md) ---
if [ -f "$DEST/CODEBASE_MAP.md" ]; then
  DIRS=$(extract_section "$DEST/CODEBASE_MAP.md" "Directory Structure")
  if [ -n "$DIRS" ]; then
    {
      echo "## Directory Structure"
      echo ""
      echo "$DIRS"
      echo ""
    } >> "$OUTFILE"
  fi
fi

# Line count for output
LINES=$(wc -l < "$OUTFILE" | tr -d ' ')
echo "Generated $OUTFILE ($LINES lines)"
