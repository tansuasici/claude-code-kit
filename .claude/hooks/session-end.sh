#!/usr/bin/env bash
#
# session-end.sh — SessionEnd hook
#
# Appends a JSON-line audit record to reports/session-audit.log. As of
# schema_version 2 the record is a structured session scorecard with metrics
# aggregated from the session's .hook-state/* files plus the transcript:
#
#   - blocks_fired           — counts per blocking hook (hook-firings.json)
#   - quality_gate           — runs / failures / last_status / skip_gate_used
#   - bash_token_estimate    — cumulative Bash output cost (bash-budget.json)
#   - edits                  — count of Edit/Write/NotebookEdit/MultiEdit calls (from transcript)
#   - compactions_observed   — best-effort compaction detection (from transcript)
#   - lessons_added          — new files in tasks/lessons/ since session_start
#   - decisions_added        — tasks/decisions.md modified since session_start (0/1)
#   - session_duration_seconds — now - session-meta.json.started_at
#
# All top-level v1 fields (timestamp, event, session_id, reason,
# transcript_path, last_quality_gate) are preserved verbatim so v1 parsers
# continue to work.
#

set -euo pipefail

INPUT=$(cat)

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
REPORTS_DIR="$ROOT/reports"
mkdir -p "$REPORTS_DIR"
# Self-gitignore: audit logs are transient and machine-local
[ -f "$REPORTS_DIR/.gitignore" ] || printf 'session-audit.log\n' >"$REPORTS_DIR/.gitignore"
LOG="$REPORTS_DIR/session-audit.log"

STATE_DIR="$ROOT/.hook-state"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
NOW_EPOCH=$(date +%s)

# python3 is required for the rich aggregation path. Without it, fall back to
# the v1 single-line shape so legacy installs keep getting some signal.
if ! command -v python3 >/dev/null 2>&1; then
  GATE_STATUS="none"
  STATE_FILE="$STATE_DIR/last_quality_gate.json"
  if [ -f "$STATE_FILE" ]; then
    GATE_STATUS=$(grep -oE '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' || echo "none")
  fi
  SESSION_ID=$(printf '%s' "$INPUT" | grep -oE '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')
  REASON=$(printf '%s' "$INPUT" | grep -oE '"reason"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')
  TRANSCRIPT=$(printf '%s' "$INPUT" | grep -oE '"transcript_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')
  printf '{"timestamp":"%s","event":"SessionEnd","schema_version":1,"session_id":"%s","reason":"%s","transcript_path":"%s","last_quality_gate":"%s"}\n' \
    "$TS" "${SESSION_ID:-}" "${REASON:-unknown}" "${TRANSCRIPT:-}" "$GATE_STATUS" >>"$LOG"
  exit 0
fi

# Rich path: python3 aggregates state + transcript and writes one JSON line.
printf '%s' "$INPUT" | python3 - "$TS" "$NOW_EPOCH" "$STATE_DIR" "$ROOT" >>"$LOG" <<'PY'
import json, os, sys

ts = sys.argv[1]
now_epoch = int(sys.argv[2])
state_dir = sys.argv[3]
root = sys.argv[4]

# --- Inbound stop-hook payload (session_id, reason, transcript_path) ------
try:
    payload = json.load(sys.stdin)
except Exception:
    payload = {}
session_id = payload.get("session_id", "") or ""
reason = payload.get("reason", "unknown") or "unknown"
transcript_path = payload.get("transcript_path", "") or ""

# --- Load each state file with graceful absence ---------------------------
def load_json(path):
    try:
        with open(path) as f:
            d = json.load(f)
        return d if isinstance(d, dict) else {}
    except (FileNotFoundError, json.JSONDecodeError):
        return {}

last_gate = load_json(os.path.join(state_dir, "last_quality_gate.json"))
hook_firings = load_json(os.path.join(state_dir, "hook-firings.json"))
gate_history = load_json(os.path.join(state_dir, "quality-gate-history.json"))
bash_budget = load_json(os.path.join(state_dir, "bash-budget.json"))
read_budget = load_json(os.path.join(state_dir, "read-budget.json"))
session_meta = load_json(os.path.join(state_dir, "session-meta.json"))

# --- Derived metrics ------------------------------------------------------
KNOWN_BLOCKING_HOOKS = (
    "protect-files",
    "protect-changes",
    "branch-protect",
    "block-dangerous-commands",
    "stop-gate",
)
blocks_fired = {h: int(hook_firings.get(h, 0)) for h in KNOWN_BLOCKING_HOOKS}

quality_gate = {
    "runs": int(gate_history.get("runs", 0)),
    "failures": int(gate_history.get("failures", 0)),
    "last_status": gate_history.get("last_status") or last_gate.get("status") or "none",
    "skip_gate_used": int(gate_history.get("skip_gate_used", 0)) > 0,
}

bash_token_estimate = int(bash_budget.get("cumulative_tokens", 0))
read_token_estimate = int(read_budget.get("cumulative_tokens", 0))

# session_duration: prefer started_at_epoch from session-meta; fall back to None.
started_epoch = session_meta.get("started_at_epoch")
if isinstance(started_epoch, int):
    duration = max(0, now_epoch - started_epoch)
else:
    duration = None

# --- Best-effort transcript parse (edits + compactions) -------------------
# Transcript format is a stream of events serialized as JSON; the kit doesn't
# control it, so be conservative: count events whose tool name matches the
# editing tools, and events whose payload mentions a compaction marker.
edits = 0
compactions_observed = 0
if transcript_path and os.path.isfile(transcript_path):
    try:
        with open(transcript_path, encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line.startswith("{"):
                    continue
                try:
                    ev = json.loads(line)
                except Exception:
                    continue
                # tool-use event with editing tool name
                name = None
                if isinstance(ev, dict):
                    if ev.get("type") == "tool_use":
                        name = ev.get("name")
                    msg = ev.get("message") or {}
                    if isinstance(msg, dict):
                        content = msg.get("content") or []
                        if isinstance(content, list):
                            for c in content:
                                if isinstance(c, dict) and c.get("type") == "tool_use":
                                    if c.get("name") in ("Edit", "Write", "NotebookEdit", "MultiEdit"):
                                        edits += 1
                    if name in ("Edit", "Write", "NotebookEdit", "MultiEdit"):
                        edits += 1
                    # compaction marker — kit doesn't control the wire format,
                    # but "compact" inside an event type or message hint is a
                    # strong signal. False positives are acceptable here.
                    blob = json.dumps(ev)
                    if "compact_summary" in blob or '"type": "compaction"' in blob:
                        compactions_observed += 1
    except Exception:
        pass

# --- Lessons + decisions modified since session_start --------------------
lessons_added = 0
decisions_added = 0
if isinstance(started_epoch, int):
    lessons_dir = os.path.join(root, "tasks", "lessons")
    if os.path.isdir(lessons_dir):
        for entry in os.listdir(lessons_dir):
            if not entry.endswith(".md") or entry in ("_index.md", "_TEMPLATE.md"):
                continue
            full = os.path.join(lessons_dir, entry)
            try:
                if os.path.getmtime(full) >= started_epoch:
                    lessons_added += 1
            except OSError:
                continue
    decisions_path = os.path.join(root, "tasks", "decisions.md")
    if os.path.isfile(decisions_path):
        try:
            if os.path.getmtime(decisions_path) >= started_epoch:
                decisions_added = 1
        except OSError:
            pass

# --- Lesson-candidate detector -------------------------------------------
# If the session hit learnable signals (quality-gate failures, or journaled
# findings/decisions) but captured no lesson, leave a one-shot breadcrumb for the
# NEXT session's start to nudge /skill-extractor. DETECT only — a hook can't judge
# whether something is a generalizable lesson, so it never writes one.
journal_findings = 0
journal_path = os.path.join(state_dir, "session-journal.md")
if os.path.isfile(journal_path):
    try:
        with open(journal_path, encoding="utf-8", errors="replace") as jf:
            for ln in jf:
                s = ln.strip()
                if s.startswith("[finding]") or s.startswith("[decision]"):
                    journal_findings += 1
    except OSError:
        pass
learnable = (quality_gate["failures"] > 0 or journal_findings > 0) and lessons_added == 0
breadcrumb = os.path.join(state_dir, "lesson-candidate.json")
try:
    if learnable:
        with open(breadcrumb + ".tmp", "w") as bf:
            json.dump({"at": ts, "gate_failures": quality_gate["failures"],
                       "journal_findings": journal_findings}, bf)
        os.replace(breadcrumb + ".tmp", breadcrumb)
    elif os.path.exists(breadcrumb):
        os.remove(breadcrumb)  # nothing learnable → clear any stale breadcrumb
except OSError:
    pass

# --- Emit one JSON line --------------------------------------------------
record = {
    "timestamp": ts,
    "event": "SessionEnd",
    "schema_version": 2,
    "session_id": session_id,
    "reason": reason,
    "transcript_path": transcript_path,
    "last_quality_gate": quality_gate["last_status"],
    "metrics": {
        "edits": edits,
        "blocks_fired": blocks_fired,
        "quality_gate": quality_gate,
        "lessons_added": lessons_added,
        "decisions_added": decisions_added,
        "bash_token_estimate": bash_token_estimate,
        "read_token_estimate": read_token_estimate,
        "compactions_observed": compactions_observed,
        "session_duration_seconds": duration,
    },
}
sys.stdout.write(json.dumps(record) + "\n")
PY

exit 0
