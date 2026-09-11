#!/usr/bin/env bash
#
# gate-state.sh — per-file quality-gate results (.hook-state/quality-gate-state.json)
#
# Source it:  source "$HOOK_LIB/gate-state.sh"
#
# The gate used to keep a single record, the last run: a pass on b.py closed a
# failure on a.py, a skipped check left an older pass standing for code nothing
# checked, and a pass never went stale. This keeps a record per edited file:
#
#   runs[<scope>]  latest result of each check scope — a per-file check (ruff,
#                  py_compile, bash -n) or a scope-wide one (tsc, cargo check,
#                  go vet <pkg>, a declared command):
#                  {command, kind, status, exit_code, reason, at, duration_s, started}
#   files[<path>]  {scope, hash, at, sessions}: the scope that last checked the
#                  file, the file's sha256 as that check saw it, and the sessions
#                  that edited it — or {status: "skipped", reason, sessions} when
#                  no check applies to it
#   seq, pending   run numbers, and each in-flight run's snapshot of the files
#                  its scope tracks, hashed when it started
#
# A file is verified only while its scope's latest run passed AND its content
# still hashes the same. A passing scope-wide run re-covers the files in scope
# that are unchanged since it started — never content it did not see. A run that
# finishes after a later run of the same scope started records nothing: the later
# run's result stands. A scope-wide failure whose files were all renamed or
# deleted still blocks (an "orphan" scope) until the scope runs again.
#
# Results are per session: a stop answers for the files its own session edited
# (records with no session, or a stop with none, count everywhere — fail closed).
#
# Every load-modify-save holds an exclusive lock (<state>.lock) and writes through
# a unique temp file renamed into place, so concurrent hooks don't lose records.
# A state file that exists but can't be read is an error, never an empty state.
#
#   gate_state_start  <state> <file> <scope> <kind> <command> <session>
#       Mark a check in flight and print its run number. A hook killed mid-check
#       leaves "running", which stop-gate.sh treats as stale and re-verifies.
#       On failure prints the reason instead and returns 1.
#   gate_state_finish <state> <summary> <run> <file> <scope> <kind> <command>
#                     <status> <exit_code> <reason> <duration_s> <stderr_tail> <session>
#       Record the result, rewrite the summary (last_quality_gate.json) and print
#       PostToolUse additionalContext JSON when Claude should hear about it.
#       <run> is start's run number, or "" when no check was started. Returns 1
#       without a usable python3 (the caller keeps its own log), 2 when the
#       result could not be recorded (reason in GATE_STATE_ERR).
#   gate_state_lines  <state> <config_ok 0|1> <session> [unrecorded-file...]
#       One line per file of <session> that is not verified, tab-separated, "-"
#       for an empty field:
#         block<TAB>status<TAB>file<TAB>command<TAB>reason
#         stale<TAB>file<TAB>scope<TAB>command
#         unverified<TAB>file<TAB>reason
#         orphan<TAB>status<TAB>scope<TAB>command
#         unrecorded<TAB>file      (an unrecorded-file argument with no record here)
#       On failure — an unreadable state included — prints error<TAB>reason and
#       returns 1; callers must treat that as blocking.
#   gate_state_prune  <state> <days>    Drop records older than <days>.
#
# Without a usable python3, quality-gate.sh keeps a plain per-file log instead,
# .hook-state/quality-gate-files.tsv, one line per run:
#   session<TAB>file<TAB>status<TAB>stamp<TAB>kind<TAB>scope<TAB>epoch<TAB>detail
# (status "v2": a later result for the file is in the state above). stamp comes
# from gate_file_stamp. Every field is non-empty ("-"), so `read` with a tab IFS
# can't shift fields.
#
#   gate_file_stamp  <file>     ck:<cksum> of the content, else mt:<mtime>, else "-"
#   gate_marker_path <project>  ${TMPDIR:-/tmp}/cck-gate-<key>: where results that
#       could not be written inside <project> are noted, one line per file:
#       session<TAB>root<TAB>file<TAB>epoch
#   gate_lines_prune <file> <epoch-field> <days>
#       Delete a line file once every line in it is older than <days>.
#
# Statuses: passed · failed · timeout · error (command not found or not
# executable, invalid .claude/commands.json, a result that could not be recorded)
# · skipped (with a reason). kind is "file", "scope", or "config" (a commands.json
# error — re-verified once the file is valid again).
#

# shellcheck source=python3.sh
source "$(dirname "${BASH_SOURCE[0]}")/python3.sh"

_gate_state_py() {
  # UTF-8 in and out whatever the locale says: a non-ASCII path must not turn a
  # blocking verdict into an encoding error.
  PYTHONIOENCODING=utf-8:surrogateescape PYTHONUTF8=1 python3 - "$@" <<'PY'
import calendar, contextlib, fcntl, hashlib, json, os, sys, tempfile, time

BLOCKING = ("failed", "timeout", "error")
LOCK_WAIT = 10  # seconds a writer waits for another one to finish

class Unreadable(Exception):
    pass

def digest(path):
    try:
        with open(path, "rb") as fh:
            return hashlib.sha256(fh.read()).hexdigest()
    except OSError:
        return None

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def epoch(at):
    try:
        return calendar.timegm(time.strptime(at, "%Y-%m-%dT%H:%M:%SZ"))
    except (TypeError, ValueError):
        return None

def load(path):
    """The state, empty when there is none yet. A file that exists but can't be
    read raises Unreadable: treating it as empty would forget every failure."""
    try:
        with open(path, encoding="utf-8") as fh:
            d = json.load(fh)
    except FileNotFoundError:
        return {"schema_version": 2, "runs": {}, "files": {}, "pending": {}}
    except (OSError, ValueError) as e:
        raise Unreadable(f"{os.path.basename(path)} is unreadable ({e})")
    if not (isinstance(d, dict) and d.get("schema_version") == 2
            and isinstance(d.get("runs"), dict) and isinstance(d.get("files"), dict)):
        raise Unreadable(f"{os.path.basename(path)} is not a schema_version 2 gate state")
    if not isinstance(d.get("pending"), dict):
        d["pending"] = {}
    return d

def save(path, d):
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path) or ".",
                               prefix="." + os.path.basename(path) + ".", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(d, fh, indent=2)
        os.replace(tmp, path)
    except BaseException:
        with contextlib.suppress(OSError):
            os.unlink(tmp)
        raise

@contextlib.contextmanager
def locked(state):
    fd = os.open(state + ".lock", os.O_RDWR | os.O_CREAT, 0o644)
    try:
        deadline = time.monotonic() + LOCK_WAIT
        while True:
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() > deadline:
                    raise TimeoutError(f"{os.path.basename(state)}.lock is still held after {LOCK_WAIT}s")
                time.sleep(0.02)
        yield
    finally:
        os.close(fd)  # releases the lock

def visible(rec, sid):
    """Whether a record counts for session sid: its own, or of an unknown session
    (fail closed). "-" is "no session id"."""
    sessions = rec.get("sessions") if isinstance(rec, dict) else None
    return sid == "-" or not sessions or "-" in sessions or sid in sessions

def sessions_of(prev, sid):
    """prev's sessions plus sid. A record from before sessions were kept is of an
    unknown session."""
    s = list(prev.get("sessions") or (["-"] if prev else []))
    if sid not in s:
        s.append(sid)
    return s

def classify(d, config_ok, sid):
    """(kind, info) for every tracked file of session sid that still exists."""
    out = []
    for path in sorted(d["files"]):
        rec = d["files"][path]
        if not visible(rec, sid) or not os.path.isfile(path):
            continue  # another session's, or deleted since — nothing left to verify
        if rec.get("status") == "skipped":
            out.append(("unverified", {"file": path, "reason": rec.get("reason", "")}))
            continue
        scope = rec.get("scope", "")
        run = d["runs"].get(scope) or {}
        status = run.get("status")
        info = {"file": path, "scope": scope, "command": run.get("command", ""),
                "status": status or "", "reason": run.get("reason", "")}
        if (status is None or status == "running" or rec.get("hash") is None
                or digest(path) != rec.get("hash")
                or (run.get("kind") == "config" and config_ok)):
            out.append(("stale", info))
        elif status in BLOCKING:
            out.append(("block", info))
        else:
            out.append(("verified", info))
    return out

def orphans(d, sid):
    """Scope-wide runs whose latest result blocks while every file of session sid
    they covered is gone (renamed or deleted): the failure may have moved with
    the content, so it still blocks until the scope runs again."""
    by_scope = {}
    for path, rec in d["files"].items():
        if rec.get("status") != "skipped" and visible(rec, sid):
            by_scope.setdefault(rec.get("scope", ""), []).append(path)
    out = []
    for scope in sorted(by_scope):
        run = d["runs"].get(scope) or {}
        if (run.get("kind") == "scope" and run.get("status") in BLOCKING
                and not any(os.path.isfile(p) for p in by_scope[scope])):
            out.append({"scope": scope, "command": run.get("command", ""), "status": run["status"]})
    return out

def start(state, path, scope, kind, command, sid):
    with locked(state):
        d = load(state)
        seq = int(d.get("seq", 0)) + 1
        d["seq"] = seq
        d["runs"][scope] = {"command": command, "kind": kind, "status": "running",
                            "exit_code": None, "reason": "", "at": now(), "duration_s": 0,
                            "started": seq}
        prev = d["files"].get(path) or {}
        d["files"][path] = {"scope": scope, "hash": digest(path), "at": now(),
                            "sessions": sessions_of(prev, sid)}
        # What this run checks: the files its scope tracks, as they are now. An
        # older run of the scope can no longer record a result, so its snapshot goes.
        d["pending"] = {k: v for k, v in d["pending"].items()
                        if isinstance(v, dict) and v.get("scope") != scope}
        d["pending"][str(seq)] = {"scope": scope, "at": now(), "hashes": {
            p: digest(p) for p, rec in d["files"].items() if rec.get("scope") == scope}}
        save(state, d)
    print(seq)

def finish(state, summary, run, path, scope, kind, command, status, exit_code, reason, duration, tail, sid):
    with locked(state):
        d = load(state)
        prev = d["files"].get(path) or {}
        notified = False
        if status == "skipped":
            notified = (prev.get("status") == "skipped" and prev.get("reason") == reason
                        and prev.get("notified", False))
            d["files"][path] = {"status": "skipped", "reason": reason, "at": now(), "notified": True,
                                "sessions": sessions_of(prev, sid)}
        else:
            snap = d["pending"].pop(run, None) if run else None
            latest = int((d["runs"].get(scope) or {}).get("started") or 0)
            if run and latest > int(run):
                pass  # a later run of this scope started: its result stands, not this one
            else:
                if run:
                    started = int(run)
                    hashes = (snap or {}).get("hashes", {})
                    own = hashes.get(path)  # None without a snapshot → stale, re-verified
                else:
                    # Nothing was started (a commands.json error, or start failed):
                    # this result belongs to the file as it is now.
                    started = int(d.get("seq", 0)) + 1
                    d["seq"] = started
                    hashes = {}
                    own = digest(path)
                d["runs"][scope] = {"command": command, "kind": kind, "status": status,
                                    "exit_code": int(exit_code), "reason": reason, "at": now(),
                                    "duration_s": int(duration), "started": started}
                d["files"][path] = {"scope": scope, "hash": own, "at": now(),
                                    "sessions": sessions_of(prev, sid)}
                if status == "passed" and kind == "scope":
                    # The check ran over the whole scope: it covers every file it saw,
                    # if that file still has the content it had when the check started.
                    for p, h in hashes.items():
                        rec = d["files"].get(p)
                        if p == path or not rec or rec.get("scope") != scope:
                            continue
                        cur = digest(p)
                        if cur is None:
                            del d["files"][p]
                        elif h is not None and cur == h:
                            rec["hash"] = h
        save(state, d)

        items = classify(d, config_ok=(kind != "config"), sid=sid)
        blocking = [i for k, i in items if k == "block"]
        stale = [i for k, i in items if k == "stale"]
        unverified = [i for k, i in items if k == "unverified"]
        verified = [i for k, i in items if k == "verified"]
        orphaned = orphans(d, sid)
        if blocking:
            overall = blocking[0]["status"]
        elif orphaned:
            overall = orphaned[0]["status"]
        elif stale:
            overall = "stale"
        elif verified:
            overall = "passed"
        else:
            overall = "skipped"
        summ = {
            "status": overall,
            "session_id": sid,
            "exit_code": int(exit_code),
            "tool": command,
            "edited_file": path,
            "duration_seconds": int(duration),
            "stderr_tail": tail,
            "last_run_status": status,
            "reason": reason,
            "blocking_files": [i["file"] for i in blocking],
            "stale_files": [i["file"] for i in stale],
            "unverified_files": [i["file"] for i in unverified],
        }
        save(summary, summ)

    # Paths in messages are relative to the project the state belongs to.
    root = os.path.dirname(os.path.dirname(os.path.abspath(summary)))
    def show(p):
        rp = os.path.relpath(p, root)
        return p if rp.startswith("..") else rp

    msg = ""
    if status in BLOCKING:
        msg = f"Quality gate {status.upper()} for {show(path)}: {command}" + (f" ({reason})" if reason else "") + ".\n"
        if tail.strip():
            msg += tail.strip()[-1500:] + "\n"
        msg += "stop-gate.sh blocks completion until this file's check passes."
    elif status == "skipped" and not notified:
        msg = (f"{show(path)} is NOT verified by the quality gate: {reason}. Nothing checked this "
               "file; verify it another way (tests, a build, running it) before calling the task done.")
    elif status == "passed":
        others = [show(i["file"]) for i in blocking if i["file"] != path]
        if others:
            msg = (f"{show(path)} passed ({command}), but {len(others)} other file(s) still have no "
                   "passing check: " + ", ".join(others[:5]) + ". stop-gate.sh will block until they pass.")
    if msg:
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": msg}}))

def lines(state, config_ok, sid, *unrecorded):
    def clean(s):
        s = str(s).replace("\t", " ").replace("\n", " ").strip()
        return s or "-"
    d = load(state)
    out = []
    for kind, i in classify(d, config_ok=(config_ok == "1"), sid=sid):
        if kind == "block":
            out.append(["block", i["status"], i["file"], i["command"], i["reason"]])
        elif kind == "stale":
            out.append(["stale", i["file"], i["scope"], i["command"]])
        elif kind == "unverified":
            out.append(["unverified", i["file"], i["reason"]])
    for o in orphans(d, sid):
        out.append(["orphan", o["status"], o["scope"], o["command"]])
    for p in sorted(set(unrecorded)):
        rec = d["files"].get(p)
        if (not rec or not visible(rec, sid)) and os.path.isfile(p):
            out.append(["unrecorded", p])
    sys.stdout.write("".join("\t".join(clean(f) for f in row) + "\n" for row in out))

def prune(state, days):
    if not os.path.exists(state):
        return
    cutoff = time.time() - float(days) * 86400
    def old(rec):
        return not isinstance(rec, dict) or (epoch(rec.get("at")) or 0) < cutoff
    with locked(state):
        d = load(state)
        d["files"] = {p: r for p, r in d["files"].items() if not old(r)}
        used = {r.get("scope") for r in d["files"].values()}
        d["runs"] = {s: r for s, r in d["runs"].items() if s in used or not old(r)}
        d["pending"] = {k: v for k, v in d["pending"].items() if not old(v)}
        save(state, d)

cmd, args = sys.argv[1], sys.argv[2:]
try:
    {"start": start, "finish": finish, "lines": lines, "prune": prune}[cmd](*args)
except Unreadable as e:
    sys.stderr.write(f"the gate state is unreadable: {e}\n")
    sys.exit(3)
except Exception as e:
    sys.stderr.write(f"{type(e).__name__}: {e}\n")
    sys.exit(3)
PY
}

# _gate_state_try <cmd> [args...] — run the helper; its stdout passes through. On
# failure GATE_STATE_ERR holds the reason (the helper's last stderr line).
_gate_state_try() {
  local err
  GATE_STATE_ERR=""
  if { err=$(_gate_state_py "$@" 2>&1 1>&3 3>&-); } 3>&1; then
    return 0
  fi
  GATE_STATE_ERR="${err##*$'\n'}"
  [ -n "$GATE_STATE_ERR" ] || GATE_STATE_ERR="the gate state helper (python3) failed"
  return 1
}

gate_state_start() {
  python3_usable || return 0
  _gate_state_try start "$@" && return 0
  printf '%s\n' "$GATE_STATE_ERR"
  return 1
}

gate_state_finish() {
  python3_usable || return 1
  _gate_state_try finish "$@" || return 2
}

gate_state_lines() {
  if ! python3_usable; then
    printf 'error\t%s\n' "no usable python3 to read the gate state"
    return 1
  fi
  _gate_state_try lines "$@" && return 0
  printf 'error\t%s\n' "$GATE_STATE_ERR"
  return 1
}

gate_state_prune() {
  python3_usable || return 0
  _gate_state_try prune "$@"
}

gate_file_stamp() {
  local out
  if out=$(cksum <"$1" 2>/dev/null) && [ -n "$out" ]; then
    printf 'ck:%s\n' "${out//[[:space:]]/:}"
  elif out=$(date -r "$1" +%s 2>/dev/null) && [ -n "$out" ]; then
    printf 'mt:%s\n' "$out"
  else
    printf '%s\n' "-"
  fi
}

gate_marker_path() {
  local key=""
  key=$(printf '%s' "$1" | cksum 2>/dev/null) || key=""
  key="${key%%[[:space:]]*}"
  if [ -z "$key" ]; then
    key="${1//[^A-Za-z0-9]/_}"
    key="${key: -100}"
  fi
  printf '%s/cck-gate-%s\n' "${TMPDIR:-/tmp}" "$key"
}

gate_lines_prune() {
  local f="$1" n="$2" cutoff line
  local -a parts
  [ -f "$f" ] || return 0
  cutoff=$(( $(date +%s) - $3 * 86400 ))
  while IFS= read -r line; do
    IFS=$'\t' read -r -a parts <<<"$line"
    case "${parts[n-1]:-}" in
      ''|*[!0-9]*) return 0 ;;  # not an epoch: keep the file
    esac
    [ "${parts[n-1]}" -lt "$cutoff" ] || return 0
  done <"$f"
  rm -f "$f"
}
