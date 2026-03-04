#!/usr/bin/env bash
#
# validate.sh — Check CODEBASE_MAP.md for unfilled placeholders
#
# Usage: ./scripts/validate.sh [path/to/CODEBASE_MAP.md]
#

set -euo pipefail

FILE="${1:-CODEBASE_MAP.md}"
ERRORS=0

if [ ! -f "$FILE" ]; then
  echo "Error: $FILE not found"
  echo "Usage: $0 [path/to/CODEBASE_MAP.md]"
  exit 1
fi

echo "Validating $FILE..."
echo ""

# Patterns that indicate unfilled placeholders
declare -a PATTERNS=(
  '\[command\]'
  '\[module\]'
  '\[file\]'
  '\[how managed\]'
  '\.\.\.'
  '<!-- .* -->'
  'src/\.\.\.'
)

declare -a LABELS=(
  '[command] placeholder'
  '[module] placeholder'
  '[file] placeholder'
  '[how managed] placeholder'
  '... placeholder'
  'HTML comment (unfilled section)'
  'src/... placeholder'
)

for i in "${!PATTERNS[@]}"; do
  MATCHES=$(grep -n -E "${PATTERNS[$i]}" "$FILE" 2>/dev/null || true)
  if [ -n "$MATCHES" ]; then
    echo "  WARN  ${LABELS[$i]}:"
    while IFS= read -r line; do
      echo "         Line $line"
    done <<< "$MATCHES"
    ERRORS=$((ERRORS + 1))
    echo ""
  fi
done

# Check for empty sections (## heading followed by --- or another ## with nothing between)
EMPTY_SECTIONS=$(awk '
  /^## / {
    if (header != "" && content == 0) {
      print NR-1 ": " header " (empty section)"
    }
    header = $0
    content = 0
    next
  }
  /^---$/ { next }
  /^[[:space:]]*$/ { next }
  /^<!-- .* -->$/ { next }
  { content = 1 }
  END {
    if (header != "" && content == 0) {
      print NR ": " header " (empty section)"
    }
  }
' "$FILE")

if [ -n "$EMPTY_SECTIONS" ]; then
  echo "  WARN  Empty sections found:"
  while IFS= read -r line; do
    echo "         Line $line"
  done <<< "$EMPTY_SECTIONS"
  ERRORS=$((ERRORS + 1))
  echo ""
fi

# Summary
if [ "$ERRORS" -eq 0 ]; then
  echo "  OK  $FILE is fully filled in!"
  exit 0
else
  echo "  $ERRORS issue(s) found. Fill in the placeholders above."
  exit 1
fi
