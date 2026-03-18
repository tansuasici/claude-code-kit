#!/usr/bin/env bash
#
# protect-files.sh — PreToolUse hook
# Blocks edits to sensitive files (secrets, credentials, lock files)
#
# Reads tool input from stdin (JSON with tool_name and tool_input)
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

# Only check file-writing tools
case "$TOOL_NAME" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

# Extract file path from tool input
FILE_PATH=$(parse_json_field "file_path")
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
  .env.example|.env.template|.env.sample|.env.test)
    ;; # Allow these — they don't contain real secrets
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
  *.p12|*.pfx)
    BLOCKED=true
    REASON="Certificate file"
    ;;
  *.jks)
    BLOCKED=true
    REASON="Java keystore file"
    ;;
  firebase-adminsdk*.json)
    BLOCKED=true
    REASON="Firebase Admin SDK credential file"
    ;;
  google-services.json)
    BLOCKED=true
    REASON="Android Google services config"
    ;;
  GoogleService-Info.plist)
    BLOCKED=true
    REASON="iOS Google services config"
    ;;
  package-lock.json|yarn.lock|pnpm-lock.yaml|Gemfile.lock|poetry.lock|Cargo.lock)
    BLOCKED=true
    REASON="Lock file (should be auto-generated)"
    ;;
esac

# Check directory patterns
case "$DIRNAME" in
  */.ssh|*/.ssh/*|*/.gnupg|*/.gnupg/*|*/.aws|*/.aws/*)
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
