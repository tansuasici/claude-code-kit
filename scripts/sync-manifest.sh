#!/usr/bin/env bash
#
# sync-manifest.sh — regenerate .kit-manifest from the repo's directory tree.
#
# The manifest is the source of truth for which files install.sh ships to a
# user's project. install.sh builds the manifest at install-time via
# `manifest_add`, but the *repo* copy at `.kit-manifest` is what
# `uninstall.sh --upgrade` and `--diff` consult, and what humans read to see
# what kit ships.
#
# This script keeps the repo copy in sync with the directory tree. The CI job
# in .github/workflows/validate.yml runs it with `--check` and fails the build
# if the manifest is stale.
#
# Usage:
#   ./scripts/sync-manifest.sh           # rewrite .kit-manifest
#   ./scripts/sync-manifest.sh --check   # exit 1 if rewrite would change it
#
# The set of entries mirrors install.sh's `manifest_add` calls — anything
# install.sh copies into the user's project belongs here. Files repo uses
# internally (bench/, examples/, html-module/, install.sh itself, scripts that
# only the maintainer runs) are deliberately excluded.
#

set -uo pipefail

KIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$KIT_ROOT"

CHECK_ONLY=0
if [ "${1:-}" = "--check" ]; then
  CHECK_ONLY=1
fi

# Collect entries that install.sh's manifest_add path would produce.
# Order doesn't matter — we sort at the end. Same rule for inclusion: if a path
# is unconditionally shipped by install.sh, it goes in. Conditional paths (e.g.
# WIKI.md, ARTIFACTS.md, harness docs, extensions/README.md) are excluded so
# the manifest reflects the default install.

entries=()

add_if_file() {
  [ -f "$1" ] && entries+=("$1")
}

add_glob_files() {
  local pattern="$1"
  local f
  for f in $pattern; do
    [ -f "$f" ] && entries+=("$f")
  done
}

# --- Top-level files (always shipped) -----------------------------------
add_if_file CLAUDE.md
add_if_file CODEBASE_MAP.md
add_if_file DESIGN.md
add_if_file VERSION
add_if_file .kit-manifest

# --- agent_docs/ (.md files, exclude project overlay folder) ------------
if [ -d agent_docs ]; then
  for f in agent_docs/*.md; do
    [ -f "$f" ] && entries+=("$f")
  done
fi

# --- scripts/ (all *.sh) ------------------------------------------------
if [ -d scripts ]; then
  for f in scripts/*.sh; do
    [ -f "$f" ] && entries+=("$f")
  done
fi

# --- tasks/ — only the default top-level files (lessons/specs are dynamic)
if [ -d tasks ]; then
  for f in tasks/decisions.md tasks/handoff.md tasks/todo.md; do
    [ -f "$f" ] && entries+=("$f")
  done
  # Lessons template + index ship; per-day lesson files are user-owned.
  if [ -d tasks/lessons ]; then
    for f in tasks/lessons/_TEMPLATE.md tasks/lessons/_index.md; do
      [ -f "$f" ] && entries+=("$f")
    done
  fi
fi

# --- .claude/agents/ ----------------------------------------------------
if [ -d .claude/agents ]; then
  for f in .claude/agents/*.md; do
    [ -f "$f" ] && entries+=("$f")
  done
fi

# --- .claude/hooks/ (all *.sh + lib dir) --------------------------------
if [ -d .claude/hooks ]; then
  for f in .claude/hooks/*.sh; do
    [ -f "$f" ] && entries+=("$f")
  done
  [ -d .claude/hooks/lib ] && entries+=(".claude/hooks/lib")
fi

# --- .claude/settings.json ----------------------------------------------
add_if_file .claude/settings.json

# --- .claude/skills/ (each skill dir, exclude _shared/_templates) -------
if [ -d .claude/skills ]; then
  for d in .claude/skills/*/; do
    [ -d "$d" ] || continue
    base=$(basename "$d")
    case "$base" in
      _*) continue ;;
    esac
    entries+=(".claude/skills/$base")
  done
fi

# --- Render --------------------------------------------------------------
NEW_MANIFEST=$(printf '%s\n' "${entries[@]}" | sort -u)

if [ "$CHECK_ONLY" -eq 1 ]; then
  CURRENT=$(cat .kit-manifest 2>/dev/null || echo "")
  if [ "$NEW_MANIFEST" != "$CURRENT" ]; then
    echo ".kit-manifest is out of sync with the repo's directory tree." >&2
    echo "" >&2
    echo "Run scripts/sync-manifest.sh (no args) to regenerate, then commit." >&2
    echo "" >&2
    echo "--- Drift (existing < ; regenerated >) ---" >&2
    diff <(printf '%s\n' "$CURRENT") <(printf '%s\n' "$NEW_MANIFEST") >&2 || true
    exit 1
  fi
  echo ".kit-manifest is in sync with the directory tree."
  exit 0
fi

# Write atomically.
TMP=$(mktemp)
printf '%s\n' "$NEW_MANIFEST" > "$TMP"
mv "$TMP" .kit-manifest

LINES=$(printf '%s\n' "$NEW_MANIFEST" | grep -c '^' 2>/dev/null || echo 0)
echo "Regenerated .kit-manifest with $LINES entries."
exit 0
