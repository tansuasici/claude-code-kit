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
# Same hash tool order as install.sh's file_hash.
hash_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  else
    python3 -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$1"
  fi
}
# set_baseline <project> <rel> <hash> — pretend the kit last installed <hash> at <rel>.
set_baseline() {
  awk -F'\t' -v OFS='\t' -v p="$2" -v h="$3" '$2 == p { $1 = h } { print }' "$1/.kit-baseline" > "$1/.kit-baseline.tmp" \
    && mv "$1/.kit-baseline.tmp" "$1/.kit-baseline"
}
# upgrade_summary <log> — the "Upgrade summary:" line with colors stripped.
upgrade_summary() {
  sed "s/$(printf '\033')\[[0-9;]*m//g" "$1" | grep 'Upgrade summary' || true
}

TMP="$(mktemp -d "${TMPDIR:-/tmp}/cck-install-test.XXXXXX")"
STMP="$(mktemp -d "${TMPDIR:-/tmp}/cck-strict-test.XXXXXX")"
GTMP="$(mktemp -d "${TMPDIR:-/tmp}/cck-generic-test.XXXXXX")"
trap 'rm -rf "$TMP" "$STMP" "$GTMP"' EXIT
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

echo "== scripts (user-facing only) =="
# Kit-maintainer scripts used to ship too. In a project, sync-manifest.sh then
# sourced a scripts/lib/ that never ships, failed, and still exited 0.
. "$KIT_ROOT/scripts/lib/manifest.sh"
WANT_SCRIPTS=$(printf '%s\n' $KIT_USER_SCRIPTS | LC_ALL=C sort)
GOT_SCRIPTS=$(cd "$TMP/scripts" && ls -1 *.sh | LC_ALL=C sort)
[ "$GOT_SCRIPTS" = "$WANT_SCRIPTS" ] && pass "scripts/ holds exactly KIT_USER_SCRIPTS" || fail "scripts/ is not KIT_USER_SCRIPTS: $(echo $GOT_SCRIPTS)"
GOT_MANIFEST=$(grep '^scripts/' "$TMP/.kit-manifest" | sed 's#^scripts/##' | LC_ALL=C sort)
[ "$GOT_MANIFEST" = "$WANT_SCRIPTS" ] && pass ".kit-manifest lists the same scripts" || fail ".kit-manifest scripts differ: $(echo $GOT_MANIFEST)"
for s in build-skills.sh run-bench.sh sync-manifest.sh test-install.sh; do
  assert_absent "$TMP/scripts/$s"
done
# npx installs copy from the npm tarball, so `files` must carry the same set.
GOT_PACKAGE=$(grep -oE '"scripts/[a-z-]+\.sh"' "$KIT_ROOT/package.json" | tr -d '"' | sed 's#^scripts/##' | LC_ALL=C sort)
[ "$GOT_PACKAGE" = "$WANT_SCRIPTS" ] && pass "package.json files ships the same scripts" || fail "package.json files scripts differ: $(echo $GOT_PACKAGE)"
LONE="$TMP/.lone"
mkdir -p "$LONE/scripts" && cp "$KIT_ROOT/scripts/sync-manifest.sh" "$LONE/scripts/"
if bash "$LONE/scripts/sync-manifest.sh" --check >/dev/null 2>&1; then
  fail "sync-manifest.sh --check exits 0 without scripts/lib/manifest.sh"
else
  pass "sync-manifest.sh fails loudly without its library"
fi
rm -rf "$LONE"

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

echo "== generic template (no stack detected) =="
# GTMP has no package.json/go.mod/Cargo.toml, so auto-detection finds nothing and
# install falls back to the generic map. That fallback used to be this repo's own
# CODEBASE_MAP.md, which describes ClaudeCodeKit — the first file CLAUDE.md tells
# the agent to read for orientation.
# GTMP also has a scripts/ of its own, which takes the "Skipped scripts/" path —
# that used to record every *.sh in it as a kit file. Its test-install.sh shares
# a kit-maintainer script's name but was never the kit's — no leftover warning.
mkdir -p "$GTMP/scripts" && echo 'echo deploy' > "$GTMP/scripts/deploy.sh"
echo 'echo own tests' > "$GTMP/scripts/test-install.sh"
if ( cd "$GTMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" >"$GTMP/.install.log" 2>&1 ); then
  pass "generic install ran clean"
else
  fail "generic install failed"; tail -8 "$GTMP/.install.log"
fi
if cmp -s "$GTMP/CODEBASE_MAP.md" "$KIT_ROOT/CODEBASE_MAP.md"; then
  fail "generic install shipped this repo's own CODEBASE_MAP.md"
else
  pass "generic install ships a blank map, not this repo's own"
fi
KITREF=$(grep -c 'ClaudeCodeKit' "$GTMP/CODEBASE_MAP.md" || true)
[ "${KITREF:-0}" = "0" ] && pass "installed map does not mention ClaudeCodeKit" || fail "installed map mentions ClaudeCodeKit ${KITREF}×"
if grep -qxF 'scripts/deploy.sh' "$GTMP/.kit-manifest"; then
  fail "the project's own scripts/deploy.sh was recorded as a kit file"
else
  pass "the project's own scripts stay out of .kit-manifest"
fi
GENERIC_LOG=$(cat "$GTMP/.install.log")
[[ "$GENERIC_LOG" != *"No longer shipped"* ]] && pass "first install doesn't call the project's own test-install.sh a leftover" || fail "first install reported the project's own test-install.sh as a kit leftover"

echo "== upgrade: install from before .kit-baseline, stack added since (TAN-6269) =="
# Without a baseline a local edit can't be told from an older kit file: changed
# files are replaced and the previous copies backed up. CLAUDE.md must stay on the
# template it came from even though a package.json now auto-detects as node-api.
rm -f "$GTMP/.kit-baseline"
echo '{"name":"late-node","version":"1.0.0"}' > "$GTMP/package.json"
printf '#!/usr/bin/env bash\n# an older kit version\n' > "$GTMP/.claude/hooks/secret-scan.sh"
if ( cd "$GTMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --upgrade >"$GTMP/.upgrade.log" 2>&1 ); then
  pass "upgrade of a pre-baseline install ran clean"
else
  fail "upgrade of a pre-baseline install failed"; tail -8 "$GTMP/.upgrade.log"
fi
cmp -s "$KIT_ROOT/.claude/hooks/secret-scan.sh" "$GTMP/.claude/hooks/secret-scan.sh" \
  && pass "stale hook updated" || fail "stale hook left in place: .claude/hooks/secret-scan.sh"
BACKUP=$(find "$GTMP/.kit-backup" -type f -name secret-scan.sh 2>/dev/null | head -n 1)
if [ -n "$BACKUP" ] && grep -q 'an older kit version' "$BACKUP"; then
  pass "previous copy kept in .kit-backup/"
else
  fail "no backup of the replaced hook under .kit-backup/"
fi
cmp -s "$KIT_ROOT/CLAUDE.md" "$GTMP/CLAUDE.md" \
  && pass "CLAUDE.md stays on the generic template" || fail "upgrade swapped CLAUDE.md for another template"
grep -q "^#template	generic$" "$GTMP/.kit-baseline" 2>/dev/null \
  && pass "baseline written, template recorded" || fail ".kit-baseline missing or template not recorded"

echo "== doctor =="
if ( cd "$TMP" && bash ./scripts/doctor.sh >"$TMP/.doctor.log" 2>&1 ); then
  pass "doctor reports healthy"
else
  fail "doctor reported a failure"; tail -8 "$TMP/.doctor.log"
fi

echo "== upgrade (idempotent) =="
# Plant a kit-maintainer script the way an earlier install left it (file +
# manifest entry): upgrade must report it, keep it, and drop it from the manifest.
cp "$KIT_ROOT/scripts/run-bench.sh" "$TMP/scripts/"
echo "scripts/run-bench.sh" >> "$TMP/.kit-manifest"
if ( cd "$TMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --upgrade >"$TMP/.upgrade.log" 2>&1 ); then
  pass "upgrade ran clean"
else
  fail "upgrade failed"; tail -8 "$TMP/.upgrade.log"
fi
assert_file "$TMP/CLAUDE.md"
assert_file "$TMP/.kit-baseline"
SUMMARY=$(upgrade_summary "$TMP/.upgrade.log")
[[ "$SUMMARY" == *" 0 updated · 0 added · "*" · 0 kept (local edits) · 0 conflicts"* ]] \
  && pass "re-upgrading a fresh install changes nothing" || fail "re-upgrade of a fresh install: ${SUMMARY:-no summary line}"
UPGRADE_LOG=$(cat "$TMP/.upgrade.log")
[[ "$UPGRADE_LOG" == *"scripts/run-bench.sh"* ]] && pass "upgrade reports leftover scripts/run-bench.sh" || fail "upgrade did not report leftover scripts/run-bench.sh"
assert_file "$TMP/scripts/run-bench.sh"
if grep -qxF 'scripts/run-bench.sh' "$TMP/.kit-manifest"; then
  fail "leftover scripts/run-bench.sh is still in .kit-manifest"
else
  pass "leftover scripts/run-bench.sh dropped from .kit-manifest"
fi

echo "== upgrade: kit changes land, local edits survive (TAN-6269) =="
# --upgrade used to copy only MISSING files, so a file a release changed was never
# updated while VERSION was bumped. Each case below is set up against the baseline.
H1=".claude/hooks/block-dangerous-commands.sh"          # kit changed it, you didn't → updated
H2=".claude/hooks/secret-scan.sh"                       # you edited it, kit didn't  → kept
H3=".claude/hooks/branch-protect.sh"                    # both changed it            → conflict
S1=".claude/skills/debug/references/error-patterns.md" # nested skill file          → updated
printf '#!/usr/bin/env bash\n# an older kit version\n' > "$TMP/$H1"
set_baseline "$TMP" "$H1" "$(hash_of "$TMP/$H1")"
printf 'an older kit version\n' > "$TMP/$S1"
set_baseline "$TMP" "$S1" "$(hash_of "$TMP/$S1")"
echo '# my local tweak' >> "$TMP/$H2"
echo '# my local tweak' >> "$TMP/$H3"
set_baseline "$TMP" "$H3" "$(hash_of "$TMP/package.json")"  # the kit last shipped something else here
echo '- [ ] my own task' >> "$TMP/tasks/todo.md"
echo '## My module' >> "$TMP/CODEBASE_MAP.md"
cp "$TMP/tasks/todo.md" "$TMP/.todo.before"
cp "$TMP/CODEBASE_MAP.md" "$TMP/.map.before"
if ( cd "$TMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --upgrade >"$TMP/.upgrade2.log" 2>&1 ); then
  pass "upgrade over an edited install ran clean"
else
  fail "upgrade over an edited install failed"; tail -8 "$TMP/.upgrade2.log"
fi
cmp -s "$KIT_ROOT/$H1" "$TMP/$H1" && pass "kit-changed hook updated" || fail "kit-changed hook left stale: $H1"
cmp -s "$KIT_ROOT/$S1" "$TMP/$S1" && pass "nested skill file updated" || fail "nested skill file left stale: $S1"
grep -q 'my local tweak' "$TMP/$H2" && pass "locally edited hook kept" || fail "local edit overwritten: $H2"
assert_absent "$TMP/$H2.kit-new"
grep -q 'my local tweak' "$TMP/$H3" && pass "conflicting hook kept" || fail "local edit overwritten on conflict: $H3"
cmp -s "$KIT_ROOT/$H3" "$TMP/$H3.kit-new" && pass "conflict: kit version saved as .kit-new" || fail "conflict: no .kit-new for $H3"
cmp -s "$TMP/.todo.before" "$TMP/tasks/todo.md" && pass "tasks/todo.md untouched" || fail "upgrade modified tasks/todo.md"
cmp -s "$TMP/.map.before" "$TMP/CODEBASE_MAP.md" && pass "CODEBASE_MAP.md untouched" || fail "upgrade modified CODEBASE_MAP.md"
cmp -s "$KIT_ROOT/examples/node-api/CLAUDE.md" "$TMP/CLAUDE.md" \
  && pass "CLAUDE.md still on its node-api template" || fail "CLAUDE.md drifted off its node-api template"
assert_absent "$TMP/.kit-backup"  # every file had a baseline entry — nothing needed a backup
SUMMARY=$(upgrade_summary "$TMP/.upgrade2.log")
[[ "$SUMMARY" == *" 2 updated · "* && "$SUMMARY" == *" 1 kept (local edits) · 1 conflicts"* ]] \
  && pass "summary reports 2 updated · 1 kept · 1 conflict" || fail "summary: ${SUMMARY:-no summary line}"
# A conflict is reported once: the next upgrade keeps the file quietly unless the
# kit changes it again.
( cd "$TMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --upgrade >"$TMP/.upgrade3.log" 2>&1 ) || fail "third upgrade failed"
SUMMARY=$(upgrade_summary "$TMP/.upgrade3.log")
[[ "$SUMMARY" == *" 0 updated · "* && "$SUMMARY" == *" 2 kept (local edits) · 0 conflicts"* ]] \
  && pass "next upgrade: conflict settles to kept" || fail "next upgrade summary: ${SUMMARY:-no summary line}"

echo "== uninstall --force =="
if ! ( cd "$TMP" && bash "$KIT_ROOT/uninstall.sh" --force >"$TMP/.uninstall.log" 2>&1 ); then
  fail "uninstall.sh errored"; tail -8 "$TMP/.uninstall.log"
fi
assert_absent "$TMP/CLAUDE.md"
assert_absent "$TMP/.claude/hooks"
assert_absent "$TMP/.kit-manifest"
assert_absent "$TMP/.kit-baseline"
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
