#!/usr/bin/env bash
#
# check-pipefail-grep.sh — no quiet grep on the receiving end of a pipe in
# pipefail scripts.
#
# A quiet grep exits the moment it matches, which can leave the writer with
# EPIPE. Under `set -o pipefail` the pipeline then reports failure even though
# the pattern DID match, so the match is silently lost. That flipped wired hooks
# into phantom "orphan hook" warnings (TAN-5273) and made skill section checks
# flake (TAN-4746). Use a herestring — grep -q PATTERN <<< "$VAR" — or, for a
# plain substring test, bash's [[ "$VAR" == *"$NEEDLE"* ]].
#
# Usage: ./scripts/check-pipefail-grep.sh   (from the repo root)
#

set -uo pipefail

PATTERN='[^|]\|[[:space:]]*grep[[:space:]]+(-[a-zA-Z]*q[a-zA-Z]*|--quiet)([[:space:]]|$)'
violations=0
for file in $(git ls-files '*.sh'); do
  grep -q 'pipefail' "$file" || continue
  hits=$(grep -nE "$PATTERN" "$file" | grep -vE '^[0-9]+:[[:space:]]*#' || true)
  if [ -n "$hits" ]; then
    echo "$file:"
    sed 's/^/  /' <<< "$hits"
    violations=$((violations + $(wc -l <<< "$hits")))
  fi
done
if [ "$violations" -gt 0 ]; then
  echo ""
  echo "$violations pipe(s) into a quiet grep found in pipefail scripts." >&2
  exit 1
fi
echo "No quiet grep is fed by a pipe in a pipefail script."
