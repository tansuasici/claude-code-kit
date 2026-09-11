#!/usr/bin/env bash
#
# quality-gate.sh — PostToolUse hook
#
# After a file edit, runs a fast verification command appropriate to the
# project type (typecheck, lint, or syntax-check) and records the result per
# file in `.hook-state/quality-gate-state.json` (lib/gate-state.sh), with
# `.hook-state/last_quality_gate.json` as the summary. stop-gate.sh reads them
# to decide whether the agent is allowed to finish the turn.
#
# Does NOT block (always exits 0). Blocking happens in stop-gate.sh based
# on the persisted state — this separation matches Nader Dabit's "Agent
# Hooks: Deterministic Control" model and avoids tying every edit to a
# block decision. What Claude needs to hear now — a failed check, a file no
# check covers — goes out as PostToolUse additionalContext on stdout: stderr
# from a hook that exits 0 only reaches the debug log.
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
#   declared checks must run against the worktree's copy of the code.
ROOT=$(package_root "$FILE_PATH")
[ -z "$ROOT" ] && exit 0  # no project root → nothing to gate
PROJECT_ROOT=$(hook_project_root "$FILE_PATH")
STATE_DIR="$PROJECT_ROOT/.hook-state"
mkdir -p "$STATE_DIR"
# Self-gitignore: state is transient, never commit
[ -f "$STATE_DIR/.gitignore" ] || printf '*\n!.gitignore\n' >"$STATE_DIR/.gitignore"
STATE_V2="$STATE_DIR/quality-gate-state.json"
STATE_FILE="$STATE_DIR/last_quality_gate.json"

START=$(date +%s)
TOOL_USED=""
STATUS="skipped"
REASON=""
SCOPE_KIND="file"
SCOPE_DIR="$FILE_PATH"
EXIT_CODE=0
STDERR_TAIL=""
OUT=""

# Hard time limit per check (lib/run-with-timeout.sh): past it the check's whole
# process group is killed and the run is recorded as "timeout", not "failed".
GATE_TIMEOUT="${CCK_QUALITY_GATE_TIMEOUT:-30}"
case "$GATE_TIMEOUT" in ''|*[!0-9]*|0) GATE_TIMEOUT=30 ;; esac

# run_check NAME KIND SCOPE_DIR CMD [ARGS...]
#   KIND "file":  the check covers this file only (ruff, py_compile, bash -n).
#   KIND "scope": it covers SCOPE_DIR as a whole (tsc, cargo check, go vet <pkg>,
#                 a declared command), so a pass re-covers every file under it.
# Capture output and exit code without using `|| true` (which would always
# yield exit 0 and falsely report "passed").
run_check() {
  TOOL_USED="$1"; SCOPE_KIND="$2"; SCOPE_DIR="$3"; shift 3
  gate_state_start "$STATE_V2" "$FILE_PATH" "$SCOPE_DIR :: $TOOL_USED" "$SCOPE_KIND" "$TOOL_USED"
  set +e
  OUT=$(run_with_timeout "$GATE_TIMEOUT" "$@" 2>&1)
  EXIT_CODE=$?
  set -e
  case "$EXIT_CODE" in
    0)   STATUS="passed" ;;
    124) STATUS="timeout"; REASON="killed after ${GATE_TIMEOUT}s" ;;
    126) STATUS="error";   REASON="command not executable" ;;
    127) STATUS="error";   REASON="command not found" ;;
    *)   STATUS="failed" ;;
  esac
  STDERR_TAIL=$(printf '%s' "$OUT" | tail -c 2000)
}

# skip CODE DETAIL — no check applies to this file. Recorded, never "passed".
skip() { STATUS="skipped"; REASON="$1: $2"; }

CONFIG_ERROR=$(project_commands_error "$PROJECT_ROOT")
if [ -n "$CONFIG_ERROR" ]; then
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
  if [ -n "$DECL_KEYS" ]; then
    # shellcheck disable=SC2086  # DECL_KEYS is a fixed word list
    DECL=$(project_check_command "$PROJECT_ROOT" $DECL_KEYS)
  fi
  TAB=$'\t'
  DECL_KIND="${DECL%%"$TAB"*}"
  DECL_VALUE=""
  case "$DECL" in *"$TAB"*) DECL_VALUE="${DECL#*"$TAB"}" ;; esac

  # A declared timeout sets the per-check limit; the env var still wins.
  DECL_TIMEOUT=$(project_commands_timeout "$PROJECT_ROOT")
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
        elif command -v python3 &>/dev/null; then
          run_check "python3 -m py_compile" file "$FILE_PATH" python3 -m py_compile "$FILE_PATH"
        else
          skip "tool-unavailable" "neither ruff nor python3 is installed"
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

# Update quality-gate history (cumulative runs/failures per session) — only for
# runs that executed a check. Session-end aggregates this into the scorecard.
# Atomic via temp-file rename.
HISTORY_FILE="$STATE_DIR/quality-gate-history.json"
if [ "$STATUS" != "skipped" ] && command -v python3 &>/dev/null; then
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
if command -v python3 &>/dev/null; then
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
# to know (additionalContext on stdout). Without python3 only the summary is kept.
if ! gate_state_finish "$STATE_V2" "$STATE_FILE" "$FILE_PATH" "$SCOPE_DIR :: $TOOL_USED" "$SCOPE_KIND" "$TOOL_USED" \
     "$STATUS" "$EXIT_CODE" "$REASON" "$DURATION" "$STDERR_TAIL"; then
  if [ "$STATUS" != "skipped" ]; then
    # Bash fallback — escape minimally
    ESC_STDERR=$(printf '%s' "$STDERR_TAIL" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
    cat >"$STATE_FILE" <<EOF
{
  "status": "$STATUS",
  "exit_code": $EXIT_CODE,
  "tool": "$TOOL_USED",
  "edited_file": "$FILE_PATH",
  "duration_seconds": $DURATION,
  "stderr_tail": "$ESC_STDERR"
}
EOF
  fi
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
