#!/usr/bin/env bash
#
# notify-waiting.sh — Notification hook (fallback: Stop)
#
# Pushes an out-of-terminal signal the moment Claude is waiting for you — user
# input or a permission prompt — so you don't have to babysit a long autonomous
# run (/loop, auto-mode, /ship). This is the local shell-hook slice of the
# "never go dark" idea: no hosted control-plane, no task board, just a ping.
#
# Two independent, layered signals — both are advisory and both fail open:
#
#   1. Local desktop notification. Uses terminal-notifier or osascript (macOS)
#      or notify-send (Linux) when present. Silent no-op if none is installed
#      (e.g. CI, headless servers) — never an error.
#   2. Optional remote push. OFF by default. Fires only when you opt in via env:
#        CCK_NOTIFY_NTFY_URL       full ntfy topic URL, e.g. https://ntfy.sh/my-topic
#        CCK_NOTIFY_PUSHOVER_TOKEN + CCK_NOTIFY_PUSHOVER_USER   Pushover app/user keys
#      With none set, no network call is ever made.
#
#   CCK_NOTIFY_DRY_RUN=1  suppresses the real desktop popup and, instead of
#                         calling curl, prints the remote target(s) to stderr —
#                         for offline testing and config checks.
#
# Contract: strictly advisory. It is wired on the Notification event, never
# blocks or mutates tool flow, and ALWAYS exits 0. Pairs with
# task-complete-notify.sh (Stop = "task done"); this one is "agent is waiting".
#

set -euo pipefail

# Consume stdin (hook protocol) and pull the notification text.
INPUT=$(cat)
# `|| true` keeps a missing lib/ from tripping errexit — this hook must fail open.
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd || true)"
if [ -n "$HOOK_LIB" ] && [ -f "$HOOK_LIB/json-parse.sh" ]; then
  # shellcheck source=lib/json-parse.sh
  source "$HOOK_LIB/json-parse.sh"
  MESSAGE=$(parse_json_field "message")
fi

TITLE="Claude Code"
MESSAGE="${MESSAGE:-Claude is waiting for your input}"

# Sanitize for safe interpolation into osascript / notify-send: drop quotes and
# backslashes, flatten newlines, cap length. Notification text is trusted-ish
# but this keeps a stray quote from mangling the AppleScript string.
MESSAGE=${MESSAGE//\\/ }
MESSAGE=${MESSAGE//\"/}
MESSAGE=${MESSAGE//$'\n'/ }
MESSAGE=${MESSAGE:0:200}

DRY_RUN="${CCK_NOTIFY_DRY_RUN:-}"

# --- 1. Local desktop notification (silent if no notifier is present) --------
# Dry-run suppresses the real popup so tests/config-checks have no side effects.
if [ -z "$DRY_RUN" ]; then
  if command -v terminal-notifier &>/dev/null; then
    terminal-notifier -title "$TITLE" -message "$MESSAGE" &>/dev/null || true
  elif command -v osascript &>/dev/null; then
    osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\"" &>/dev/null || true
  elif command -v notify-send &>/dev/null; then
    notify-send "$TITLE" "$MESSAGE" &>/dev/null || true
  fi
fi

# --- 2. Optional remote push (opt-in via env; off by default) ----------------
push_remote() { # only reached when curl exists or we're in dry-run
  # ntfy: POST the message body to the configured topic URL.
  if [ -n "${CCK_NOTIFY_NTFY_URL:-}" ]; then
    if [ -n "$DRY_RUN" ]; then
      printf 'notify-waiting: ntfy -> %s\n' "$CCK_NOTIFY_NTFY_URL" >&2
    else
      curl -fsS -m 5 \
        -H "Title: $TITLE" \
        -d "$MESSAGE" \
        "$CCK_NOTIFY_NTFY_URL" &>/dev/null || true
    fi
  fi

  # Pushover: needs both the application token and the user key.
  if [ -n "${CCK_NOTIFY_PUSHOVER_TOKEN:-}" ] && [ -n "${CCK_NOTIFY_PUSHOVER_USER:-}" ]; then
    if [ -n "$DRY_RUN" ]; then
      printf 'notify-waiting: pushover -> api.pushover.net\n' >&2
    else
      curl -fsS -m 5 \
        --form-string "token=$CCK_NOTIFY_PUSHOVER_TOKEN" \
        --form-string "user=$CCK_NOTIFY_PUSHOVER_USER" \
        --form-string "title=$TITLE" \
        --form-string "message=$MESSAGE" \
        https://api.pushover.net/1/messages.json &>/dev/null || true
    fi
  fi
}

if [ -n "${CCK_NOTIFY_NTFY_URL:-}" ] || { [ -n "${CCK_NOTIFY_PUSHOVER_TOKEN:-}" ] && [ -n "${CCK_NOTIFY_PUSHOVER_USER:-}" ]; }; then
  if [ -n "$DRY_RUN" ] || command -v curl &>/dev/null; then
    push_remote
  fi
fi

exit 0
