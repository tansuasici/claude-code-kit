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
#                  {command, kind, status, exit_code, reason, at, duration_s}
#   files[<path>]  {scope, hash, at}: the scope that last checked the file and
#                  the file's sha256 at that moment — or {status: "skipped",
#                  reason} when no check applies to it
#
# A file is verified only while its scope's latest run passed AND its content
# still hashes the same. A passing scope-wide run re-covers every file in scope.
#
#   gate_state_start  <state> <file> <scope> <kind> <command>
#       Mark a check in flight. A hook killed mid-check leaves "running", which
#       stop-gate.sh treats as stale and re-verifies.
#   gate_state_finish <state> <summary> <file> <scope> <kind> <command> <status>
#                     <exit_code> <reason> <duration_s> <stderr_tail>
#       Record the result, rewrite the summary (last_quality_gate.json) and print
#       PostToolUse additionalContext JSON when Claude should hear about it.
#       Returns non-zero without python3, so the caller can write the summary.
#   gate_state_lines  <state> <config_ok 0|1>
#       One line per tracked file that is not verified, tab-separated, "-" for
#       an empty field:
#         block<TAB>status<TAB>file<TAB>command<TAB>reason
#         stale<TAB>file<TAB>scope<TAB>command
#         unverified<TAB>file<TAB>reason
#
# Statuses: passed · failed · timeout · error (command not found or not
# executable, invalid .claude/commands.json) · skipped (with a reason).
# kind is "file", "scope", or "config" (a commands.json error — re-verified once
# the file is valid again).
#

_gate_state_py() {
  python3 - "$@" <<'PY'
import hashlib, json, os, sys, time

BLOCKING = ("failed", "timeout", "error")

def digest(path):
    try:
        with open(path, "rb") as fh:
            return hashlib.sha256(fh.read()).hexdigest()
    except OSError:
        return None

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def load(path):
    try:
        with open(path) as fh:
            d = json.load(fh)
        if isinstance(d, dict) and d.get("schema_version") == 2:
            if not isinstance(d.get("runs"), dict):
                d["runs"] = {}
            if not isinstance(d.get("files"), dict):
                d["files"] = {}
            return d
    except (OSError, ValueError):
        pass
    return {"schema_version": 2, "runs": {}, "files": {}}

def save(path, d):
    tmp = path + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(d, fh, indent=2)
    os.replace(tmp, path)

def classify(d, config_ok):
    """(kind, info) for every tracked file that still exists."""
    out = []
    for path in sorted(d["files"]):
        rec = d["files"][path]
        if not os.path.isfile(path):
            continue  # deleted since — nothing left to verify
        if rec.get("status") == "skipped":
            out.append(("unverified", {"file": path, "reason": rec.get("reason", "")}))
            continue
        scope = rec.get("scope", "")
        run = d["runs"].get(scope) or {}
        status = run.get("status")
        info = {"file": path, "scope": scope, "command": run.get("command", ""),
                "status": status or "", "reason": run.get("reason", "")}
        if (status is None or status == "running" or digest(path) != rec.get("hash")
                or (run.get("kind") == "config" and config_ok)):
            out.append(("stale", info))
        elif status in BLOCKING:
            out.append(("block", info))
        else:
            out.append(("verified", info))
    return out

def start(state, path, scope, kind, command):
    d = load(state)
    d["runs"][scope] = {"command": command, "kind": kind, "status": "running",
                        "exit_code": None, "reason": "", "at": now(), "duration_s": 0}
    d["files"][path] = {"scope": scope, "hash": digest(path), "at": now()}
    save(state, d)

def finish(state, summary, path, scope, kind, command, status, exit_code, reason, duration, tail):
    d = load(state)
    prev = d["files"].get(path) or {}
    notified = False
    if status == "skipped":
        notified = (prev.get("status") == "skipped" and prev.get("reason") == reason
                    and prev.get("notified", False))
        d["files"][path] = {"status": "skipped", "reason": reason, "at": now(), "notified": True}
    else:
        d["runs"][scope] = {"command": command, "kind": kind, "status": status,
                            "exit_code": int(exit_code), "reason": reason, "at": now(),
                            "duration_s": int(duration)}
        d["files"][path] = {"scope": scope, "hash": digest(path), "at": now()}
        if status == "passed" and kind == "scope":
            # The check just ran over the whole scope, so it covers every file in it
            # as that file is now.
            for p in list(d["files"]):
                rec = d["files"][p]
                if p != path and rec.get("scope") == scope:
                    h = digest(p)
                    if h is None:
                        del d["files"][p]
                    else:
                        rec["hash"] = h
    save(state, d)

    items = classify(d, config_ok=(kind != "config"))
    blocking = [i for k, i in items if k == "block"]
    stale = [i for k, i in items if k == "stale"]
    unverified = [i for k, i in items if k == "unverified"]
    verified = [i for k, i in items if k == "verified"]
    if blocking:
        overall = blocking[0]["status"]
    elif stale:
        overall = "stale"
    elif verified:
        overall = "passed"
    else:
        overall = "skipped"
    summ = {
        "status": overall,
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

def lines(state, config_ok):
    def clean(s):
        s = str(s).replace("\t", " ").replace("\n", " ").strip()
        return s or "-"
    d = load(state)
    for kind, i in classify(d, config_ok=(config_ok == "1")):
        if kind == "block":
            print("\t".join(["block", clean(i["status"]), clean(i["file"]), clean(i["command"]), clean(i["reason"])]))
        elif kind == "stale":
            print("\t".join(["stale", clean(i["file"]), clean(i["scope"]), clean(i["command"])]))
        elif kind == "unverified":
            print("\t".join(["unverified", clean(i["file"]), clean(i["reason"])]))

cmd, args = sys.argv[1], sys.argv[2:]
{"start": start, "finish": finish, "lines": lines}[cmd](*args)
PY
}

gate_state_start() {
  command -v python3 >/dev/null 2>&1 || return 0
  _gate_state_py start "$@" 2>/dev/null || true
}

gate_state_finish() {
  command -v python3 >/dev/null 2>&1 || return 1
  _gate_state_py finish "$@" 2>/dev/null
}

gate_state_lines() {
  command -v python3 >/dev/null 2>&1 || return 0
  _gate_state_py lines "$@" 2>/dev/null || true
}
