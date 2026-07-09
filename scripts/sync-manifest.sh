#!/usr/bin/env bash
#
# sync-manifest.sh — regenerate .kit-manifest from the repo's directory tree.
#
# The manifest is the source of truth for which files install.sh ships to a
# user's project. install.sh builds the manifest at install-time via
# `manifest_add`, but the *repo* copy at `.kit-manifest` is what
# `uninstall.sh` and `--diff` consult, and what humans read to see what kit
# ships.
#
# This script keeps the repo copy in sync with the directory tree. The CI job
# in .github/workflows/validate.yml runs it with `--check` and fails the build
# if the manifest is stale.
#
# Usage:
#   ./scripts/sync-manifest.sh           # rewrite .kit-manifest
#   ./scripts/sync-manifest.sh --check   # exit 1 if rewrite would change it
#
# The enumeration + read/write logic lives in scripts/lib/manifest.sh so it has
# exactly one home (shared with install.sh's write path). Anything install.sh
# ships unconditionally belongs in `kit_manifest_entries`; conditional payloads
# (WIKI.md, ARTIFACTS.md, DESIGN.md, harness docs, extensions/README.md) are
# excluded so the manifest reflects the default install.
#

set -uo pipefail

KIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$KIT_ROOT"
. "$KIT_ROOT/scripts/lib/manifest.sh"

CHECK_ONLY=0
if [ "${1:-}" = "--check" ]; then
  CHECK_ONLY=1
fi

# LC_ALL=C makes collation byte-deterministic across platforms — without it the
# manifest's sort order differs between macOS (BSD locale) and Linux CI, so a
# manifest regenerated on one would fail --check on the other.
NEW_MANIFEST=$(kit_manifest_entries | LC_ALL=C sort -u)

if [ "$CHECK_ONLY" -eq 1 ]; then
  CURRENT=$(manifest_read "$MANIFEST_FILE" | LC_ALL=C sort -u)
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

# Rewrite via the shared writer (atomic, sorted, de-duplicated).
MANIFEST_ENTRIES=()
while IFS= read -r line; do
  [ -n "$line" ] && MANIFEST_ENTRIES+=("$line")
done <<< "$NEW_MANIFEST"
manifest_write "$KIT_ROOT"

LINES=$(printf '%s\n' "$NEW_MANIFEST" | grep -c '^' 2>/dev/null || echo 0)
echo "Regenerated .kit-manifest with $LINES entries."
exit 0
