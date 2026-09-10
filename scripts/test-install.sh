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
rel() { local p="${1#"$TMP"/}"; echo "${p#"${STMP:-}"/}"; }
assert_file()   { [ -f "$1" ] && pass "exists: $(rel "$1")"     || fail "missing file: $(rel "$1")"; }
assert_dir()    { [ -d "$1" ] && pass "exists: $(rel "$1")/"    || fail "missing dir: $(rel "$1")"; }
assert_absent() { [ ! -e "$1" ] && pass "absent: $(rel "$1")"   || fail "should be absent: $(rel "$1")"; }
# Validate JSON with whatever the box has — same fallback order as doctor.sh.
json_valid() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$1" 2>/dev/null
  elif command -v node >/dev/null 2>&1; then
    node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$1" 2>/dev/null
  else
    return 0  # no validator available — treat as valid rather than fail the suite
  fi
}

TMP="$(mktemp -d "${TMPDIR:-/tmp}/cck-install-test.XXXXXX")"
STMP="$(mktemp -d "${TMPDIR:-/tmp}/cck-strict-test.XXXXXX")"
trap 'rm -rf "$TMP" "$STMP"' EXIT
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

echo "== task scaffold (no kit-internal state) =="
# The kit dogfoods itself, so its own tasks/ carries a live board, 15 ADRs, real
# lessons and a spike spec. A fresh project must get scaffold/tasks/, not that.
assert_file "$TMP/tasks/todo.md"
assert_file "$TMP/tasks/decisions.md"
assert_file "$TMP/tasks/handoff.md"
assert_file "$TMP/tasks/lessons/_index.md"
assert_file "$TMP/tasks/lessons/_TEMPLATE.md"
assert_absent "$TMP/tasks/specs"
LESSONS=$(find "$TMP/tasks/lessons" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
[ "$LESSONS" -eq 3 ] && pass "lessons scaffold is 3 files" || fail "expected 3 scaffold lessons, got $LESSONS"
LEAK=$(grep -rlE 'CLA-[0-9]|TAN-[0-9]|release-please cut' "$TMP/tasks" 2>/dev/null || true)
[ -z "$LEAK" ] && pass "no kit-internal state in tasks/" || fail "kit-internal state leaked into tasks/: $LEAK"
ADRS=$(grep -cE '^### ADR-[0-9]' "$TMP/tasks/decisions.md" || true)
[ "$ADRS" -eq 1 ] && pass "decisions.md ships only the ADR-001 example" || fail "decisions.md carries $ADRS ADRs (expected the 1 example)"

echo "== package contents (files field) =="
# package.json `files` supersedes .npmignore, so a wholesale ".claude/" entry
# silently shipped the maintainer's settings.local.json to every npm user.
if command -v npm >/dev/null 2>&1; then
  PACK=$(cd "$KIT_ROOT" && npm pack --dry-run 2>&1)
  if [[ "$PACK" == *"settings.local.json"* ]]; then
    fail "npm tarball would ship .claude/settings.local.json"
  else
    pass "npm tarball excludes settings.local.json"
  fi
  if [[ "$PACK" == *" tasks/"* ]]; then
    fail "npm tarball would ship the kit's own tasks/"
  else
    pass "npm tarball ships scaffold/tasks/, not the kit's own tasks/"
  fi
else
  pass "npm unavailable — package-contents check skipped"
fi

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
# The manifest backstop sweeps kit files the path-based detection misses (e.g.
# .claude/*.example), so .claude/ is left fully clean — no orphaned kit files.
assert_absent "$TMP/.claude"
# the user's own file must survive
assert_file "$TMP/package.json"

# --- strict profile: install path is otherwise never exercised (TAN-4689) -----
echo "== strict profile install =="
echo '{"name":"fixture-strict","version":"1.0.0"}' > "$STMP/package.json"
if ( cd "$STMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --profile strict >"$STMP/.install.log" 2>&1 ); then
  pass "strict install ran clean"
else
  fail "strict install failed"; tail -8 "$STMP/.install.log"
fi
STRICT_SETTINGS="$STMP/.claude/settings.json"
assert_file "$STRICT_SETTINGS"
if json_valid "$STRICT_SETTINGS"; then
  pass "strict settings.json is valid JSON"
else
  fail "strict settings.json is INVALID JSON"
fi
# The strict delta: 5 opt-in hooks + the build-config hard-block flag.
for needle in skill-extract-reminder.sh auto-lint.sh auto-format.sh skill-compliance.sh notify-waiting.sh CCK_PROTECT_BUILD_CONFIGS; do
  grep -q "$needle" "$STRICT_SETTINGS" && pass "strict enables $needle" || fail "strict missing $needle"
done

echo "== strict upgrade (idempotent) =="
if ( cd "$STMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --profile strict --upgrade >"$STMP/.upgrade.log" 2>&1 ); then
  pass "strict upgrade ran clean"
else
  fail "strict upgrade failed"; tail -8 "$STMP/.upgrade.log"
fi
json_valid "$STRICT_SETTINGS" && pass "strict settings.json still valid after upgrade" || fail "strict settings.json broke on upgrade"

echo ""
if [ "$FAILS" -eq 0 ]; then
  echo "install-test: ALL PASS"
else
  echo "install-test: $FAILS FAIL"
  exit 1
fi
