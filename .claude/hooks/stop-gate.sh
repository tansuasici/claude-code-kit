#!/usr/bin/env bash
#
# stop-gate.sh — Stop hook
#
# Blocks completion (exit 2) while any file this session edited has no passing
# quality gate: its check failed, timed out or errored, its result could not be
# recorded, or the file changed after its last check and still doesn't pass.
# Reads the per-file state quality-gate.sh keeps (.hook-state/quality-gate-state.json,
# lib/gate-state.sh) and, for edits made without a usable python3, its plain log
# (.hook-state/quality-gate-files.tsv); falls back to the
# `.hook-state/last_quality_gate.json` summary when only that exists.
# Replaces the prompt rule "Verification (Mandatory Order)" — which the agent can
# ignore — with deterministic enforcement.
#
# Whose results: the Stop payload's session_id. A stop answers for the files its
# own session edited; a record or a stop without a session id counts everywhere
# (fail closed). Where: the checkout the session is working in (the payload's
# cwd, which follows Claude into a git worktree), the project it started in
# (CLAUDE_PROJECT_DIR), and every other worktree this session stored results in
# (.hook-state/quality-gate-roots).
#
# Fails closed: a gate state that exists but can't be read — a torn or edited
# file, a python3 that doesn't run, a reader that errors — blocks with a message
# saying how to reset it; so does a .hook-state that isn't writable, a result that
# could not be recorded, and any unexpected error in this hook. A scope-wide
# failure whose files were all renamed or deleted still blocks.
#
# Stale files — changed after their check by Bash, a formatter or codegen, or
# whose check never finished — are re-verified here by re-running quality-gate.sh
# on them (one file per check scope, at most 3), within a time budget
# (CCK_STOP_REVERIFY_BUDGET, 300s — Claude Code kills a Stop hook at its own
# timeout, 600s by default, and a killed hook doesn't block). A stale file not
# re-verified in time blocks.
#
# Files no check covers (skipped: unsupported language, tool not installed) don't
# block — quality-gate.sh told Claude at edit time that they are NOT verified —
# and never count as passed.
#
# Escape hatch: set CLAUDE_SKIP_QUALITY_GATE=1 (or SKIP_QUALITY_GATE=1) for
# the session when test infrastructure is broken or an intentional ship is
# in progress. Recording the bypass reason in tasks/decisions.md or
# tasks/handoff.md is strongly recommended.
#
# Runs before task-complete-notify.sh so the notification only fires on
# successful completion.
#

set -euo pipefail

INPUT=$(cat)
[ -n "$INPUT" ] || INPUT='{}'

# Fail closed: an unexpected error in this hook must not read as "allowed".
on_exit() {
  local rc=$?
  if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then
    echo "BLOCKED by stop-gate.sh: the gate check itself failed (exit $rc), so completion can't be confirmed. Set SKIP_QUALITY_GATE=1 to bypass while it is broken." >&2
    exit 2
  fi
}
trap on_exit EXIT

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_LIB="$HOOK_DIR/lib"
source "$HOOK_LIB/json-parse.sh"
source "$HOOK_LIB/state-counter.sh"
source "$HOOK_LIB/roots.sh"
source "$HOOK_LIB/project-commands.sh"
source "$HOOK_LIB/gate-state.sh"

python3_usable || true  # probe once; the command substitutions below reuse the answer

SID=$(parse_json_field "session_id")
SID="${SID//[[:space:]]/_}"
SID="${SID:--}"
ROOT=$(hook_project_root "$(parse_json_field "cwd")")
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
MARKER=$(gate_marker_path "$PROJECT_DIR")
TAB=$'\t'
NL=$'\n'
BUDGET="${CCK_STOP_REVERIFY_BUDGET:-300}"
case "$BUDGET" in ''|*[!0-9]*) BUDGET=300 ;; esac
BUDGET_SPENT=0

# ours SESSION — a record counts for this stop: same session, or either side has
# no session id (fail closed).
ours() { [ "$SID" = "-" ] || [ "$1" = "-" ] || [ "$1" = "$SID" ]; }
marker_trusted() { [ -f "$MARKER" ] && [ ! -L "$MARKER" ] && [ -O "$MARKER" ]; }

ROOTS="$NL"
add_root() {
  if [ -n "$1" ]; then
    case "$ROOTS" in *"$NL$1$NL"*) ;; *) ROOTS="$ROOTS$1$NL" ;; esac
  fi
}
add_root "$ROOT"
add_root "$PROJECT_DIR"
if [ -f "$PROJECT_DIR/.hook-state/quality-gate-roots" ]; then
  while IFS=$'\t' read -r s r _; do
    if ours "$s"; then add_root "$r"; fi
  done <"$PROJECT_DIR/.hook-state/quality-gate-roots"
fi
if marker_trusted; then
  while IFS=$'\t' read -r s r _; do
    if ours "$s"; then add_root "$r"; fi
  done <"$MARKER"
fi

# unrecorded_for ROOT — this session's files whose result for ROOT could not be
# recorded (quality-gate.sh's cannot_record), one per line.
unrecorded_for() {
  local s f r _ side="$1/.hook-state/quality-gate-unrecorded"
  if [ -f "$side" ]; then
    while IFS=$'\t' read -r s f _; do
      if ours "$s" && [ -f "$f" ]; then printf '%s\n' "$f"; fi
    done <"$side"
  fi
  if marker_trusted; then
    while IFS=$'\t' read -r s r f _; do
      if ours "$s" && [ "$r" = "$1" ] && [ -f "$f" ]; then printf '%s\n' "$f"; fi
    done <"$MARKER"
  fi
}

root_has_state() {
  local h="$1/.hook-state"
  [ -f "$h/quality-gate-state.json" ] || [ -f "$h/quality-gate-files.tsv" ] \
    || [ -f "$h/last_quality_gate.json" ] || { [ -d "$h" ] && [ ! -w "$h" ]; }
}

ACTIVE=""
while IFS= read -r r; do
  if [ -n "$r" ] && { root_has_state "$r" || [ -n "$(unrecorded_for "$r")" ]; }; then
    ACTIVE="$ACTIVE$r$NL"
  fi
done <<<"$ROOTS"

# No state → no gated edits happened (or hooks weren't wired) → allow stop
if [ -z "$ACTIVE" ]; then
  exit 0
fi

# Escape hatch (either name works). Marked in quality-gate-history.json so
# session-end.sh can surface skip_gate_used in the scorecard.
if [ "${CLAUDE_SKIP_QUALITY_GATE:-0}" = "1" ] || [ "${SKIP_QUALITY_GATE:-0}" = "1" ]; then
  bump_counter "$ROOT/.hook-state/quality-gate-history.json" "skip_gate_used"
  echo "stop-gate: bypassed via SKIP_QUALITY_GATE" >&2
  exit 0
fi

rel() { printf '%s' "${2#"$1"/}"; }  # rel ROOT PATH
dash() { [ "$1" = "-" ] || printf '%s' "$1"; }

# tsv_lines TSV — the plain per-file log (no usable python3) in gate_state_lines'
# format, plus tracked<TAB>file for every file of this session it has a line for.
# The latest line per file wins; a file whose content changed since is stale.
tsv_lines() {
  local s f st stamp kind scope detail cur i n=0 seen="$NL" live="$NL" dead=""
  local -a F ST STAMP KIND SCOPE DETAIL
  if [ ! -r "$1" ]; then
    printf 'error\t%s is unreadable\n' "$1"
    return 0
  fi
  while IFS=$'\t' read -r s f st stamp kind scope _ detail; do
    if ours "$s"; then
      F[n]="$f"; ST[n]="$st"; STAMP[n]="$stamp"; KIND[n]="$kind"; SCOPE[n]="$scope"; DETAIL[n]="$detail"
      n=$((n + 1))
    fi
  done <"$1"
  i=$n
  while [ "$i" -gt 0 ]; do
    i=$((i - 1))
    f="${F[i]}"
    case "$seen" in *"$NL$f$NL"*) continue ;; esac
    seen="$seen$f$NL"
    printf 'tracked\t%s\n' "$f"
    if [ ! -f "$f" ]; then
      case "${KIND[i]}:${ST[i]}" in
        scope:failed|scope:timeout|scope:error) dead="$dead${ST[i]}$TAB${SCOPE[i]}$TAB${DETAIL[i]}$NL" ;;
      esac
      continue
    fi
    live="$live${SCOPE[i]}$NL"
    case "${ST[i]}" in
      v2) ;;
      skipped) printf 'unverified\t%s\t%s\n' "$f" "${DETAIL[i]}" ;;
      *)
        cur=$(gate_file_stamp "$f")
        if [ "${ST[i]}" = "running" ] || [ "${STAMP[i]}" = "-" ] || [ "$cur" != "${STAMP[i]}" ]; then
          printf 'stale\t%s\t%s\t%s\n' "$f" "${SCOPE[i]}" "${DETAIL[i]}"
        else
          case "${ST[i]}" in
            failed|timeout|error) printf 'block\t%s\t%s\t%s\t-\n' "${ST[i]}" "$f" "${DETAIL[i]}" ;;
          esac
        fi
        ;;
    esac
  done
  # A scope-wide failure whose files are all gone (renamed or deleted) still blocks.
  while IFS=$'\t' read -r st scope detail; do
    [ -n "$st" ] || continue
    case "$live" in *"$NL$scope$NL"*) continue ;; esac
    printf 'orphan\t%s\t%s\t%s\n' "$st" "$scope" "$detail"
    live="$live$scope$NL"
  done <<<"$dead"
}

# v2_relevant STATE — whether a per-file state that can't be read without python3
# may hold this session's records (then it blocks; older sessions' don't).
v2_relevant() {
  local rc=0
  [ "$SID" != "-" ] || return 0
  if command -v jq >/dev/null 2>&1; then
    jq -e --arg s "$SID" '[(.files // {})[] | (.sessions // []) | select(length == 0 or index("-") != null or index($s) != null)] | length > 0' \
      "$1" >/dev/null 2>&1 || rc=$?
    [ "$rc" != 1 ]
    return
  fi
  grep -qF -- "\"$SID\"" "$1" 2>/dev/null || ! grep -q '"sessions"' "$1" 2>/dev/null
}

# summary_line SUMMARY — the verdict of a summary-only state (from before per-file
# results), if it is this session's.
summary_line() {
  local out="" status sess
  if python3_usable; then
    out=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); print((d.get("status") or "") + "\t" + (d.get("session_id") or "-"))' "$1" 2>/dev/null) || out=""
  elif command -v jq &>/dev/null; then
    out=$(jq -r '(.status // "") + "\t" + (.session_id // "-")' "$1" 2>/dev/null) || out=""
  else
    status=$(grep -oE '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$1" | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' || true)
    sess=$(grep -oE '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' "$1" | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' || true)
    out="$status$TAB${sess:--}"
  fi
  status="${out%%"$TAB"*}"
  sess="${out#*"$TAB"}"
  [ "$sess" != "$out" ] || sess="-"
  ours "$sess" || return 0
  case "$status" in
    failed|timeout|error) printf 'summary\t%s\n' "$status" ;;
    "") printf 'unreadable\t%s is missing or unreadable\n' "$(basename "$1")" ;;
  esac
}

# root_lines ROOT — everything in ROOT that isn't verified for this session.
root_lines() {
  local root="$1" hs="$1/.hook-state" tsv_out="" rem="" f config_ok=1
  local -a args
  if [ -d "$hs" ] && [ ! -w "$hs" ]; then
    printf 'unwritable\t%s\n' "$hs"
  fi
  if [ -f "$hs/quality-gate-files.tsv" ]; then
    tsv_out=$(tsv_lines "$hs/quality-gate-files.tsv")
    printf '%s\n' "$tsv_out"
  fi
  # A file noted as unrecorded counts as recorded once there is a record for it
  # (a stale one is re-verified like any other).
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$NL$tsv_out$NL" in
      *"${NL}tracked$TAB$f$NL"*) ;;
      *) rem="$rem$f$NL" ;;
    esac
  done <<<"$(unrecorded_for "$root")"
  if [ -f "$hs/quality-gate-state.json" ]; then
    if python3_usable; then
      if [ -n "$(project_commands_error "$root")" ]; then
        config_ok=0
      fi
      args=()
      while IFS= read -r f; do
        if [ -n "$f" ]; then args[${#args[@]}]="$f"; fi
      done <<<"$rem"
      rem=""
      # On failure gate_state_lines prints an "error" line, which blocks.
      gate_state_lines "$hs/quality-gate-state.json" "$config_ok" "$SID" ${args[@]+"${args[@]}"} || true
    elif v2_relevant "$hs/quality-gate-state.json"; then
      printf 'nopython\t%s\n' "$hs/quality-gate-state.json"
    fi
  elif [ ! -f "$hs/quality-gate-files.tsv" ] && [ -f "$hs/last_quality_gate.json" ]; then
    summary_line "$hs/last_quality_gate.json"
  fi
  while IFS= read -r f; do
    if [ -n "$f" ]; then printf 'unrecorded\t%s\n' "$f"; fi
  done <<<"$rem"
}

# reverify FILE — re-run quality-gate.sh on FILE within what is left of the budget.
# Its output is swallowed: the refreshed state is what counts.
reverify() {
  local left=$((BUDGET - SECONDS))
  if [ "$left" -le 0 ]; then
    BUDGET_SPENT=1
    return 0
  fi
  printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"},"session_id":"%s"}' "$(json_str "$1")" "$(json_str "$SID")" \
    | CCK_GATE_TIMEOUT_CAP="$left" bash "$HOOK_DIR/quality-gate.sh" >/dev/null 2>&1 || true
}

BLOCK_LIST=""
UNVERIFIED=""
SHOWN_STATE=""
UNREADABLE=""

# check_root ROOT — add ROOT's blocking files to BLOCK_LIST and its unverified
# ones to UNVERIFIED.
check_root() {
  local root="$1" blocks="" lines stale="" seen="$NL" n=0 note="" f kind a b c d
  lines=$(root_lines "$root")

  # Re-verify stale files — one per check scope (a scope-wide re-run covers the
  # rest), at most 3, within the stop's time budget.
  while IFS=$'\t' read -r kind a b c d; do
    if [ "$kind" = "stale" ] && [ "$n" -lt 3 ]; then
      case "$seen" in
        *"$NL$b$NL"*) ;;
        *) seen="$seen$b$NL"; stale="$stale$a$NL"; n=$((n + 1)) ;;
      esac
    fi
  done <<<"$lines"
  if [ -n "$stale" ]; then
    while IFS= read -r f; do
      if [ -n "$f" ]; then reverify "$f"; fi
    done <<<"$stale"
    lines=$(root_lines "$root")
  fi
  if [ "$BUDGET_SPENT" = 1 ]; then
    note=" — stop-gate's re-verification budget (${BUDGET}s, CCK_STOP_REVERIFY_BUDGET) ran out"
  fi

  while IFS=$'\t' read -r kind a b c d; do
    case "$kind" in
      block)
        c=$(dash "$c"); d=$(dash "$d")
        blocks="${blocks}  - $(rel "$root" "$b") — $a: ${c}${d:+ ($d)}"$'\n'
        ;;
      stale)
        c=$(dash "$c")
        blocks="${blocks}  - $(rel "$root" "$a") — stale: changed since its last check${c:+ ($c)} and not re-verified$note"$'\n'
        ;;
      orphan)
        c=$(dash "$c")
        blocks="${blocks}  - $(rel "$root" "$b") — its last run $a${c:+ ($c)}, and every file it covered has since been renamed or deleted; save a file it covers so the check runs again"$'\n'
        ;;
      unrecorded)
        blocks="${blocks}  - $(rel "$root" "$a") — its check result could not be recorded"$'\n'
        ;;
      unwritable)
        blocks="${blocks}  - $a is not writable, so gate results can't be recorded there"$'\n'
        ;;
      nopython)
        blocks="${blocks}  - $a can't be read: python3 is missing or doesn't run (on macOS, xcode-select --install)"$'\n'
        UNREADABLE="${UNREADABLE}  $root/.hook-state/"$'\n'
        ;;
      summary)
        blocks="${blocks}  - last quality gate did not pass (status: $a)"$'\n'
        ;;
      error|unreadable)
        blocks="${blocks}  - $a"$'\n'
        UNREADABLE="${UNREADABLE}  $root/.hook-state/"$'\n'
        ;;
      unverified)
        UNVERIFIED="${UNVERIFIED}$(rel "$root" "$a") ($(dash "$b")); "
        ;;
    esac
  done <<<"$lines"

  if [ -n "$blocks" ]; then
    BLOCK_LIST="${BLOCK_LIST}${blocks}"
    SHOWN_STATE="${SHOWN_STATE}State: $root/.hook-state/"$'\n'
  fi
}

while IFS= read -r r <&3; do
  if [ -n "$r" ]; then check_root "$r"; fi
done 3<<<"$ACTIVE"

if [ -n "$BLOCK_LIST" ]; then
  bump_counter "$ROOT/.hook-state/hook-firings.json" "stop-gate"
  RESET_HELP=""
  if [ -n "$UNREADABLE" ]; then
    RESET_HELP="The gate state is unreadable, so the failures it may record can't be ruled out.
To reset it, delete quality-gate-state.json and last_quality_gate.json in
${UNREADABLE}then save the files you edited again so their checks re-run.
"
  fi
  cat <<EOF >&2
BLOCKED by stop-gate.sh: the quality gate has not passed for every file edited this session.
${BLOCK_LIST}${SHOWN_STATE}
${RESET_HELP}Fix the failing check and re-run, or set SKIP_QUALITY_GATE=1 if the
failure is unrelated to your change (e.g. broken test infrastructure).
EOF
  exit 2
fi

if [ -n "$UNVERIFIED" ]; then
  echo "stop-gate: code changed without a passing check (no check covers it — NOT verified): ${UNVERIFIED%; }" >&2
fi

# Non-blocking nudge: the kit mandates a smoke test (CLAUDE.md → Verification
# step 4), but it's manual and a hook can't run it. If verification ran this
# session (ledger has entries) but no smoke-test result is recorded, remind once
# — never block (smoke testing stays a manual step).
LEDGER="$ROOT/.hook-state/verification-ledger.json"
if [ -f "$LEDGER" ] && python3_usable; then
  NEED_SMOKE=$(python3 -c '
import json,sys
try:
    d=json.load(open(sys.argv[1]))
    print("1" if (d.get("entries") and d.get("smoke_test") is None) else "0")
except Exception:
    print("0")' "$LEDGER" 2>/dev/null || echo 0)
  if [ "$NEED_SMOKE" = "1" ]; then
    echo "stop-gate: reminder — auto-gates passed but no smoke-test result is recorded (CLAUDE.md → Verification step 4 is manual). Record it with /verification-status. Non-blocking." >&2
  fi
fi

exit 0
