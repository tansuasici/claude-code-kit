#!/usr/bin/env bash
#
# run-with-timeout.sh — run a check under a hard time limit, on every platform.
#
# Source it:  source "$HOOK_LIB/run-with-timeout.sh"
#
#   run_with_timeout <seconds> <cmd> [args...]
#
# Exit status is the command's own, or 124 when the limit was hit (GNU timeout's
# convention). The command runs in its own process group. On timeout the whole
# group gets SIGTERM, then SIGKILL after a 3s grace, so `sh -c "cd … && npx tsc"`
# can't leave the real tool running once its shell is gone — GNU timeout signals
# only the direct child. When the command finishes on its own, whatever it left
# running in its group (`lint & true`) is ended the same way, so no leftover keeps
# running or holds the check's output open. If the wrapper itself is signalled
# (SIGTERM/SIGINT/SIGHUP) it kills the group before exiting; if only the calling
# hook dies, the wrapper still enforces the limit on its own.
#
# Order: python3 (process-group kill; the gate's state writes already need it) →
# GNU timeout / gtimeout → perl alarm (ships with macOS; process-group kill too) →
# unbounded, with a warning on stderr, only when none of those exist.
#

# shellcheck source=python3.sh
source "$(dirname "${BASH_SOURCE[0]}")/python3.sh"

run_with_timeout() {
  local secs="$1"
  shift
  if python3_usable; then
    python3 -c '
import os, signal, subprocess, sys, time

GRACE = 3
secs = float(sys.argv[1])
try:
    p = subprocess.Popen(sys.argv[2:], stdin=subprocess.DEVNULL, start_new_session=True)
except OSError as e:
    sys.stderr.write("run_with_timeout: %s\n" % e)
    sys.exit(127)

def kill_group():
    """SIGTERM the process group, SIGKILL whatever is left of it after GRACE s."""
    try:
        os.killpg(p.pid, signal.SIGTERM)
    except (ProcessLookupError, PermissionError):
        return  # nothing left in the group
    deadline = time.monotonic() + GRACE
    while time.monotonic() < deadline:
        p.poll()  # reap the leader, so a zombie leader does not keep the group alive
        try:
            os.killpg(p.pid, 0)
        except (ProcessLookupError, PermissionError):
            return
        time.sleep(0.05)
    try:
        os.killpg(p.pid, signal.SIGKILL)
    except (ProcessLookupError, PermissionError):
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
kill_group()  # the command is done: end anything it left running in its group
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
    # The command runs in its own process group; on SIGALRM the whole group is
    # killed (a plain alarm + exec ended only the shell and left the tool running).
    perl -e '
use POSIX ();
my $secs = shift @ARGV;
my $pid = fork;
defined $pid or exit 127;
if (!$pid) { setpgrp(0, 0); exec @ARGV or exit 127; }
setpgrp($pid, $pid);
sub kill_group {
  kill("TERM", -$pid) or return;
  for (1 .. 60) {
    waitpid($pid, POSIX::WNOHANG());
    kill(0, -$pid) or return;
    select(undef, undef, undef, 0.05);
  }
  kill("KILL", -$pid);
}
my $rc;
eval {
  local $SIG{ALRM} = sub { die "alarm\n" };
  alarm $secs;
  waitpid($pid, 0);
  $rc = $?;
  alarm 0;
};
if ($@) {
  kill_group();
  waitpid($pid, 0);
  print STDERR "run_with_timeout: timed out after ${secs}s, process group killed\n";
  exit 124;
}
kill_group();
exit(($rc & 127) ? 128 + ($rc & 127) : $rc >> 8);
' "${secs%.*}" "$@"
    return $?
  fi
  echo "run_with_timeout: no python3, timeout, gtimeout or perl — running without a time limit" >&2
  "$@"
}
