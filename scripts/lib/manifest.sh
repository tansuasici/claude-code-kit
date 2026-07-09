#!/usr/bin/env bash
#
# manifest.sh — shared manifest primitives for Claude Code Kit.
#
# `.kit-manifest` is the record of which files the kit ships into a user's
# project. This library is the single home for the read/write/enumerate logic
# that used to be reimplemented across install.sh, scripts/sync-manifest.sh, and
# uninstall.sh.
#
# Consumers:
#   - scripts/sync-manifest.sh  — sources this to enumerate + write the repo copy
#   - install.sh                — sources this (from the cloned/--local source,
#                                 after the source tree is available) to write
#                                 the per-project manifest
#   - uninstall.sh              — does NOT source this: it runs standalone via
#                                 `curl … | bash` with no library beside it, so
#                                 it reads the `.kit-manifest` *artifact* this
#                                 code produces (the same single source) with a
#                                 trivial inline read.
#
# Source it, then call the functions:  . "<dir>/scripts/lib/manifest.sh"
#

# Guard against double-sourcing (install.sh also defines MANIFEST_FILE).
if [ -n "${_CCK_MANIFEST_LIB_LOADED:-}" ]; then
  return 0 2>/dev/null || true
fi
_CCK_MANIFEST_LIB_LOADED=1

MANIFEST_FILE=".kit-manifest"

# manifest_write <dest_dir> — write the entries in the MANIFEST_ENTRIES array to
# <dest_dir>/.kit-manifest, sorted and de-duplicated. No-op if the array is empty.
# Writes atomically (temp + mv). LC_ALL=C makes collation byte-deterministic
# across macOS (BSD) and Linux.
manifest_write() {
  local dest="$1"
  [ "${#MANIFEST_ENTRIES[@]}" -gt 0 ] || return 0
  local tmp
  tmp=$(mktemp "$dest/.kit-manifest.XXXXXX" 2>/dev/null) || tmp=$(mktemp)
  printf '%s\n' "${MANIFEST_ENTRIES[@]}" | LC_ALL=C sort -u > "$tmp"
  mv "$tmp" "$dest/$MANIFEST_FILE"
}

# manifest_read <manifest_path> — emit the manifest's entries, one per line,
# skipping blank lines. Used to drive manifest-based operations.
manifest_read() {
  local path="$1"
  [ -f "$path" ] || return 0
  grep -v '^[[:space:]]*$' "$path" || true
}

# kit_manifest_entries — emit the exact set of paths install.sh ships under the
# default (standard) profile, relative to the current directory (caller cd's to
# the kit root first). Order doesn't matter — callers sort. Same inclusion rule
# as install.sh's unconditional manifest_add calls: conditional payloads
# (WIKI.md, ARTIFACTS.md, DESIGN.md, harness docs, extensions/README.md) are
# excluded so the manifest reflects the default install.
kit_manifest_entries() {
  local entries=() f d base

  # --- Top-level files (always shipped) ---------------------------------
  local top
  for top in CLAUDE.md CODEBASE_MAP.md VERSION .kit-manifest; do
    [ -f "$top" ] && entries+=("$top")
  done

  # --- agent_docs/ (.md files, exclude project overlay folder) ----------
  if [ -d agent_docs ]; then
    for f in agent_docs/*.md; do
      [ -f "$f" ] && entries+=("$f")
    done
  fi

  # --- scripts/ (all *.sh) ----------------------------------------------
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

  # --- .claude/agents/ --------------------------------------------------
  if [ -d .claude/agents ]; then
    for f in .claude/agents/*.md; do
      [ -f "$f" ] && entries+=("$f")
    done
  fi

  # --- .claude/hooks/ (all *.sh + lib dir) ------------------------------
  if [ -d .claude/hooks ]; then
    for f in .claude/hooks/*.sh; do
      [ -f "$f" ] && entries+=("$f")
    done
    [ -d .claude/hooks/lib ] && entries+=(".claude/hooks/lib")
  fi

  # --- .claude/settings.json --------------------------------------------
  [ -f .claude/settings.json ] && entries+=(".claude/settings.json")

  # --- .claude/skills/ (each skill dir, exclude _shared/_templates) -----
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

  [ "${#entries[@]}" -gt 0 ] && printf '%s\n' "${entries[@]}"
}
