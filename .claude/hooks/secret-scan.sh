#!/usr/bin/env bash
#
# secret-scan.sh — PostToolUse hook
# Scans edited files for accidentally committed secrets
#
# Reads tool input from stdin (JSON with tool_name and tool_input)
#

set -euo pipefail

INPUT=$(cat)
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
source "$HOOK_LIB/json-parse.sh"

TOOL_NAME=$(parse_json_field "tool_name")

# Only run after file edits
case "$TOOL_NAME" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(parse_json_field "file_path")
[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

# Skip binary files (check for "text" in file output — works on both macOS and Linux)
if ! file "$FILE_PATH" | grep -qi "text"; then
  exit 0
fi

# Skip lock files and common non-source files
BASENAME=$(basename "$FILE_PATH")
case "$BASENAME" in
  package-lock.json|yarn.lock|pnpm-lock.yaml|*.lock) exit 0 ;;
  *.min.js|*.min.css|*.bundle.js|*.map) exit 0 ;;
  *.g.dart|*.designer.cs|*.generated.swift|*.generated.ts) exit 0 ;;
esac

FINDINGS=""

# AWS keys
if grep -nE 'AKIA[0-9A-Z]{16}' "$FILE_PATH" >/dev/null 2>&1; then
  FINDINGS="${FINDINGS}\n  - AWS Access Key ID detected"
fi

# Generic API key patterns (key = "...", api_key: "...", etc.)
SQ="'"
if grep -nE "(api[_-]?key|api[_-]?secret|auth[_-]?token|access[_-]?token|secret[_-]?key)[[:space:]]*[=:][[:space:]]*[\"${SQ}][A-Za-z0-9+/=_-]{20,}[\"${SQ}]" "$FILE_PATH" >/dev/null 2>&1; then
  FINDINGS="${FINDINGS}\n  - API key or token assignment detected"
fi

# Private keys
if grep -nE 'BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY' "$FILE_PATH" >/dev/null 2>&1; then
  FINDINGS="${FINDINGS}\n  - Private key detected"
fi

# Common password patterns
if grep -nE "(password|passwd|pwd)[[:space:]]*[=:][[:space:]]*[\"${SQ}][^\"${SQ}]{8,}[\"${SQ}]" "$FILE_PATH" >/dev/null 2>&1; then
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

# Slack tokens
if grep -nE 'xox[bpars]-[A-Za-z0-9-]{10,}' "$FILE_PATH" >/dev/null 2>&1; then
  FINDINGS="${FINDINGS}\n  - Slack token detected"
fi

# Google API keys
if grep -nE 'AIza[0-9A-Za-z_-]{35}' "$FILE_PATH" >/dev/null 2>&1; then
  FINDINGS="${FINDINGS}\n  - Google API key detected"
fi

# Stripe keys
if grep -nE '(sk|pk)_live_[A-Za-z0-9]{20,}' "$FILE_PATH" >/dev/null 2>&1; then
  FINDINGS="${FINDINGS}\n  - Stripe live key detected"
fi

# SendGrid keys
if grep -nE 'SG\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}' "$FILE_PATH" >/dev/null 2>&1; then
  FINDINGS="${FINDINGS}\n  - SendGrid API key detected"
fi

# Twilio Account SID and Auth Token
if grep -nE 'AC[a-f0-9]{32}' "$FILE_PATH" >/dev/null 2>&1; then
  FINDINGS="${FINDINGS}\n  - Twilio Account SID detected"
fi

# npm tokens
if grep -nE 'npm_[A-Za-z0-9]{36,}' "$FILE_PATH" >/dev/null 2>&1; then
  FINDINGS="${FINDINGS}\n  - npm token detected"
fi

# PyPI tokens
if grep -nE 'pypi-[A-Za-z0-9_-]{50,}' "$FILE_PATH" >/dev/null 2>&1; then
  FINDINGS="${FINDINGS}\n  - PyPI token detected"
fi

# Database connection strings with passwords
if grep -nE '(mongodb|postgres|postgresql|mysql|redis)://[^:]+:[^@]+@' "$FILE_PATH" >/dev/null 2>&1; then
  FINDINGS="${FINDINGS}\n  - Database connection string with credentials detected"
fi

if [ -n "$FINDINGS" ]; then
  echo "WARNING: Potential secrets found in $FILE_PATH"
  printf '%b\n' "$FINDINGS"
  echo ""
  echo "If these are intentional (e.g., test fixtures, examples),"
  echo "you can ignore this warning. Otherwise, remove the secrets"
  echo "and use environment variables instead."
  # Exit 0 (warning only, don't block)
  # Change to exit 2 if you want to block edits with secrets
  exit 0
fi

exit 0
