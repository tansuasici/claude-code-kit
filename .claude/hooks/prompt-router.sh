#!/usr/bin/env bash
#
# prompt-router.sh — UserPromptSubmit hook
#
# Inspects the user prompt and injects domain-specific reminders when keywords
# match. Replaces "if the user mentions auth, remember to also..." prompt rules
# that the agent might forget.
#
# Emits nothing (no JSON) if no keywords match — keeps context clean.
# Always exits 0.
#

set -euo pipefail

INPUT=$(cat)

# Extract the prompt text (Claude Code passes it under "prompt").
# Use python3 for robust parsing; fall back to grep-based extraction.
PROMPT=""
if command -v python3 &>/dev/null; then
  PROMPT=$(printf '%s' "$INPUT" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("prompt",""))' 2>/dev/null || true)
elif command -v jq &>/dev/null; then
  PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // ""' 2>/dev/null || true)
else
  # Best-effort: strip the JSON envelope around "prompt"
  PROMPT=$(printf '%s' "$INPUT" | grep -oE '"prompt"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' || true)
fi

[ -z "$PROMPT" ] && exit 0

# Case-insensitive match
LOWER=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')

REMINDERS=""
append() { REMINDERS="${REMINDERS}${1}"$'\n'; }

# Keyword matching uses a leading word boundary plus a stem — we deliberately
# DO NOT close with `\b`, because that would miss inflections like
# "authentication" (auth + entic), "permissions" (permission + s),
# "deployment" (deploy + ment). Trailing characters are allowed.

# Auth / security
if printf '%s' "$LOWER" | grep -qE '\b(auth|login|signin|sign-in|session|jwt|oauth|password|credential|permission|rbac|acl)'; then
  append "[Auth/security context] This touches authentication or authorization. Treat token handling, session expiry, and permission checks as required test cases. Avoid logging secrets, sessions, or credentials."
fi

# Payments / billing
if printf '%s' "$LOWER" | grep -qE '\b(payment|billing|invoice|refund|checkout|stripe|subscription|charge)'; then
  append "[Billing context] Customer-visible behavior — update tests with any behavior change. Never log full card data or PII. Reconcile any state change with the source of truth (DB, Stripe, ledger)."
fi

# Migrations / schema
if printf '%s' "$LOWER" | grep -qE '\b(migration|schema|alter table|drop table|rename column|backfill)'; then
  append "[Migration context] Migrations are protected changes. Stop and present a plan with rollback. Confirm read/write impact on production data, lock duration, and whether a backfill is needed."
fi

# Deploy / release
if printf '%s' "$LOWER" | grep -qE '\b(deploy|release|production|prod\b|ship\b|rollout|hotfix)'; then
  append "[Deploy context] Treat as a sensitive action. Verify the change is on the right branch, CI is green, CHANGELOG is updated, and a rollback path is documented before tagging or pushing."
fi

# Dependencies
if printf '%s' "$LOWER" | grep -qE '\b(add a dependency|new dependency|install package|npm install|pip install|cargo add|go get)'; then
  append "[Dependency context] New dependencies are protected changes. Provide at least two alternatives and a tradeoff analysis before adding (per CLAUDE.md → Protected Changes)."
fi

[ -z "$REMINDERS" ] && exit 0

# Emit JSON
if command -v python3 &>/dev/null; then
  printf '%s' "$REMINDERS" | python3 -c 'import json,sys; print(json.dumps({"additionalContext": sys.stdin.read().rstrip()}))'
elif command -v jq &>/dev/null; then
  printf '%s' "$REMINDERS" | jq -Rs '{additionalContext: (. | rtrimstr("\n"))}'
else
  ESCAPED=$(printf '%s' "$REMINDERS" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk 'BEGIN{ORS=""} {print; printf "\\n"}')
  printf '{"additionalContext":"%s"}\n' "$ESCAPED"
fi

exit 0
