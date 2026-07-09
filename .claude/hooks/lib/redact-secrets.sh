#!/usr/bin/env bash
#
# redact-secrets.sh — shared hook/skill library
#
# Defines redact_secrets(): reads stdin, writes stdout with secret VALUES
# masked as «redacted». Used before agent-authored text is persisted to disk
# where it could later be committed or synced:
#   - scripts/note.sh          → .hook-state/session-journal.md
#   - .claude/hooks/journal-fold.sh → tasks/handoff-<session-id>.md (durable)
#
# Design goals (see TAN-4733):
#   - Mask the VALUE, not the whole line — prose stays readable.
#   - Conservative — no false positives on words like "password reset flow"
#     (an assignment separator [:=] or a `Bearer ` prefix is required for the
#     key=value forms; standalone high-entropy token formats are masked on sight).
#   - Portable — pure python3 with a `cat` passthrough fallback if python3 is
#     absent (redaction is defense-in-depth, never a hard gate).
#
# Source it, then call:  redact_secrets < infile   |   printf '%s' "$x" | redact_secrets
#

# The redactor lives in python for reliable case-insensitive regex. The program
# is captured into a variable via a quoted heredoc so it can contain any quote
# character, and so real stdin stays free for the data being redacted.
_REDACT_PY_PROG=''
IFS='' read -r -d '' _REDACT_PY_PROG <<'PYEOF' || true
import sys, re

text = sys.stdin.read()
R = "«redacted»"  # «redacted»

# key = value / key: value / key => value — mask the value after the key token.
# The separator requirement is what keeps prose ("password reset flow") safe.
# Run this BEFORE the standalone patterns so a `key=<token>` value is consumed
# whole (fixed-width token patterns would otherwise leave a trailing char).
KEY = (
    r'(?i)(\b(?:api[_-]?key|api[_-]?secret|auth[_-]?token|access[_-]?token'
    r'|refresh[_-]?token|session[_-]?key|secret[_-]?key|client[_-]?secret'
    r'|secret|password|passwd|pwd|private[_-]?key|token)\b\s*(?:=>|[:=])\s*)'
)

# (A1) Authorization: Bearer <token>
text = re.sub(r'(?i)(\bBearer\s+)[A-Za-z0-9._~+/\-]{6,}=*', lambda m: m.group(1) + R, text)

# (A2) quoted value — mask whatever is inside the quotes.
text = re.sub(KEY + r'(["\'])(?:(?!\2).)+\2',
              lambda m: m.group(1) + m.group(2) + R + m.group(2), text)

# (A3) unquoted value — a contiguous secret-like run of >=6 token chars.
# The length floor avoids masking short prose words after a colon.
text = re.sub(KEY + r'[A-Za-z0-9._+/=~\-]{6,}', lambda m: m.group(1) + R, text)

# (B) Standalone high-signal token formats — unambiguous, mask any that remain
# (e.g. a token pasted without a key= prefix).
for pat in (
    r'AKIA[0-9A-Z]{16}',                                              # AWS access key id
    r'(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36,}',                      # GitHub tokens
    r'xox[bpars]-[A-Za-z0-9-]{10,}',                                  # Slack tokens
    r'AIza[0-9A-Za-z_\-]{35}',                                        # Google API key
    r'eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}',  # JWT
    r'sk-[A-Za-z0-9]{20,}',                                           # OpenAI-style keys
):
    text = re.sub(pat, R, text)

sys.stdout.write(text)
PYEOF

redact_secrets() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "$_REDACT_PY_PROG" 2>/dev/null || cat
  else
    cat
  fi
}
