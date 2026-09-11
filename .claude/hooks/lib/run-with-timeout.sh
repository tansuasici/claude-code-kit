#!/usr/bin/env bash
#
# run-with-timeout.sh — run a check under a hard time limit, on every platform.
#
# Source it:  source "$HOOK_LIB/run-with-timeout.sh"
#
#   run_with_timeout <seconds> <cmd> [args...]
#
# Exit status is the command's own, or 124 when the limit was hit (GNU timeout's
# convention). On timeout the command's whole process group gets SIGTERM, then
# SIGKILL after a 3s grace, so `sh -c "cd … && npx tsc"` can't leave the real tool
# running once its shell is gone — GNU timeout signals only the direct child. If
# the wrapper itself is signalled (SIGTERM/SIGINT/SIGHUP) it kills the group
# before exiting; if only the calling hook dies, the wrapper still enforces the
# limit on its own.
#
# Order: python3 (process-group kill; the gate's state writes already need it) →
# GNU timeout / gtimeout → perl alarm (ships with macOS) → unbounded, with a
# warning on stderr, only when none of those exist.
#

run_with_timeout() {
  local secs="$1" rc
  shift
  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import os, signal, subprocess, sys

secs = float(sys.argv[1])
try:
    p = subprocess.Popen(sys.argv[2:], stdin=subprocess.DEVNULL, start_new_session=True)
except OSError as e:
    sys.stderr.write("run_with_timeout: %s\n" % e)
    sys.exit(127)

def kill_group():
    for sig in (signal.SIGTERM, signal.SIGKILL):
        try:
            os.killpg(p.pid, sig)
        except (ProcessLookupError, PermissionError):
            return
        if sig == signal.SIGTERM:
            try:
                p.wait(timeout=3)
            except subprocess.TimeoutExpired:
                pass

def on_signal(signum, frame):
    kill_group()
    sys.exit(128 + signum)

for s in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
    signal.signal(s, on_signal)

try:
    rc = p.wait(timeout=secs)
except subprocess.TimeoutExpired:
    kill_group()
    sys.stderr.write("run_with_timeout: timed out after %gs, process group killed\n" % secs)
    sys.exit(124)
sys.exit(128 - rc if rc < 0 else rc)
' "$secs" "$@"
    return $?
  fi
  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout -k 3 "$secs" "$@"
    return $?
  fi
  if command -v timeout >/dev/null 2>&1; then
    timeout -k 3 "$secs" "$@"
    return $?
  fi
  if command -v perl >/dev/null 2>&1; then
    # alarm survives exec; SIGALRM ends the command (exit 142) → report 124.
    perl -e 'alarm shift @ARGV; exec @ARGV or exit 127' "${secs%.*}" "$@"
    rc=$?
    [ "$rc" -eq 142 ] && rc=124
    return "$rc"
  fi
  echo "run_with_timeout: no python3, timeout, gtimeout or perl — running without a time limit" >&2
  "$@"
}
