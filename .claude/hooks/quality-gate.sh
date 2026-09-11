#!/usr/bin/env bash
#
# quality-gate.sh — PostToolUse hook
#
# After a file edit, runs a fast verification command appropriate to the
# project type (typecheck, lint, or syntax-check) and records the result per
# file in `.hook-state/quality-gate-state.json` (lib/gate-state.sh), with
# `.hook-state/last_quality_gate.json` as the summary — or, without a usable
# python3, in the plain log `.hook-state/quality-gate-files.tsv`. stop-gate.sh
# reads them to decide whether the agent is allowed to finish the turn. Each
# result carries the payload's session_id: a stop answers for its own session.
#
# Does NOT block the edit. Blocking happens in stop-gate.sh based on the
# persisted state — this separation matches Nader Dabit's "Agent Hooks:
# Deterministic Control" model and avoids tying every edit to a block decision.
# What Claude needs to hear now — a failed check, a file no check covers — goes
# out as PostToolUse additionalContext on stdout: stderr from a hook that exits
# 0 only reaches the debug log. The exception is a result that can't be recorded
# (unwritable or unreadable state, a full disk): the file is noted where
# stop-gate.sh finds it, and the hook exits 2 so its stderr reaches Claude.
#
# Statuses: passed · failed · timeout (killed at CCK_QUALITY_GATE_TIMEOUT, 30s,
# together with its whole process group) · error (command not found or not
# executable, invalid .claude/commands.json) · skipped (no check applies —
# recorded with a reason and reported as NOT verified, never as passed).
# Docs, data, config and markup files, and files without an extension, are
# not gated at all.
#

set -euo pipefail

INPUT=$(cat)
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
source "$HOOK_LIB/json-parse.sh"
source "$HOOK_LIB/project-commands.sh"
source "$HOOK_LIB/roots.sh"
source "$HOOK_LIB/run-with-timeout.sh"
source "$HOOK_LIB/gate-state.sh"

TOOL_NAME=$(parse_json_field "tool_name")

case "$TOOL_NAME" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(parse_json_field "file_path")
[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

# Not code → nothing to verify, nothing recorded: files without an extension
# (Makefile, Dockerfile, LICENSE), env files, and docs / data / config / markup.
BASENAME=$(basename "$FILE_PATH")
case "$BASENAME" in
  .env|.env.*) exit 0 ;;
  *.*) EXT=$(printf '%s' "${BASENAME##*.}" | tr '[:upper:]' '[:lower:]') ;;
  *) exit 0 ;;
esac
case "$EXT" in
  md|mdx|markdown|txt|rst|adoc|json|jsonc|json5|yaml|yml|toml|ini|cfg|conf|lock|csv|tsv|xml|html|htm|css|scss|sass|less|svg|png|jpg|jpeg|gif|webp|ico|pdf|log|example|sample|gitignore|gitattributes|editorconfig|dockerignore)
    exit 0 ;;
esac

# Two roots, kept apart (lib/roots.sh):
# - ROOT, the package root, is where the check RUNS: tsconfig lookup, `cd`, go
#   package path. Nearest project marker above the file, stopping at the worktree.
# - PROJECT_ROOT is where the verdict is STORED and .claude/commands.json is read.
#   Normally CLAUDE_PROJECT_DIR, which stop-gate.sh / session-*.sh read — writing
#   state into a nested package dir once hid a failed gate from them. An edit in
#   another git worktree of the same repo (an isolated subagent) belongs to that
#   worktree: its result must neither block nor clear the main checkout's, and its
#   declared checks must run against the worktree's copy of the code. The
#   session still answers for it: stop-gate.sh finds that worktree through
#   .hook-state/quality-gate-roots in the session's project.
ROOT=$(package_root "$FILE_PATH")
[ -z "$ROOT" ] && exit 0  # no project root → nothing to gate
PROJECT_ROOT=$(hook_project_root "$FILE_PATH")
SESSION_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$PROJECT_ROOT/.hook-state"
STATE_V2="$STATE_DIR/quality-gate-state.json"
STATE_FILE="$STATE_DIR/last_quality_gate.json"
FILES_TSV="$STATE_DIR/quality-gate-files.tsv"
python3_usable || true  # probe once; the command substitutions below reuse the answer

# The session this edit belongs to ("-" when the payload has none).
SID=$(parse_json_field "session_id")
SID="${SID//[[:space:]]/_}"
SID="${SID:--}"
TAB=$'\t'
NL=$'\n'

START=$(date +%s)
TOOL_USED=""
STATUS="skipped"
REASON=""
SCOPE_KIND="file"
SCOPE_DIR="$FILE_PATH"
EXIT_CODE=0
STDERR_TAIL=""
OUT=""
RUN_ID=""
START_ERR=""
STAMP=""
CHECK_PID=""
CAPPED=""
OUT_FILE="$STATE_DIR/.gate-output.$$"
GS_RC=0
EXIT_RC=0
UNRECORDED=""

# note_marker — note this file in the marker outside the project
# (gate_marker_path), for results that can't be written inside it. Prints the
# marker's path; fails if it can't be written (or isn't safely ours).
note_marker() {
  local marker
  marker=$(gate_marker_path "$SESSION_DIR")
  printf '%s' "$marker"
  [ ! -L "$marker" ] && { [ ! -e "$marker" ] || [ -O "$marker" ]; } \
    && { printf '%s\t%s\t%s\t%s\n' "$SID" "$PROJECT_ROOT" "$FILE_PATH" "$(date +%s)" >>"$marker"; } 2>/dev/null
}

# cannot_record CAUSE — this result can't be stored where stop-gate.sh reads it.
# Never lose it silently: note the file in .hook-state/quality-gate-unrecorded or,
# failing that, in the marker outside the project, and exit 2 at the end so Claude
# hears it now. stop-gate.sh blocks on noted files until a record for them exists.
cannot_record() {
  local marker
  STATUS="error"; REASON="the result could not be recorded: $1"
  UNRECORDED="$1"
  if ! { printf '%s\t%s\t%s\n' "$SID" "$FILE_PATH" "$(date +%s)" >>"$STATE_DIR/quality-gate-unrecorded"; } 2>/dev/null; then
    if marker=$(note_marker); then
      UNRECORDED="$UNRECORDED; noted in $marker"
    else
      UNRECORDED="$UNRECORDED; it could not be noted in $marker either"
    fi
  fi
  EXIT_RC=2
}

# State lives in the project the file belongs to (lib/roots.sh). If it can't be
# written there, no check result can count.
if ! mkdir -p "$STATE_DIR" 2>/dev/null || [ ! -w "$STATE_DIR" ]; then
  cannot_record "$STATE_DIR is not writable"
elif [ ! -f "$STATE_DIR/.gitignore" ]; then
  # Self-gitignore: state is transient, never commit
  { printf '*\n!.gitignore\n' >"$STATE_DIR/.gitignore"; } 2>/dev/null || true
fi

# A result stored in another worktree than the session's project (an edit by
# absolute path into ../feature-wt) is still this session's: note that worktree in
# the project's .hook-state/quality-gate-roots, where stop-gate.sh looks.
note_root() {
  local roots="$SESSION_DIR/.hook-state/quality-gate-roots" marker
  if [ -f "$roots" ] && grep -qF -- "$SID$TAB$PROJECT_ROOT$TAB" "$roots" 2>/dev/null; then
    return 0
  fi
  if { mkdir -p "$SESSION_DIR/.hook-state" \
       && printf '%s\t%s\t%s\n' "$SID" "$PROJECT_ROOT" "$(date +%s)" >>"$roots"; } 2>/dev/null; then
    [ -f "$SESSION_DIR/.hook-state/.gitignore" ] \
      || { printf '*\n!.gitignore\n' >"$SESSION_DIR/.hook-state/.gitignore"; } 2>/dev/null || true
    return 0
  fi
  if marker=$(note_marker); then
    return 0
  fi
  cannot_record "$SESSION_DIR/.hook-state is not writable, so this worktree's result can't be found at stop"
}
if [ -z "$UNRECORDED" ] && [ "$PROJECT_ROOT" != "$SESSION_DIR" ]; then
  note_root
fi

# Hard time limit per check (lib/run-with-timeout.sh): past it the check's whole
# process group is killed and the run is recorded as "timeout", not "failed".
GATE_TIMEOUT="${CCK_QUALITY_GATE_TIMEOUT:-30}"
case "$GATE_TIMEOUT" in ''|*[!0-9]*|0) GATE_TIMEOUT=30 ;; esac

# run_check NAME KIND SCOPE_DIR CMD [ARGS...]
#   KIND "file":  the check covers this file only (ruff, py_compile, bash -n).
#   KIND "scope": it covers SCOPE_DIR as a whole (tsc, cargo check, go vet <pkg>,
#                 a declared command), so a pass re-covers every file under it.
# Capture output and exit code without using `|| true` (which would always
# yield exit 0 and falsely report "passed"). The output goes to a file, not a
# pipe: a process the check leaves behind could hold a pipe open and keep the
# hook waiting past any time limit.
run_check() {
  TOOL_USED="$1"; SCOPE_KIND="$2"; SCOPE_DIR="$3"; shift 3
  local err
  # stop-gate.sh caps a re-verification by what is left of its time budget.
  case "${CCK_GATE_TIMEOUT_CAP:-}" in
    ''|*[!0-9]*|0) ;;
    *) if [ "$GATE_TIMEOUT" -gt "$CCK_GATE_TIMEOUT_CAP" ]; then GATE_TIMEOUT="$CCK_GATE_TIMEOUT_CAP"; CAPPED=1; fi ;;
  esac
  if python3_usable; then
    if ! RUN_ID=$(gate_state_start "$STATE_V2" "$FILE_PATH" "$SCOPE_DIR :: $TOOL_USED" "$SCOPE_KIND" "$TOOL_USED" "$SID"); then
      START_ERR="$RUN_ID"; RUN_ID=""
    fi
  else
    # Stamped before the check runs, so an edit during it doesn't count as checked.
    STAMP=$(gate_file_stamp "$FILE_PATH")
    tsv_append running "$STAMP" || START_ERR="can't write $FILES_TSV"
  fi
  if ! err=$( { : >"$OUT_FILE"; } 2>&1 ); then
    START_ERR="can't write $OUT_FILE (${err##*: })"
    return 0
  fi
  # Run it in the background and wait, so a signal reaches on_signal at once.
  trap 'on_signal 15' TERM
  trap 'on_signal 2' INT
  trap 'on_signal 1' HUP
  set +e
  run_with_timeout "$GATE_TIMEOUT" "$@" >"$OUT_FILE" 2>&1 &
  CHECK_PID=$!
  wait "$CHECK_PID"
  EXIT_CODE=$?
  set -e
  CHECK_PID=""
  trap - TERM INT HUP
  OUT=""
  if [ -f "$OUT_FILE" ]; then
    OUT=$(<"$OUT_FILE")
    rm -f "$OUT_FILE"
  fi
  case "$EXIT_CODE" in
    0)   STATUS="passed" ;;
    124) STATUS="timeout"; REASON="killed after ${GATE_TIMEOUT}s" ;;
    126) STATUS="error";   REASON="command not executable" ;;
    127) STATUS="error";   REASON="command not found" ;;
    *)   STATUS="failed" ;;
  esac
  STDERR_TAIL=$(printf '%s' "$OUT" | tail -c 2000)
  if [ "$STATUS" = "timeout" ] && [ -n "$CAPPED" ]; then
    REASON="$REASON (all that was left of the stop-gate re-verification budget)"
  fi
}

# skip CODE DETAIL — no check applies to this file. Recorded, never "passed".
skip() { STATUS="skipped"; REASON="$1: $2"; }

# tsv_append STATUS STAMP — one line in quality-gate-files.tsv, the per-file log
# kept without a usable python3 (format: lib/gate-state.sh). No field is empty.
tsv_append() {
  local detail="$TOOL_USED${REASON:+ ($REASON)}"
  detail="${detail//$TAB/ }"
  detail="${detail//$NL/ }"
  { printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$SID" "$FILE_PATH" "$1" "${2:--}" "$SCOPE_KIND" \
      "$SCOPE_DIR :: ${TOOL_USED:--}" "$(date +%s)" "${detail:--}" >>"$FILES_TSV"; } 2>/dev/null
}

# A hook killed mid-check (a SIGTERM from Claude Code, Ctrl-C) ends its check and
# leaves no output file behind. The run stays marked "running", so stop-gate.sh
# re-verifies the file.
on_signal() {
  if [ -n "$CHECK_PID" ]; then
    kill -TERM "$CHECK_PID" 2>/dev/null || true
  fi
  rm -f "$OUT_FILE" 2>/dev/null || true
  exit $((128 + $1))
}

# .claude/commands.json says how to check THIS project. A file outside it
# (../sibling/util.py) is checked as if nothing were declared: a declared command
# runs over the project, never over that file. Compared as physical paths, so
# `..` and symlinks can't move a file in or out.
IN_PROJECT=0
FILE_DIR_P=$(cd "$(dirname "$FILE_PATH")" 2>/dev/null && pwd -P) || FILE_DIR_P=""
PROJECT_P=$(cd "$PROJECT_ROOT" 2>/dev/null && pwd -P) || PROJECT_P=""
if [ -n "$FILE_DIR_P" ] && [ -n "$PROJECT_P" ]; then
  case "$FILE_DIR_P/" in "$PROJECT_P"/*) IN_PROJECT=1 ;; esac
fi

CONFIG_ERROR=""
if [ "$IN_PROJECT" = 1 ]; then
  CONFIG_ERROR=$(project_commands_error "$PROJECT_ROOT")
fi
if [ -n "$UNRECORDED" ]; then
  :  # nothing can be recorded — don't run a check whose result would be lost
elif [ -n "$CONFIG_ERROR" ]; then
  # A broken commands.json is a config error, not "nothing declared": falling
  # back to auto-detection would silently run a different check than declared.
  TOOL_USED=".claude/commands.json"; SCOPE_KIND="config"; SCOPE_DIR="$PROJECT_ROOT"
  STATUS="error"; REASON="${CONFIG_ERROR#.claude/commands.json: }"; EXIT_CODE=1
else
  # Single source of truth: if the project declares its commands in
  # .claude/commands.json (at the project root, NOT the walk-up ROOT), prefer the
  # declared typecheck/lint over the per-language guess below — so the gate runs
  # the SAME check the project documents. One check per edit: typecheck wins for
  # typed languages, else lint. Declared commands run from the project root.
  # An absent key → auto-detect below; a key set to "" → the project has no such
  # check, so the edit is recorded as skipped (NOT verified) rather than guessed.
  DECL_KEYS=""
  case "$EXT" in
    ts|tsx|mts|cts|cs|csproj|sln|slnx|props|targets|razor|cshtml) DECL_KEYS="typecheck lint" ;;
    js|jsx|mjs|cjs|py|go|rs) DECL_KEYS="lint" ;;
  esac
  DECL="auto"
  if [ -n "$DECL_KEYS" ] && [ "$IN_PROJECT" = 1 ]; then
    # shellcheck disable=SC2086  # DECL_KEYS is a fixed word list
    DECL=$(project_check_command "$PROJECT_ROOT" $DECL_KEYS)
  fi
  TAB=$'\t'
  DECL_KIND="${DECL%%"$TAB"*}"
  DECL_VALUE=""
  case "$DECL" in *"$TAB"*) DECL_VALUE="${DECL#*"$TAB"}" ;; esac

  # A declared timeout sets the per-check limit; the env var still wins.
  DECL_TIMEOUT=""
  if [ "$IN_PROJECT" = 1 ]; then
    DECL_TIMEOUT=$(project_commands_timeout "$PROJECT_ROOT")
  fi
  if [ -z "${CCK_QUALITY_GATE_TIMEOUT:-}" ] && [ -n "$DECL_TIMEOUT" ]; then
    GATE_TIMEOUT="$DECL_TIMEOUT"
  fi

  if [ "$DECL_KIND" = "run" ]; then
    run_check "$DECL_VALUE" scope "$PROJECT_ROOT" sh -c "cd \"$PROJECT_ROOT\" && $DECL_VALUE"
  elif [ "$DECL_KIND" = "off" ]; then
    skip "disabled" "commands.json sets $DECL_VALUE to \"\""
  else
    case "$EXT" in
      ts|tsx|mts|cts)
        if [ -f "$ROOT/tsconfig.json" ]; then
          # `cd` and `npx` chained via sh -c so the timeout wraps the actual tool.
          run_check "tsc --noEmit" scope "$ROOT" sh -c "cd \"$ROOT\" && npx --no-install tsc --noEmit"
        else
          skip "no-config" "no tsconfig.json in $ROOT"
        fi
        ;;
      js|jsx|mjs|cjs)
        if [ -f "$ROOT/package.json" ] && grep -q '"lint"' "$ROOT/package.json" 2>/dev/null; then
          run_check "npm run lint" scope "$ROOT" sh -c "cd \"$ROOT\" && npm run lint --silent"
        else
          skip "no-config" "no \"lint\" script in $ROOT/package.json"
        fi
        ;;
      py)
        if command -v ruff &>/dev/null; then
          run_check "ruff check" file "$FILE_PATH" ruff check "$FILE_PATH"
        elif python3_usable; then
          run_check "python3 -m py_compile" file "$FILE_PATH" python3 -m py_compile "$FILE_PATH"
        else
          skip "tool-unavailable" "neither ruff nor a working python3 is installed"
        fi
        ;;
      go)
        if command -v go &>/dev/null; then
          PKG_DIR=$(dirname "$FILE_PATH")
          # Portable relative path: strip ROOT prefix. Fall back to "..." if outside.
          REL_PKG="${PKG_DIR#"$ROOT"/}"
          if [ "$REL_PKG" = "$PKG_DIR" ] || [ -z "$REL_PKG" ]; then
            REL_PKG="..."  # outside ROOT or equals ROOT — vet everything
          fi
          run_check "go vet ./$REL_PKG" scope "$ROOT/$REL_PKG" sh -c "cd \"$ROOT\" && go vet \"./$REL_PKG\""
        else
          skip "tool-unavailable" "go is not installed"
        fi
        ;;
      rs)
        if command -v cargo &>/dev/null; then
          run_check "cargo check" scope "$ROOT" sh -c "cd \"$ROOT\" && cargo check --quiet"
        else
          skip "tool-unavailable" "cargo is not installed"
        fi
        ;;
      cs|csproj|sln|slnx|props|targets|razor|cshtml)
        # Build the nearest project: the edited .csproj/.sln itself, else the
        # *.csproj (or *.sln, for solution-level files) in ROOT — package_root
        # stops at the directory holding one.
        DOTNET_TARGET=""
        case "$EXT" in csproj|sln|slnx) DOTNET_TARGET="$FILE_PATH" ;; esac
        if [ -z "$DOTNET_TARGET" ]; then
          for f in "$ROOT"/*.csproj "$ROOT"/*.sln "$ROOT"/*.slnx; do
            if [ -f "$f" ]; then
              DOTNET_TARGET="$f"
              break
            fi
          done
        fi
        if ! command -v dotnet &>/dev/null; then
          skip "tool-unavailable" "dotnet is not installed"
        elif [ -z "$DOTNET_TARGET" ]; then
          skip "no-config" "no .csproj or .sln found for $BASENAME"
        else
          # A cold build is slow: unless a limit was set (env or commands.json), allow 120s.
          [ -n "${CCK_QUALITY_GATE_TIMEOUT:-}" ] || [ -n "$DECL_TIMEOUT" ] || GATE_TIMEOUT=120
          DOTNET_DIR=$(dirname "$DOTNET_TARGET")
          DOTNET_ARGS="-nologo -v q"
          # --no-restore only once restored: on a fresh clone it fails with a
          # misleading "assets file not found" instead of building.
          [ -f "$DOTNET_DIR/obj/project.assets.json" ] && DOTNET_ARGS="$DOTNET_ARGS --no-restore"
          run_check "dotnet build $(basename "$DOTNET_TARGET")" scope "$DOTNET_TARGET" \
            sh -c "cd \"$DOTNET_DIR\" && dotnet build \"$(basename "$DOTNET_TARGET")\" $DOTNET_ARGS"
        fi
        ;;
      sh|bash)
        run_check "bash -n" file "$FILE_PATH" bash -n "$FILE_PATH"
        ;;
      *)
        skip "unsupported-language" "no check for .$EXT files"
        ;;
    esac
  fi
fi

END=$(date +%s)
DURATION=$((END - START))

# The gate state couldn't be marked before the check (unreadable, locked,
# unwritable, a full disk): its result can't be trusted to land.
if [ -n "$START_ERR" ]; then
  cannot_record "$START_ERR"
fi

# Update quality-gate history (cumulative runs/failures per session) — only for
# runs that executed a check. Session-end aggregates this into the scorecard.
# Atomic via temp-file rename.
HISTORY_FILE="$STATE_DIR/quality-gate-history.json"
if [ "$STATUS" != "skipped" ] && python3_usable; then
  python3 - "$HISTORY_FILE" "$STATUS" "$TOOL_USED" <<'PY' 2>/dev/null || true
import json, os, sys
f, status, tool = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(f) as fh:
        d = json.load(fh)
    if not isinstance(d, dict):
        d = {}
except (FileNotFoundError, json.JSONDecodeError):
    d = {}
d["runs"] = int(d.get("runs", 0)) + 1
if status in ("failed", "timeout", "error"):
    d["failures"] = int(d.get("failures", 0)) + 1
elif "failures" not in d:
    d["failures"] = 0
d["last_status"] = status
d["last_tool"] = tool
d.setdefault("skip_gate_used", 0)  # stop-gate.sh sets this to 1 on bypass
tmp = f + ".tmp"
with open(tmp, "w") as fh:
    json.dump(d, fh, indent=2)
os.replace(tmp, f)
PY
fi

# Append this edit to the verification ledger — append-only evidence of WHAT
# actually ran (tool, outcome, file, time), or that nothing could (skipped, with
# the reason), capped at the last 50 entries. The manual slots CLAUDE.md mandates
# but a hook can't judge (smoke_test, silent_failures, coverage) are filled by
# the agent via /verification-status.
LEDGER_FILE="$STATE_DIR/verification-ledger.json"
NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")
if python3_usable; then
  python3 - "$LEDGER_FILE" "$NOW_ISO" "$TOOL_USED" "$STATUS" "$EXIT_CODE" "$FILE_PATH" "$DURATION" "$REASON" "$SCOPE_DIR" <<'PY' 2>/dev/null || true
import json, os, sys
f, at, tool, status, exit_code, edited, duration, reason, scope = sys.argv[1:]
try:
    with open(f) as fh:
        d = json.load(fh)
    if not isinstance(d, dict):
        d = {}
except (FileNotFoundError, json.JSONDecodeError):
    d = {}
d.setdefault("schema_version", 1)
d.setdefault("entries", [])
d.setdefault("smoke_test", None)
d.setdefault("silent_failures", None)
d.setdefault("coverage", None)
entry = {
    "at": at, "tool": tool, "status": status,
    "exit_code": int(exit_code), "file": edited, "duration_s": int(duration),
}
if reason:
    entry["reason"] = reason
if status != "skipped":
    entry["scope"] = scope
d["entries"].append(entry)
d["entries"] = d["entries"][-50:]
tmp = f + ".tmp"
with open(tmp, "w") as fh:
    json.dump(d, fh, indent=2)
os.replace(tmp, f)
PY
fi

# Record the result per file, rewrite the summary, and tell Claude what it needs
# to know (additionalContext on stdout). Without a usable python3 the result goes
# to the plain per-file log, and a summary is written for older readers.
if [ -n "$UNRECORDED" ] && [ ! -w "$STATE_DIR" ]; then
  :  # nothing can be written there
elif python3_usable; then
  gate_state_finish "$STATE_V2" "$STATE_FILE" "$RUN_ID" "$FILE_PATH" "$SCOPE_DIR :: $TOOL_USED" "$SCOPE_KIND" \
    "$TOOL_USED" "$STATUS" "$EXIT_CODE" "$REASON" "$DURATION" "$STDERR_TAIL" "$SID" || GS_RC=$?
  if [ "$GS_RC" = 2 ]; then
    if [ -z "$UNRECORDED" ]; then
      cannot_record "$GATE_STATE_ERR"
    fi
  elif [ -f "$FILES_TSV" ]; then
    # This file's latest result is in the state now, not in the plain log.
    tsv_append v2 "-" || true
  fi
else
  if [ "$STATUS" = "skipped" ]; then
    STAMP=$(gate_file_stamp "$FILE_PATH")
  fi
  if ! tsv_append "$STATUS" "${STAMP:--}" && [ -z "$UNRECORDED" ]; then
    cannot_record "can't write $FILES_TSV"
  fi
  # What Claude needs to hear, as the python3 path would say it.
  MSG=""
  if [ "$STATUS" = "failed" ] || [ "$STATUS" = "timeout" ] || [ "$STATUS" = "error" ]; then
    MSG="Quality gate $STATUS for $FILE_PATH: $TOOL_USED${REASON:+ ($REASON)}. ${STDERR_TAIL:+$STDERR_TAIL }stop-gate.sh blocks completion until this file's check passes."
  elif [ "$STATUS" = "skipped" ]; then
    MSG="$FILE_PATH is NOT verified by the quality gate: $REASON. Nothing checked this file; verify it another way (tests, a build, running it) before calling the task done."
  fi
  if [ -n "$MSG" ] && [ -z "$UNRECORDED" ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$(json_str "$MSG")"
  fi
fi
if { ! python3_usable || [ "$GS_RC" != 0 ] || [ -n "$UNRECORDED" ]; } && [ "$STATUS" != "skipped" ]; then
  # Bash fallback summary
  { cat >"$STATE_FILE" <<EOF
{
  "status": "$STATUS",
  "session_id": "$(json_str "$SID")",
  "exit_code": $EXIT_CODE,
  "tool": "$(json_str "$TOOL_USED")",
  "edited_file": "$(json_str "$FILE_PATH")",
  "duration_seconds": $DURATION,
  "reason": "$(json_str "$REASON")",
  "stderr_tail": "$(json_str "$STDERR_TAIL")"
}
EOF
  } 2>/dev/null || true
fi

if [ "$EXIT_RC" = 2 ]; then
  cat >&2 <<EOF
Quality gate ERROR: the result for $FILE_PATH could not be recorded: $UNRECORDED.
stop-gate.sh blocks completion until a check of this file is recorded. Fix the cause
(free disk space, make $STATE_DIR writable, or reset an unreadable state by
deleting quality-gate-state.json and last_quality_gate.json there), then save the
file again.
EOF
  exit 2
fi

# Debug-log trail (stderr at exit 0 never reaches Claude — additionalContext does).
case "$STATUS" in
  failed)
    echo "Quality gate FAILED ($TOOL_USED, ${DURATION}s). See $STATE_FILE." >&2
    echo "Completion will be blocked by stop-gate.sh until this is fixed." >&2
    ;;
  timeout)
    echo "Quality gate TIMED OUT ($TOOL_USED): killed after ${GATE_TIMEOUT}s. See $STATE_FILE." >&2
    echo "Completion will be blocked by stop-gate.sh. If the check is legitimately slow, raise CCK_QUALITY_GATE_TIMEOUT." >&2
    ;;
  error)
    echo "Quality gate ERROR ($TOOL_USED): $REASON. See $STATE_FILE." >&2
    ;;
esac

exit 0
