#!/usr/bin/env bash
#
# unicode-scan.sh — PostToolUse hook
# Detects invisible Unicode characters that may indicate Glassworm-style
# supply chain attacks or code obfuscation.
#
# Scans edited files for:
#   - Variation Selectors (U+FE00–FE0F) — Glassworm payload encoding
#   - Variation Selectors Supplement (U+E0100–E01EF) — Glassworm payload encoding
#   - Zero Width characters (U+200B–200D, U+2060, U+FEFF mid-file)
#   - Tags block (U+E0000–E007F) — hidden text encoding
#
# Exit 0 = warn only (default)
# Change final exit to "exit 2" to block edits containing invisible Unicode
#

set -euo pipefail

INPUT=$(cat)

parse_json_field() {
  local field="$1"
  if command -v jq &>/dev/null; then
    echo "$INPUT" | jq -r "(.tool_input.${field} // .${field}) // empty" 2>/dev/null || true
  elif command -v python3 &>/dev/null; then
    echo "$INPUT" | python3 -c "import sys,json;d=json.load(sys.stdin);v=d.get('tool_input',d);print(v.get('${field}',d.get('${field}','')))" 2>/dev/null || true
  else
    echo "$INPUT" | grep -oE "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' || true
  fi
}

TOOL_NAME=$(parse_json_field "tool_name")

# Only run after file edits
case "$TOOL_NAME" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(parse_json_field "file_path")
[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

# Skip binary files
if ! file "$FILE_PATH" | grep -qi "text"; then
  exit 0
fi

# Skip files that legitimately contain Unicode (fonts, locale data, etc.)
BASENAME=$(basename "$FILE_PATH")
case "$BASENAME" in
  package-lock.json|yarn.lock|pnpm-lock.yaml|*.lock) exit 0 ;;
  *.min.js|*.min.css|*.bundle.js|*.map) exit 0 ;;
  *.woff|*.woff2|*.ttf|*.otf|*.eot) exit 0 ;;
  *.po|*.mo) exit 0 ;;
esac

# Check for allowlist comment in file
if head -5 "$FILE_PATH" | grep -q "kit-allow-unicode" 2>/dev/null; then
  exit 0
fi

FINDINGS=""

# Use perl for reliable Unicode detection (available on macOS and most Linux)
if command -v perl &>/dev/null; then

  # Zero Width Space (U+200B)
  if perl -CSD -ne 'exit 1 if /\x{200B}/' "$FILE_PATH" 2>/dev/null; then :; else
    FINDINGS="${FINDINGS}\n  - Zero Width Space (U+200B) detected"
  fi

  # Zero Width Non-Joiner (U+200C)
  if perl -CSD -ne 'exit 1 if /\x{200C}/' "$FILE_PATH" 2>/dev/null; then :; else
    FINDINGS="${FINDINGS}\n  - Zero Width Non-Joiner (U+200C) detected"
  fi

  # Zero Width Joiner (U+200D)
  if perl -CSD -ne 'exit 1 if /\x{200D}/' "$FILE_PATH" 2>/dev/null; then :; else
    FINDINGS="${FINDINGS}\n  - Zero Width Joiner (U+200D) detected"
  fi

  # Word Joiner (U+2060)
  if perl -CSD -ne 'exit 1 if /\x{2060}/' "$FILE_PATH" 2>/dev/null; then :; else
    FINDINGS="${FINDINGS}\n  - Word Joiner (U+2060) detected"
  fi

  # BOM mid-file (U+FEFF) — skip first line (legitimate BOM position)
  if tail -n +2 "$FILE_PATH" | perl -CSD -ne 'exit 1 if /\x{FEFF}/' 2>/dev/null; then :; else
    FINDINGS="${FINDINGS}\n  - Zero Width No-Break Space / BOM mid-file (U+FEFF) detected"
  fi

  # Variation Selectors (U+FE00–FE0F) — primary Glassworm vector
  if perl -CSD -ne 'exit 1 if /[\x{FE00}-\x{FE0F}]/' "$FILE_PATH" 2>/dev/null; then :; else
    FINDINGS="${FINDINGS}\n  - Variation Selectors (U+FE00-FE0F) detected — GLASSWORM ATTACK VECTOR"
  fi

  # Variation Selectors Supplement (U+E0100–E01EF) — primary Glassworm vector
  if perl -CSD -ne 'exit 1 if /[\x{E0100}-\x{E01EF}]/' "$FILE_PATH" 2>/dev/null; then :; else
    FINDINGS="${FINDINGS}\n  - Variation Selectors Supplement (U+E0100-E01EF) detected — GLASSWORM ATTACK VECTOR"
  fi

  # Tags block (U+E0000–E007F) — hidden text encoding
  if perl -CSD -ne 'exit 1 if /[\x{E0000}-\x{E007F}]/' "$FILE_PATH" 2>/dev/null; then :; else
    FINDINGS="${FINDINGS}\n  - Tags block (U+E0000-E007F) detected — hidden text encoding"
  fi

elif command -v python3 &>/dev/null; then
  # Fallback: use python3 for detection
  PYTHON_RESULT=$(python3 -c "
import sys, re

findings = []
try:
    with open(sys.argv[1], 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
        # Skip first-line BOM
        lines = content.split('\n')
        content_no_first = '\n'.join(lines[1:]) if len(lines) > 1 else ''

        checks = [
            (r'\u200B', 'Zero Width Space (U+200B)'),
            (r'\u200C', 'Zero Width Non-Joiner (U+200C)'),
            (r'\u200D', 'Zero Width Joiner (U+200D)'),
            (r'\u2060', 'Word Joiner (U+2060)'),
            (r'[\uFE00-\uFE0F]', 'Variation Selectors (U+FE00-FE0F) — GLASSWORM ATTACK VECTOR'),
            (r'[\U000E0000-\U000E007F]', 'Tags block (U+E0000-E007F) — hidden text encoding'),
            (r'[\U000E0100-\U000E01EF]', 'Variation Selectors Supplement (U+E0100-E01EF) — GLASSWORM ATTACK VECTOR'),
        ]
        for pattern, desc in checks:
            if re.search(pattern, content):
                findings.append(desc)

        # BOM mid-file only
        if re.search(r'\uFEFF', content_no_first):
            findings.append('Zero Width No-Break Space / BOM mid-file (U+FEFF)')

except Exception:
    pass

for f in findings:
    print(f)
" "$FILE_PATH" 2>/dev/null)

  if [ -n "$PYTHON_RESULT" ]; then
    while IFS= read -r line; do
      FINDINGS="${FINDINGS}\n  - ${line}"
    done <<< "$PYTHON_RESULT"
  fi
else
  # No perl or python3 — skip check silently
  exit 0
fi

if [ -n "$FINDINGS" ]; then
  echo "SECURITY WARNING: Invisible Unicode characters detected in $FILE_PATH"
  printf '%b\n' "$FINDINGS"
  echo ""
  echo "This may indicate a Glassworm-style supply chain attack."
  echo "Invisible characters can hide malicious payloads that execute via eval()."
  echo ""
  echo "Actions:"
  echo "  1. Inspect the file with: xxd $FILE_PATH | less"
  echo "  2. If intentional, add '// kit-allow-unicode' to the first 5 lines"
  echo ""
  # Exit 0 = warn only. Change to exit 2 to block edits with invisible Unicode.
  exit 0
fi

exit 0
