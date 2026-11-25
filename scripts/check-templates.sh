#!/usr/bin/env bash
#
# check-templates.sh — assert the shipped templates keep their required sections.
#
# Checks the example CODEBASE_MAP files, the generic map a stackless install
# falls back to, this repo's own map, and the CLAUDE.md template. This is the
# "Template Validation" check; CI and scripts/ci-local.sh both run it.
#
# Usage: ./scripts/check-templates.sh   (from the repo root)
#

set -euo pipefail

errors=0

require_sections() {
  local file="$1"; shift
  echo "Checking structure: $file"
  local section
  for section in "$@"; do
    if ! grep -q "$section" "$file"; then
      echo "  ERROR: Missing section '$section' in $file"
      errors=$((errors + 1))
    fi
  done
}

for file in examples/*/CODEBASE_MAP.md; do
  require_sections "$file" "## What" "## Tech Stack" "## Key Commands" "## Directory Structure" "## Critical Files"
done

# The generic template a stackless install falls back to, and this repo's own
# map, must both carry the full section set.
for file in scaffold/CODEBASE_MAP.md CODEBASE_MAP.md; do
  require_sections "$file" "## What" "## Why" "## Tech Stack" "## Key Commands" "## Directory Structure" "## Critical Files" "## Architecture" "## Known Constraints" "## Environment"
done

require_sections CLAUDE.md "## Session Boot" "## Plan First" "## Scope Discipline" "## Verification" "## Self-Improvement"

echo ""
if [ "$errors" -gt 0 ]; then
  echo "$errors structural error(s) found."
  exit 1
fi
echo "All templates structurally valid."
