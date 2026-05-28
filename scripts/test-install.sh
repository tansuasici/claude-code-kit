#!/usr/bin/env bash
#
# test-install.sh — smoke test for install.sh / uninstall.sh on a throwaway project.
#
# Exercises the code path that actually mutates a user's filesystem — fresh
# install, --upgrade idempotency, and clean uninstall — and asserts the
# results. The hooks have KitBench; this gives the installer the same kind of
# contract. CI runs it on ubuntu + macOS; runs locally too.
#
# Exit codes: 0 all assertions passed · 1 one or more failed
#

set -uo pipefail

KIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAILS=0
pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; FAILS=$((FAILS + 1)); }
rel() { echo "${1#"$TMP"/}"; }
assert_file()   { [ -f "$1" ] && pass "exists: $(rel "$1")"     || fail "missing file: $(rel "$1")"; }
assert_dir()    { [ -d "$1" ] && pass "exists: $(rel "$1")/"    || fail "missing dir: $(rel "$1")"; }
assert_absent() { [ ! -e "$1" ] && pass "absent: $(rel "$1")"   || fail "should be absent: $(rel "$1")"; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/cck-install-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
# Make it look like a Node project so a template auto-detects (node-api),
# and so we can assert the user's own files survive uninstall.
echo '{"name":"fixture","version":"1.0.0"}' > "$TMP/package.json"

echo "== fresh install =="
if ! ( cd "$TMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" >"$TMP/.install.log" 2>&1 ); then
  echo "install.sh failed:"; cat "$TMP/.install.log"; exit 1
fi
assert_file "$TMP/CLAUDE.md"
assert_file "$TMP/CODEBASE_MAP.md"
assert_file "$TMP/.claude/settings.json"
assert_file "$TMP/.kit-manifest"
HOOKS=$(find "$TMP/.claude/hooks" -maxdepth 1 -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')
[ "$HOOKS" -ge 18 ] && pass "hooks installed ($HOOKS)" || fail "too few hooks ($HOOKS, expected >=18)"
assert_dir "$TMP/.claude/skills"
# CLA-67 regression: build-only assets must NOT ship to user projects
assert_absent "$TMP/.claude/skills/_shared"
assert_absent "$TMP/.claude/skills/_templates"

echo "== doctor =="
if ( cd "$TMP" && bash ./scripts/doctor.sh >"$TMP/.doctor.log" 2>&1 ); then
  pass "doctor reports healthy"
else
  fail "doctor reported a failure"; tail -8 "$TMP/.doctor.log"
fi

echo "== upgrade (idempotent) =="
if ( cd "$TMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --upgrade >"$TMP/.upgrade.log" 2>&1 ); then
  pass "upgrade ran clean"
else
  fail "upgrade failed"; tail -8 "$TMP/.upgrade.log"
fi
assert_file "$TMP/CLAUDE.md"

echo "== uninstall --force =="
if ! ( cd "$TMP" && bash "$KIT_ROOT/uninstall.sh" --force >"$TMP/.uninstall.log" 2>&1 ); then
  fail "uninstall.sh errored"; tail -8 "$TMP/.uninstall.log"
fi
assert_absent "$TMP/CLAUDE.md"
assert_absent "$TMP/.claude/hooks"
assert_absent "$TMP/.kit-manifest"
# the user's own file must survive
assert_file "$TMP/package.json"

echo ""
if [ "$FAILS" -eq 0 ]; then
  echo "install-test: ALL PASS"
else
  echo "install-test: $FAILS FAIL"
  exit 1
fi
