#!/usr/bin/env bash
#
# protect-files.sh — PreToolUse hook
# Blocks edits to sensitive files (secrets, credentials, lock files)
#
# Reads tool input from stdin (JSON with tool_name and tool_input)
#

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | cut -d'"' -f4)

# Only check file-writing tools
case "$TOOL_NAME" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

# Extract file path from tool input
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | cut -d'"' -f4 || echo "")
[ -z "$FILE_PATH" ] && exit 0

BASENAME=$(basename "$FILE_PATH")
DIRNAME=$(dirname "$FILE_PATH")

# Protected file patterns
BLOCKED=false
REASON=""

case "$BASENAME" in
  .env|.env.local|.env.production|.env.staging|.env.development)
    BLOCKED=true
    REASON="Environment file with secrets"
    ;;
  .env.*)
    BLOCKED=true
    REASON="Environment file with secrets"
    ;;
  credentials.json|service-account.json|serviceAccountKey.json)
    BLOCKED=true
    REASON="Credential file"
    ;;
  id_rsa|id_ed25519|id_ecdsa|*.pem|*.key)
    BLOCKED=true
    REASON="Private key file"
    ;;
  package-lock.json|yarn.lock|pnpm-lock.yaml|Gemfile.lock|poetry.lock|Cargo.lock)
    BLOCKED=true
    REASON="Lock file (should be auto-generated)"
    ;;
esac

# Check directory patterns
case "$DIRNAME" in
  */.ssh*|*/.gnupg*|*/.aws*)
    BLOCKED=true
    REASON="Sensitive config directory"
    ;;
esac

if [ "$BLOCKED" = true ]; then
  echo "BLOCKED: $REASON — $FILE_PATH"
  echo ""
  echo "If you need to modify this file, ask the user to do it manually"
  echo "or get explicit approval first."
  exit 2
fi

exit 0
