#!/usr/bin/env bash
#
# secret-scan.sh — PostToolUse hook
# Scans edited files for accidentally committed secrets
#
# Reads tool input from stdin (JSON with tool_name and tool_input)
#

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | grep -oE '"tool_name"\s*:\s*"[^"]*"' | sed 's/.*:\s*"//;s/"$//')

# Only run after file edits
case "$TOOL_NAME" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"\s*:\s*"[^"]*"' | sed 's/.*:\s*"//;s/"$//' || echo "")
[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

# Skip binary files
if file "$FILE_PATH" | grep -q "binary"; then
  exit 0
fi

# Skip lock files and common non-source files
BASENAME=$(basename "$FILE_PATH")
case "$BASENAME" in
  package-lock.json|yarn.lock|pnpm-lock.yaml|*.lock) exit 0 ;;
  *.min.js|*.min.css|*.map) exit 0 ;;
esac

FINDINGS=""

# AWS keys
if grep -nE 'AKIA[0-9A-Z]{16}' "$FILE_PATH" >/dev/null 2>&1; then
  FINDINGS="${FINDINGS}\n  - AWS Access Key ID detected"
fi

# Generic API key patterns (key = "...", api_key: "...", etc.)
if grep -nE '(api[_-]?key|api[_-]?secret|auth[_-]?token|access[_-]?token|secret[_-]?key)\s*[=:]\s*["\x27][A-Za-z0-9+/=_-]{20,}["\x27]' "$FILE_PATH" >/dev/null 2>&1; then
  FINDINGS="${FINDINGS}\n  - API key or token assignment detected"
fi

# Private keys
if grep -nE 'BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY' "$FILE_PATH" >/dev/null 2>&1; then
  FINDINGS="${FINDINGS}\n  - Private key detected"
fi

# Common password patterns
if grep -nE '(password|passwd|pwd)\s*[=:]\s*["\x27][^"\x27]{8,}["\x27]' "$FILE_PATH" >/dev/null 2>&1; then
  FINDINGS="${FINDINGS}\n  - Hardcoded password detected"
fi

# JWT tokens
if grep -nE 'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}' "$FILE_PATH" >/dev/null 2>&1; then
  FINDINGS="${FINDINGS}\n  - JWT token detected"
fi

# GitHub tokens
if grep -nE '(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9_]{36,}' "$FILE_PATH" >/dev/null 2>&1; then
  FINDINGS="${FINDINGS}\n  - GitHub token detected"
fi

if [ -n "$FINDINGS" ]; then
  echo "WARNING: Potential secrets found in $FILE_PATH"
  echo -e "$FINDINGS"
  echo ""
  echo "If these are intentional (e.g., test fixtures, examples),"
  echo "you can ignore this warning. Otherwise, remove the secrets"
  echo "and use environment variables instead."
  # Exit 0 (warning only, don't block)
  # Change to exit 2 if you want to block edits with secrets
  exit 0
fi

exit 0
