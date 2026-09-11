#!/usr/bin/env bash
#
# Claude Code Kit — Quick Setup
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/tansuasici/claude-code-kit/main/install.sh | bash
#
#   Or clone and run locally:
#   ./install.sh [--template nextjs|node-api|python-fastapi|go|rust|django] [--profile minimal|standard|strict]
#

set -euo pipefail

REPO="https://github.com/tansuasici/claude-code-kit.git"
TEMPLATE=""
PROFILE="standard"
UPGRADE=false
DIFF_MODE=false
GITIGNORE=false
WIKI=false
HTML=false
TARGET_VERSION=""
LOCAL_SOURCE=false
DEST="$(pwd)"
CLONE_DIR=""
MANIFEST_FILE=".kit-manifest"
MANIFEST_ENTRIES=()
# .kit-baseline — "<sha256><TAB><path>" for every kit file this installer wrote,
# i.e. what the kit last put at each path. --upgrade compares against it to tell
# an untouched kit file (safe to update) from a locally edited one (kept, reported).
BASELINE_FILE=".kit-baseline"
BASELINE_ENTRIES=()
KIT_TEMPLATE_USED=""
TEMPLATE_EXPLICIT=false
UP_ADDED=0
UP_UPDATED=0
UP_UNCHANGED=0
UP_BACKED_UP=0
KEPT_FILES=()
CONFLICT_FILES=()
BACKUP_DIR=""

# Track a file in the manifest (kit-managed). manifest_write() is provided by
# scripts/lib/manifest.sh, sourced once the kit source tree is available below.
manifest_add() {
  MANIFEST_ENTRIES+=("$1")
}

# Create wiki index.md template
create_wiki_index() {
  cat > "$1" << 'WIKIEOF'
# Wiki Index

Last updated: —
Sources: 0 | Wiki pages: 0

## Summaries

## Entities

## Concepts

## Analyses
WIKIEOF
}

# Create wiki log.md template
create_wiki_log() {
  cat > "$1" << 'WIKIEOF'
# Wiki Log
WIKIEOF
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
  # For KIT_USER_SCRIPTS. The main flow sources it again later; the lib
  # guards against double-sourcing.
  if [ -f "$CLONE_DIR/scripts/lib/manifest.sh" ]; then
    . "$CLONE_DIR/scripts/lib/manifest.sh"
  fi

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
  diff_file "$CLONE_DIR/scaffold/CODEBASE_MAP.md" "$DEST/CODEBASE_MAP.md" "CODEBASE_MAP.md"
  echo ""

  # agent_docs/
  echo -e "  ${CYAN}Agent Docs${NC}"
  echo "  ----------"
  diff_dir "$CLONE_DIR/agent_docs" "$DEST/agent_docs" "*.md" "agent_docs"
  echo ""

  # tasks/
  echo -e "  ${CYAN}Tasks${NC}"
  echo "  -----"
  diff_dir "$CLONE_DIR/scaffold/tasks" "$DEST/tasks" "*.md" "tasks"
  echo ""

  # scripts/
  echo -e "  ${CYAN}Scripts${NC}"
  echo "  -------"
  for kit_script in $(user_script_names); do
    diff_file "$CLONE_DIR/scripts/$kit_script" "$DEST/scripts/$kit_script" "scripts/$kit_script"
  done
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
    echo "  Run with --upgrade to add new files and update kit files you haven't edited."
  fi
  if [ "$DIFF_MODIFIED" -gt 0 ]; then
    echo "  Modified files need manual review — diffs shown above."
  fi
  if [ "$DIFF_NEW" -eq 0 ] && [ "$DIFF_MODIFIED" -eq 0 ]; then
    echo "  Your installation is up to date!"
  fi
  echo ""
}

# user_script_names — the scripts/*.sh names install.sh ships: KIT_USER_SCRIPTS
# from scripts/lib/manifest.sh. The rest of scripts/ is kit-maintainer tooling
# that only runs inside the kit repo. A --version clone of a kit that predates
# the list falls back to every script, as that kit shipped.
user_script_names() {
  if [ -n "${KIT_USER_SCRIPTS:-}" ]; then
    echo "$KIT_USER_SCRIPTS"
    return 0
  fi
  local f
  for f in "$CLONE_DIR/scripts/"*.sh; do
    [ -f "$f" ] && basename "$f"
  done
  return 0
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

# Copy new files from src_dir into dest_dir (non-recursive, never overwrites).
# For user-owned scaffolds (tasks/): the kit seeds them once, the project owns
# them after that. Skips project overlay files. Tracks installed files in manifest.
seed_dir() {
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

# --- Upgrade helpers ---

# file_hash <path> — sha256 of a file; empty when no hashing tool exists.
file_hash() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$1"
  fi
}

# baseline_lookup <rel> — the hash the kit last installed at <rel>, from the
# .kit-baseline the previous run left (rewritten only at the end of this run).
baseline_lookup() {
  [ -f "$DEST/$BASELINE_FILE" ] || return 0
  awk -F'\t' -v p="$1" '!/^#/ && $2 == p { print $1; exit }' "$DEST/$BASELINE_FILE"
}

# baseline_template — the template the previous run recorded for CLAUDE.md.
baseline_template() {
  [ -f "$DEST/$BASELINE_FILE" ] || return 0
  awk -F'\t' '$1 == "#template" { print $2; exit }' "$DEST/$BASELINE_FILE"
}

# baseline_record <src> <rel> — record that the kit's <src> now sits at <rel>.
baseline_record() {
  local h
  h=$(file_hash "$1")
  if [ -n "$h" ]; then
    BASELINE_ENTRIES+=("$h"$'\t'"$2")
  fi
}

# baseline_record_tree <src_dir> <rel_dir> — baseline_record every file in a tree.
baseline_record_tree() {
  local src_dir="${1%/}" rel_dir="$2" f
  while IFS= read -r f; do
    baseline_record "$f" "$rel_dir/${f#"$src_dir"/}"
  done < <(find "$src_dir" -type f ! -name .DS_Store)
}

# backup_file <rel> — copy <rel> into this run's .kit-backup/<UTC stamp>/ before
# it is overwritten. The .kit-backup/ directory ignores itself in git.
backup_file() {
  if [ -z "$BACKUP_DIR" ]; then
    BACKUP_DIR=".kit-backup/$(date -u +%Y%m%dT%H%M%SZ)"
    mkdir -p "$DEST/$BACKUP_DIR"
    [ -f "$DEST/.kit-backup/.gitignore" ] || printf '*\n!.gitignore\n' > "$DEST/.kit-backup/.gitignore"
  fi
  mkdir -p "$DEST/$BACKUP_DIR/$(dirname "$1")"
  cp -p "$DEST/$1" "$DEST/$BACKUP_DIR/$1"
}

# upgrade_file <src> <rel> — bring one kit-managed file up to date:
#   missing                            → added
#   local == kit                       → unchanged
#   no baseline entry (older install)  → updated, previous copy backed up (a local
#                                        edit can't be told from an older kit file)
#   local == baseline                  → untouched since install → updated
#   local != baseline, kit == baseline → edited locally, kit unchanged → kept
#   local != baseline, kit != baseline → conflict: kept, kit copy → <rel>.kit-new
upgrade_file() {
  local src="$1" rel="$2" dest="$DEST/$2" base src_hash local_hash
  if [ ! -f "$dest" ]; then
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    baseline_record "$src" "$rel"
    UP_ADDED=$((UP_ADDED + 1))
    ok "Added $rel"
    return 0
  fi
  if cmp -s "$src" "$dest"; then
    baseline_record "$src" "$rel"
    UP_UNCHANGED=$((UP_UNCHANGED + 1))
    return 0
  fi
  base=$(baseline_lookup "$rel")
  src_hash=$(file_hash "$src")
  local_hash=$(file_hash "$dest")
  if [ -z "$base" ] || [ -z "$src_hash" ]; then
    backup_file "$rel"
    cp "$src" "$dest"
    baseline_record "$src" "$rel"
    UP_UPDATED=$((UP_UPDATED + 1))
    UP_BACKED_UP=$((UP_BACKED_UP + 1))
    ok "Updated $rel (previous copy backed up)"
  elif [ "$local_hash" = "$base" ]; then
    cp "$src" "$dest"
    baseline_record "$src" "$rel"
    UP_UPDATED=$((UP_UPDATED + 1))
    ok "Updated $rel"
  elif [ "$src_hash" = "$base" ]; then
    # Baseline entry carries over unchanged (baseline_write keeps old entries).
    KEPT_FILES+=("$rel")
  else
    cp "$src" "$dest.kit-new"
    # Record the version offered, so the next upgrade stays quiet unless the kit
    # changes this file again.
    baseline_record "$src" "$rel"
    CONFLICT_FILES+=("$rel")
    warn "Conflict: $rel has local edits and a kit update — kit version saved as $rel.kit-new"
  fi
}

# upgrade_tree <src_dir> <rel_dir> — upgrade_file every file in a tree (skills).
upgrade_tree() {
  local src_dir="${1%/}" rel_dir="$2" f
  while IFS= read -r f; do
    upgrade_file "$f" "$rel_dir/${f#"$src_dir"/}"
  done < <(find "$src_dir" -type f ! -name .DS_Store)
}

# upgrade_dir <src_dir> <dest_dir> <pattern> <label> — upgrade_file each matching
# file (non-recursive). Skips project overlay files. Tracks files in the manifest.
upgrade_dir() {
  local src_dir="$1" dest_dir="$2" pattern="${3:-*}" label="$4"
  local src_file basename
  mkdir -p "$dest_dir"
  for src_file in "$src_dir"/$pattern; do
    [ -f "$src_file" ] || continue
    basename=$(basename "$src_file")
    # Skip project overlay files
    if is_project_overlay "$basename"; then
      continue
    fi
    manifest_add "$label/$basename"
    upgrade_file "$src_file" "$label/$basename"
  done
  return 0
}

# installed_template — the template the existing CLAUDE.md came from: the one
# .kit-baseline records, else inferred from its heading (each template names its
# stack on line 1). "generic" = the root CLAUDE.md; empty = unknown.
installed_template() {
  local t head1 d
  t=$(baseline_template)
  if [ -z "$t" ] && [ -f "$DEST/CLAUDE.md" ]; then
    head1=$(head -n 1 "$DEST/CLAUDE.md")
    if [ "$head1" = "$(head -n 1 "$CLONE_DIR/CLAUDE.md")" ]; then
      t="generic"
    fi
    for d in "$CLONE_DIR"/examples/*/; do
      if [ -f "${d}CLAUDE.md" ] && [ "$head1" = "$(head -n 1 "${d}CLAUDE.md")" ]; then
        t=$(basename "$d")
      fi
    done
  fi
  # A recorded template the kit no longer ships is as good as unknown.
  if [ -n "$t" ] && [ "$t" != "generic" ] && [ ! -f "$CLONE_DIR/examples/$t/CLAUDE.md" ]; then
    t=""
  fi
  echo "$t"
}

# baseline_write — merge this run's records over the previous .kit-baseline (a
# path this run didn't touch keeps its old entry) and write it atomically.
baseline_write() {
  local old="$DEST/$BASELINE_FILE" tmp template="$KIT_TEMPLATE_USED"
  if [ -z "$template" ]; then
    template=$(baseline_template)
  fi
  tmp=$(mktemp "$DEST/.kit-baseline.XXXXXX" 2>/dev/null) || tmp=$(mktemp)
  {
    if [ -n "$template" ]; then
      printf '#template\t%s\n' "$template"
    fi
    {
      if [ "${#BASELINE_ENTRIES[@]}" -gt 0 ]; then
        printf '%s\n' "${BASELINE_ENTRIES[@]}"
      fi
      if [ -f "$old" ]; then
        awk '!/^#/' "$old"
      fi
    } | awk -F'\t' 'NF == 2 && !seen[$2]++' | LC_ALL=C sort -t "$(printf '\t')" -k2,2
  } > "$tmp"
  mv "$tmp" "$DEST/$BASELINE_FILE"
}

# print_upgrade_summary — what --upgrade did, so a quiet log can never hide files
# that were updated, kept with local edits, or left in conflict.
print_upgrade_summary() {
  local f
  echo ""
  echo -e "  Upgrade summary: ${GREEN}${UP_UPDATED} updated${NC} · ${GREEN}${UP_ADDED} added${NC} · ${UP_UNCHANGED} unchanged · ${YELLOW}${#KEPT_FILES[@]} kept (local edits)${NC} · ${RED}${#CONFLICT_FILES[@]} conflicts${NC}"
  if [ "$UP_BACKED_UP" -gt 0 ]; then
    echo "  $UP_BACKED_UP replaced file(s) predate the install record — previous copies are in $BACKUP_DIR/"
  fi
  if [ "${#CONFLICT_FILES[@]}" -gt 0 ]; then
    echo ""
    warn "Conflicts — you edited these and the kit changed them. Merge <file>.kit-new into <file>, then delete the .kit-new:"
    for f in "${CONFLICT_FILES[@]}"; do
      echo "       - $f"
    done
  fi
  if [ "${#KEPT_FILES[@]}" -gt 0 ]; then
    echo ""
    info "Kept with your local edits (the kit has no newer version of these):"
    for f in "${KEPT_FILES[@]}"; do
      echo "       - $f"
    done
  fi
}

cleanup() {
  # Only clean up if we cloned to a temp directory (not --local mode)
  if [ "$LOCAL_SOURCE" = false ] && [ -n "$CLONE_DIR" ] && [ -d "$CLONE_DIR" ]; then
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
      TEMPLATE_EXPLICIT=true
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
    --wiki)
      WIKI=true
      shift
      ;;
    --html)
      HTML=true
      shift
      ;;
    --version|-v)
      [ $# -ge 2 ] || error "--version requires an argument"
      TARGET_VERSION="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: install.sh [--template nextjs|node-api|python-fastapi|go|rust|django] [--profile minimal|standard|strict] [--upgrade] [--diff]"
      echo ""
      echo "Options:"
      echo "  --template, -t   Use a stack-specific template (nextjs, node-api, python-fastapi, go, rust, django)"
      echo "  --profile, -p    Installation profile (default: standard)"
      echo "                     minimal  — hooks only, no CLAUDE.md or docs"
      echo "                     standard — full kit with default hooks"
      echo "                     strict   — full kit with all hooks enabled"
      echo "  --upgrade, -u    Update kit-managed files; ones you edited are kept and reported (project files untouched)"
      echo "  --diff, -d       Compare local installation against latest kit (read-only)"
      echo "  --gitignore, -g  Add kit files to .gitignore (keep kit local, don't push to repo)"
      echo "  --wiki           Add knowledge wiki module (personal knowledge base)"
      echo "  --html           Add HTML artifacts module (specs, reports, PR writeups as HTML)"
      echo "  --version, -v    Install a specific version (e.g., --version v1.0.0)"
      echo "  --help, -h       Show this help"
      echo ""
      echo "To uninstall: ./uninstall.sh (or curl -fsSL .../uninstall.sh | bash)"
      exit 0
      ;;
    --local)
      [ $# -ge 2 ] || error "--local requires a path argument"
      CLONE_DIR="$2"
      LOCAL_SOURCE=true
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
    nextjs|node-api|python-fastapi|go|rust|django) ;;
    *) error "Unknown template: $TEMPLATE. Options: nextjs, node-api, python-fastapi, go, rust, django" ;;
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
  # Go
  [ -f "$dest/go.mod" ] && echo "go" && return
  # Rust
  [ -f "$dest/Cargo.toml" ] && echo "rust" && return
  # Django (manage.py, or Django pinned in requirements) — before generic Python
  if [ -f "$dest/manage.py" ] || { [ -f "$dest/requirements.txt" ] && grep -qiE '^django([=<>!~ ]|$)' "$dest/requirements.txt" 2>/dev/null; }; then
    echo "django" && return
  fi
  # Python (FastAPI / generic)
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
  info "Upgrade mode — kit-managed files are updated; ones you edited are kept and reported; project files (tasks/, CODEBASE_MAP.md, overlays) are left alone"
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

# Source the shared manifest library from the kit source (single home for the
# manifest write logic — same code scripts/sync-manifest.sh uses). It only ships
# with the kit source, so it's available here regardless of curl|bash vs npx.
if [ -f "$CLONE_DIR/scripts/lib/manifest.sh" ]; then
  . "$CLONE_DIR/scripts/lib/manifest.sh"
else
  error "Missing scripts/lib/manifest.sh in the kit source — cannot write the manifest"
fi

# Read version from downloaded kit
KIT_VERSION="unknown"
if [ -f "$CLONE_DIR/VERSION" ]; then
  KIT_VERSION=$(cat "$CLONE_DIR/VERSION" | sed 's/ *#.*//' | tr -d '[:space:]')
fi

# On --upgrade keep the template the existing CLAUDE.md came from. Auto-detection
# reflects today's tree — a generic install that later gained a package.json would
# otherwise have its CLAUDE.md swapped for the node-api template.
if [ "$UPGRADE" = true ] && [ "$TEMPLATE_EXPLICIT" = false ] && [ "$PROFILE" != "minimal" ]; then
  INSTALLED_TEMPLATE=$(installed_template)
  if [ -n "$INSTALLED_TEMPLATE" ]; then
    KEEP_TEMPLATE="$INSTALLED_TEMPLATE"
    [ "$KEEP_TEMPLATE" = "generic" ] && KEEP_TEMPLATE=""
    if [ "$KEEP_TEMPLATE" != "$TEMPLATE" ]; then
      info "Keeping installed template: $INSTALLED_TEMPLATE (auto-detection suggested ${TEMPLATE:-generic})"
    fi
    TEMPLATE="$KEEP_TEMPLATE"
  fi
fi

# Determine source for CLAUDE.md and CODEBASE_MAP.md
if [ -n "$TEMPLATE" ]; then
  SRC_CLAUDE="$CLONE_DIR/examples/$TEMPLATE/CLAUDE.md"
  SRC_MAP="$CLONE_DIR/examples/$TEMPLATE/CODEBASE_MAP.md"
  info "Using template: $TEMPLATE"
else
  SRC_CLAUDE="$CLONE_DIR/CLAUDE.md"
  # scaffold/CODEBASE_MAP.md — a blank, stack-agnostic map to fill in. This
  # repo's own CODEBASE_MAP.md describes ClaudeCodeKit, so shipping it as the
  # fallback told the agent it was working on the kit.
  SRC_MAP="$CLONE_DIR/scaffold/CODEBASE_MAP.md"
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
    baseline_record "$SRC_CLAUDE" "CLAUDE.md"
    KIT_TEMPLATE_USED="${TEMPLATE:-generic}"
    ok "Created CLAUDE.md"
  elif [ "$UPGRADE" = true ]; then
    upgrade_file "$SRC_CLAUDE" "CLAUDE.md"
    KIT_TEMPLATE_USED="${TEMPLATE:-generic}"
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
    # Track all copied files in manifest + baseline
    for f in "$CLONE_DIR/agent_docs/"*.md; do
      [ -f "$f" ] || continue
      manifest_add "agent_docs/$(basename "$f")"
      baseline_record "$f" "agent_docs/$(basename "$f")"
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

  # Copy tasks/ from scaffold/tasks/ — the pristine board, ADR log, handoff
  # template and starter lessons. Never from this repo's own tasks/, which holds
  # the kit's live task board, its 15 ADRs and its real lessons; shipping those
  # hands every new project someone else's project state.
  if [ ! -d "$DEST/tasks" ]; then
    cp -r "$CLONE_DIR/scaffold/tasks" "$DEST/tasks"
    ok "Created tasks/"
    for f in "$DEST/tasks/"*.md; do
      [ -f "$f" ] && manifest_add "tasks/$(basename "$f")"
    done
    # Track per-file lessons under tasks/lessons/
    if [ -d "$DEST/tasks/lessons" ]; then
      for f in "$DEST/tasks/lessons/"*.md; do
        [ -f "$f" ] && manifest_add "tasks/lessons/$(basename "$f")"
      done
    fi
  elif [ "$UPGRADE" = true ]; then
    seed_dir "$CLONE_DIR/scaffold/tasks" "$DEST/tasks" "*.md" "tasks"
  else
    warn "Skipped tasks/ (already exists)"
    for f in "$DEST/tasks/"*.md; do
      [ -f "$f" ] && manifest_add "tasks/$(basename "$f")"
    done
    if [ -d "$DEST/tasks/lessons" ]; then
      for f in "$DEST/tasks/lessons/"*.md; do
        [ -f "$f" ] && manifest_add "tasks/lessons/$(basename "$f")"
      done
    fi
  fi

  # tasks/lessons/ — per-file lessons directory (independent of tasks/ creation
  # so existing installs get the scaffold on --upgrade without overwriting user lessons)
  if [ ! -d "$DEST/tasks/lessons" ]; then
    mkdir -p "$DEST/tasks/lessons"
    for f in "$CLONE_DIR/scaffold/tasks/lessons/"*.md; do
      [ -f "$f" ] || continue
      cp "$f" "$DEST/tasks/lessons/$(basename "$f")"
      manifest_add "tasks/lessons/$(basename "$f")"
    done
    ok "Created tasks/lessons/ (per-file lessons with frontmatter)"
  elif [ "$UPGRADE" = true ]; then
    # scaffold/tasks/lessons/ IS the kit-managed set, so no second allowlist to
    # drift against it. Never overwrite user lessons.
    for f in "$CLONE_DIR/scaffold/tasks/lessons/"*.md; do
      [ -f "$f" ] || continue
      basename=$(basename "$f")
      manifest_add "tasks/lessons/$basename"
      if [ ! -f "$DEST/tasks/lessons/$basename" ]; then
        cp "$f" "$DEST/tasks/lessons/$basename"
        ok "Added tasks/lessons/$basename"
      fi
    done
  fi

  # Legacy detection: old single-file tasks/lessons.md
  # Inform the user there is a migration path; never auto-migrate (user data).
  if [ -f "$DEST/tasks/lessons.md" ]; then
    warn "Detected legacy tasks/lessons.md (old single-file format)"
    warn "Run ./scripts/migrate-lessons.sh to convert it to the new per-file structure"
  fi

  # Copy scripts — the user-facing ones only (see user_script_names)
  if [ ! -d "$DEST/scripts" ]; then
    mkdir -p "$DEST/scripts"
    for kit_script in $(user_script_names); do
      [ -f "$CLONE_DIR/scripts/$kit_script" ] || continue
      cp "$CLONE_DIR/scripts/$kit_script" "$DEST/scripts/"
      manifest_add "scripts/$kit_script"
      baseline_record "$CLONE_DIR/scripts/$kit_script" "scripts/$kit_script"
    done
    chmod +x "$DEST/scripts/"*.sh 2>/dev/null || true
    SCRIPT_COUNT=$(ls -1 "$DEST/scripts/"*.sh 2>/dev/null | wc -l | tr -d ' ')
    ok "Created scripts/ ($SCRIPT_COUNT scripts)"
  elif [ "$UPGRADE" = true ]; then
    for kit_script in $(user_script_names); do
      [ -f "$CLONE_DIR/scripts/$kit_script" ] || continue
      manifest_add "scripts/$kit_script"
      upgrade_file "$CLONE_DIR/scripts/$kit_script" "scripts/$kit_script"
    done
    chmod +x "$DEST/scripts/"*.sh 2>/dev/null
  else
    warn "Skipped scripts/ (already exists)"
    # Record only the kit's scripts — the project's own scripts/ isn't kit-managed.
    for kit_script in $(user_script_names); do
      [ -f "$DEST/scripts/$kit_script" ] && manifest_add "scripts/$kit_script"
    done
  fi

  # Earlier installs also copied the kit-maintainer scripts. Report any still
  # here, never delete them: they're in the user's tree and may be kept on
  # purpose. With a previous manifest, only names it lists count — a same-named
  # script of the user's own was never the kit's. Without one, only an upgrade
  # implies an earlier kit install put them there.
  RETIRED_SCRIPTS=""
  for kit_script in build-skills.sh check-counts.sh check-scaffold.sh gen-skill-docs.sh gen-strict-settings.sh run-bench.sh sync-manifest.sh test-cli.sh test-install.sh; do
    [ -f "$DEST/scripts/$kit_script" ] || continue
    if [ -f "$DEST/$MANIFEST_FILE" ]; then
      grep -qxF "scripts/$kit_script" "$DEST/$MANIFEST_FILE" || continue
    elif [ "$UPGRADE" != true ]; then
      continue
    fi
    RETIRED_SCRIPTS="$RETIRED_SCRIPTS scripts/$kit_script"
  done
  if [ -n "$RETIRED_SCRIPTS" ]; then
    warn "No longer shipped (kit-maintainer only, they don't run outside the kit repo):$RETIRED_SCRIPTS"
    warn "Delete them unless you use them yourself — install.sh leaves them in place"
  fi

fi

# Copy hooks
if [ ! -d "$DEST/.claude/hooks" ]; then
  mkdir -p "$DEST/.claude/hooks"
  for f in "$CLONE_DIR/.claude/hooks/"*.sh; do
    [ -f "$f" ] || continue
    cp "$f" "$DEST/.claude/hooks/"
    manifest_add ".claude/hooks/$(basename "$f")"
    baseline_record "$f" ".claude/hooks/$(basename "$f")"
  done
  # Copy shared hook library. Safety hooks fail closed without it (CLA-47),
  # so a silent miss would block every Edit/Bash. Hard-error instead of || true.
  if [ -d "$CLONE_DIR/.claude/hooks/lib" ]; then
    mkdir -p "$DEST/.claude/hooks/lib"
    cp "$CLONE_DIR/.claude/hooks/lib/"*.sh "$DEST/.claude/hooks/lib/" || error "Failed to copy hook library (.claude/hooks/lib/) — safety hooks would not run"
    manifest_add ".claude/hooks/lib"
    for f in "$CLONE_DIR/.claude/hooks/lib/"*.sh; do
      baseline_record "$f" ".claude/hooks/lib/$(basename "$f")"
    done
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
      upgrade_file "$lib_file" ".claude/hooks/lib/$(basename "$lib_file")"
    done
    manifest_add ".claude/hooks/lib"
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
      baseline_record "$f" ".claude/agents/$(basename "$f")"
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
    # Skip build-only assets (_shared/, _templates/) — end users don't run
    # build-skills.sh, and sync-manifest.sh excludes _* so shipping them would
    # also break the manifest --check.
    for f in "$CLONE_DIR/.claude/skills/"*; do
      [ -e "$f" ] || continue
      case "$(basename "$f")" in _*) continue ;; esac
      cp -r "$f" "$DEST/.claude/skills/"
    done
    SKILL_COUNT=$(find "$DEST/.claude/skills" -mindepth 1 -maxdepth 1 -type d ! -name "_*" 2>/dev/null | wc -l | tr -d ' ')
    ok "Created .claude/skills/ ($SKILL_COUNT skills)"
    # Track skill files in manifest + baseline
    for skill_dir in "$DEST/.claude/skills/"*/; do
      [ -d "$skill_dir" ] || continue
      local_name=$(basename "$skill_dir")
      case "$local_name" in _*) continue ;; esac
      manifest_add ".claude/skills/$local_name"
      if [ -d "$CLONE_DIR/.claude/skills/$local_name" ]; then
        baseline_record_tree "$CLONE_DIR/.claude/skills/$local_name" ".claude/skills/$local_name"
      fi
    done
  elif [ "$UPGRADE" = true ]; then
    # Skills have subdirectories (references/, resources/) — upgrade every file
    for skill_dir in "$CLONE_DIR/.claude/skills/"*/; do
      [ -d "$skill_dir" ] || continue
      local_name=$(basename "$skill_dir")
      case "$local_name" in _*) continue ;; esac
      manifest_add ".claude/skills/$local_name"
      upgrade_tree "$skill_dir" ".claude/skills/$local_name"
    done
  else
    warn "Skipped .claude/skills/ (already exists)"
    for skill_dir in "$DEST/.claude/skills/"*/; do
      [ -d "$skill_dir" ] || continue
      case "$(basename "$skill_dir")" in _*) continue ;; esac
      manifest_add ".claude/skills/$(basename "$skill_dir")"
    done
  fi

  # Community extensions slot — kit creates the directory + README only.
  # Anything users put under .claude/extensions/<name>/ survives kit upgrades.
  # See agent_docs/skills.md → Extending the Kit and ADR-015.
  if [ ! -d "$DEST/.claude/extensions" ]; then
    mkdir -p "$DEST/.claude/extensions"
    if [ -f "$CLONE_DIR/.claude/extensions/README.md" ]; then
      cp "$CLONE_DIR/.claude/extensions/README.md" "$DEST/.claude/extensions/README.md"
      manifest_add ".claude/extensions/README.md"
    fi
    ok "Created .claude/extensions/ (community extensions slot)"
  elif [ "$UPGRADE" = true ]; then
    # Refresh only the README; never touch user-installed extensions
    if [ -f "$CLONE_DIR/.claude/extensions/README.md" ]; then
      cp "$CLONE_DIR/.claude/extensions/README.md" "$DEST/.claude/extensions/README.md"
      manifest_add ".claude/extensions/README.md"
    fi
  else
    # Existing install (not an upgrade) — keep manifest entry but don't write
    [ -f "$DEST/.claude/extensions/README.md" ] && manifest_add ".claude/extensions/README.md"
  fi

fi

# Copy settings.json (hooks + permissions config)
manifest_add ".claude/settings.json"
if [ ! -f "$DEST/.claude/settings.json" ]; then
  if [ "$PROFILE" = "strict" ]; then
    cp "$CLONE_DIR/.claude/settings.strict.json" "$DEST/.claude/settings.json"
    baseline_record "$CLONE_DIR/.claude/settings.strict.json" ".claude/settings.json"
    ok "Created .claude/settings.json (strict — all hooks enabled)"
  else
    cp "$CLONE_DIR/.claude/settings.json" "$DEST/.claude/settings.json"
    baseline_record "$CLONE_DIR/.claude/settings.json" ".claude/settings.json"
    ok "Created .claude/settings.json (hooks + permissions config)"
  fi
elif [ "$UPGRADE" = true ]; then
  warn "Kept .claude/settings.json (not auto-merged — review new hooks manually)"
else
  warn "Skipped .claude/settings.json (already exists)"
fi

# Copy the MCP allowlist template (mcp-gate.sh is inert until the real file exists)
if [ -f "$CLONE_DIR/.claude/mcp-allowlist.txt.example" ]; then
  manifest_add ".claude/mcp-allowlist.txt.example"
  cp "$CLONE_DIR/.claude/mcp-allowlist.txt.example" "$DEST/.claude/mcp-allowlist.txt.example"
fi

# Copy the project-commands template (quality-gate / ship use it when the real
# .claude/commands.json exists; absent → auto-detection, unchanged behavior)
if [ -f "$CLONE_DIR/.claude/commands.json.example" ]; then
  manifest_add ".claude/commands.json.example"
  cp "$CLONE_DIR/.claude/commands.json.example" "$DEST/.claude/commands.json.example"
fi

# --- Knowledge wiki module (optional) ---
if [ "$WIKI" = true ] && [ "$PROFILE" != "minimal" ]; then
  # Copy WIKI.md schema
  manifest_add "WIKI.md"
  if [ ! -f "$DEST/WIKI.md" ]; then
    cp "$CLONE_DIR/WIKI.md" "$DEST/WIKI.md"
    baseline_record "$CLONE_DIR/WIKI.md" "WIKI.md"
    ok "Created WIKI.md (knowledge wiki schema)"
  elif [ "$UPGRADE" = true ]; then
    upgrade_file "$CLONE_DIR/WIKI.md" "WIKI.md"
  else
    warn "Skipped WIKI.md (already exists)"
  fi

  # Scaffold vault directories
  if [ ! -d "$DEST/raw-sources" ]; then
    mkdir -p "$DEST/raw-sources"
    ok "Created raw-sources/ (drop articles, PDFs, transcripts here)"
  fi

  if [ ! -d "$DEST/wiki" ]; then
    mkdir -p "$DEST/wiki/summaries" "$DEST/wiki/entities" "$DEST/wiki/concepts"
    create_wiki_index "$DEST/wiki/index.md"
    create_wiki_log "$DEST/wiki/log.md"
    ok "Created wiki/ (Claude-maintained knowledge base)"
  else
    # Ensure subdirectories exist
    mkdir -p "$DEST/wiki/summaries" "$DEST/wiki/entities" "$DEST/wiki/concepts"
    [ -f "$DEST/wiki/index.md" ] || create_wiki_index "$DEST/wiki/index.md"
    [ -f "$DEST/wiki/log.md" ] || create_wiki_log "$DEST/wiki/log.md"
  fi

  # Copy wiki skills
  for skill_dir in "$CLONE_DIR/wiki-module/.claude/skills/"*/; do
    [ -d "$skill_dir" ] || continue
    local_name=$(basename "$skill_dir")
    manifest_add ".claude/skills/$local_name"
    if [ ! -d "$DEST/.claude/skills/$local_name" ]; then
      cp -r "$skill_dir" "$DEST/.claude/skills/$local_name"
      baseline_record_tree "$skill_dir" ".claude/skills/$local_name"
    elif [ "$UPGRADE" = true ]; then
      upgrade_tree "$skill_dir" ".claude/skills/$local_name"
    fi
  done

  # Copy wiki agent
  for agent_file in "$CLONE_DIR/wiki-module/.claude/agents/"*.md; do
    [ -f "$agent_file" ] || continue
    local_name=$(basename "$agent_file")
    manifest_add ".claude/agents/$local_name"
    if [ ! -f "$DEST/.claude/agents/$local_name" ]; then
      cp "$agent_file" "$DEST/.claude/agents/$local_name"
      baseline_record "$agent_file" ".claude/agents/$local_name"
    elif [ "$UPGRADE" = true ]; then
      upgrade_file "$agent_file" ".claude/agents/$local_name"
    fi
  done

  WIKI_SKILLS=$(ls -1d "$CLONE_DIR/wiki-module/.claude/skills/"*/ 2>/dev/null | wc -l | tr -d ' ')
  ok "Added wiki module ($WIKI_SKILLS skills, 1 agent)"
fi

# --- HTML artifacts module (optional) ---
if [ "$HTML" = true ] && [ "$PROFILE" != "minimal" ]; then
  # Copy ARTIFACTS.md schema
  manifest_add "ARTIFACTS.md"
  if [ ! -f "$DEST/ARTIFACTS.md" ]; then
    cp "$CLONE_DIR/ARTIFACTS.md" "$DEST/ARTIFACTS.md"
    baseline_record "$CLONE_DIR/ARTIFACTS.md" "ARTIFACTS.md"
    ok "Created ARTIFACTS.md (HTML artifact conventions)"
  elif [ "$UPGRADE" = true ]; then
    upgrade_file "$CLONE_DIR/ARTIFACTS.md" "ARTIFACTS.md"
  else
    warn "Skipped ARTIFACTS.md (already exists)"
  fi

  # Scaffold artifacts/ directory with design-system.html and index.html
  if [ ! -d "$DEST/artifacts" ]; then
    mkdir -p "$DEST/artifacts"
    cp "$CLONE_DIR/html-module/templates/design-system.html" "$DEST/artifacts/design-system.html"
    cp "$CLONE_DIR/html-module/templates/index.html" "$DEST/artifacts/index.html"
    ok "Created artifacts/ (design-system.html + index.html)"
  else
    # Add the reference files only if missing — never overwrite user-edited tokens
    [ -f "$DEST/artifacts/design-system.html" ] || cp "$CLONE_DIR/html-module/templates/design-system.html" "$DEST/artifacts/design-system.html"
    [ -f "$DEST/artifacts/index.html" ] || cp "$CLONE_DIR/html-module/templates/index.html" "$DEST/artifacts/index.html"
  fi
fi

# Write manifest + baseline (the baseline is a kit file too — uninstall removes it)
manifest_add "$MANIFEST_FILE"
manifest_add "$BASELINE_FILE"
manifest_write "$DEST"
baseline_write

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
      echo "scripts/"
      echo ".claude/"
      if [ "$WIKI" = true ]; then
        echo "WIKI.md"
        echo "raw-sources/"
        echo "wiki/"
      fi
      if [ "$HTML" = true ]; then
        echo "ARTIFACTS.md"
        echo "artifacts/"
      fi
    } >> "$GITIGNORE_FILE"
    ok "Added kit files to .gitignore (kit stays local, won't be pushed)"
  fi
fi

echo ""
if [ "$UPGRADE" = true ]; then
  echo "  Upgrade complete! (v${KIT_VERSION}, $PROFILE profile)"
  print_upgrade_summary
  echo ""
  echo "  Next steps:"
  if [ "${#CONFLICT_FILES[@]}" -gt 0 ]; then
    echo "  - Resolve the conflicts above (merge each <file>.kit-new, then delete it)"
  fi
  echo "  - .claude/settings.json is not auto-merged — enable any new hooks it lacks"
  echo "  - Start a Claude Code session"
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
  if [ "$WIKI" = true ]; then
    echo ""
    echo "  Wiki module:"
    echo "  - Add source files to raw-sources/ (articles, PDFs, transcripts)"
    echo "  - Run /wiki-ingest to process them into the wiki"
    echo "  - Run /wiki-briefing for a daily summary"
    echo "  - Run /wiki-lint for periodic health checks"
    echo "  - Open the project folder in your markdown editor to browse the wiki"
  fi
  if [ "$HTML" = true ]; then
    echo ""
    echo "  HTML artifacts module:"
    echo "  - Edit artifacts/design-system.html tokens to match your project's taste"
    echo "  - Ask Claude to produce specs, reports, PR writeups, or editors as HTML"
    echo "  - New artifacts land in artifacts/ and auto-link from artifacts/index.html"
    echo "  - Open artifacts/<file>.html in a browser to view, share via S3/CDN"
  fi
fi
echo ""
