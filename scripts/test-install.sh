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
DTMP="$(mktemp -d "${TMPDIR:-/tmp}/cck-dotnet-test.XXXXXX")"
XTMP="$(mktemp -d "${TMPDIR:-/tmp}/cck-safety-test.XXXXXX")"
trap 'rm -rf "$TMP" "$STMP" "$GTMP" "$DTMP" "$XTMP"' EXIT
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

echo "== .NET template auto-detection (TAN-6273) =="
echo 'Microsoft Visual Studio Solution File, Format Version 12.00' > "$DTMP/App.sln"
if ( cd "$DTMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" >"$DTMP/.install.log" 2>&1 ); then
  pass "install into a .sln project ran clean"
else
  fail "install into a .sln project failed"; tail -8 "$DTMP/.install.log"
fi
cmp -s "$KIT_ROOT/examples/dotnet/CLAUDE.md" "$DTMP/CLAUDE.md" \
  && pass "a .sln project gets the dotnet template" || fail "a .sln project did not get the dotnet template"

echo "== doctor =="
if ( cd "$TMP" && bash ./scripts/doctor.sh >"$TMP/.doctor.log" 2>&1 ); then
  pass "doctor reports healthy"
else
  fail "doctor reported a failure"; tail -8 "$TMP/.doctor.log"
fi
# A mistyped commands.json key is a config error the gate blocks on — doctor must
# fail on it too, naming the key, and pass once the file is valid (TAN-6274).
printf '{"typcheck": "true"}\n' > "$TMP/.claude/commands.json"
if ( cd "$TMP" && bash ./scripts/doctor.sh >"$TMP/.doctor2.log" 2>&1 ); then
  fail "doctor passed a commands.json with an unknown key"
elif grep -q 'unknown key "typcheck"' "$TMP/.doctor2.log"; then
  pass "doctor fails on a mistyped commands.json key, naming it"
else
  fail "doctor failed without naming the unknown key"; tail -5 "$TMP/.doctor2.log"
fi
printf '{"lint": "true", "timeout": 60}\n' > "$TMP/.claude/commands.json"
if ( cd "$TMP" && bash ./scripts/doctor.sh >"$TMP/.doctor3.log" 2>&1 ); then
  pass "doctor passes a valid commands.json"
else
  fail "doctor failed on a valid commands.json"; tail -5 "$TMP/.doctor3.log"
fi
# A UTF-8 BOM (some editors add one) still makes a valid file; a non-finite
# timeout does not — the gate would silently fall back to 30s (TAN-6278).
printf '\357\273\277{"lint": "true"}\n' > "$TMP/.claude/commands.json"
if ( cd "$TMP" && bash ./scripts/doctor.sh >"$TMP/.doctor5.log" 2>&1 ); then
  pass "doctor passes a commands.json saved with a UTF-8 BOM"
else
  fail "doctor failed on a commands.json saved with a UTF-8 BOM"; tail -5 "$TMP/.doctor5.log"
fi
printf '{"lint": "true", "timeout": Infinity}\n' > "$TMP/.claude/commands.json"
if ( cd "$TMP" && bash ./scripts/doctor.sh >"$TMP/.doctor6.log" 2>&1 ); then
  fail "doctor passed a commands.json with an infinite timeout"
elif grep -q '"timeout" must be a positive number' "$TMP/.doctor6.log"; then
  pass "doctor fails on a non-finite commands.json timeout, naming it"
else
  fail "doctor failed without naming the timeout"; tail -5 "$TMP/.doctor6.log"
fi
rm -f "$TMP/.claude/commands.json"
# Doctor checks behavior, not just files (TAN-6275): the fresh install's run drove
# the installed hooks through block → compaction → fix → worktree isolation.
for check in "Broken code is caught and blocks completion" "The failing verdict survives a compaction" \
             "Fixing the code lifts the block" \
             "A git worktree's result is stored in that worktree and still blocks the session's stop"; do
  grep -qF "$check" "$TMP/.doctor.log" && pass "doctor self-test: $check" || fail "doctor self-test missing: $check"
done
# A stop-gate that never blocks must fail doctor, even though every file exists.
cp "$TMP/.claude/hooks/stop-gate.sh" "$TMP/.stop-gate.bak"
printf '#!/usr/bin/env bash\ncat >/dev/null\nexit 0\n' > "$TMP/.claude/hooks/stop-gate.sh"
if ( cd "$TMP" && bash ./scripts/doctor.sh >"$TMP/.doctor4.log" 2>&1 ); then
  fail "doctor passed with a stop-gate that never blocks"
elif grep -q 'Broken code was not blocked' "$TMP/.doctor4.log"; then
  pass "doctor fails an install whose stop-gate never blocks"
else
  fail "doctor failed, but not on the broken stop-gate"; tail -5 "$TMP/.doctor4.log"
fi
cp "$TMP/.stop-gate.bak" "$TMP/.claude/hooks/stop-gate.sh"
# The behavior checks drive the hook scripts directly, so doctor must also read how
# settings.json wires them — an unwired or bypassed gate used to read healthy (TAN-6280).
if command -v python3 >/dev/null 2>&1; then
  grep -qF "stop-gate.sh runs on Stop" "$TMP/.doctor.log" && grep -qF "quality-gate.sh runs after Edit and Write" "$TMP/.doctor.log" \
    && pass "doctor confirms both gates are wired" || fail "doctor did not report the gates' wiring"
  cp "$TMP/.claude/settings.json" "$TMP/.settings.bak"
  settings_edit() {  # <python statement on d (settings) and h (its hooks)>
    python3 -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p)); h=d.setdefault("hooks",{}); exec(sys.argv[2]); json.dump(d,open(p,"w"),indent=2)' \
      "$TMP/.claude/settings.json" "$1"
  }
  doctor_expect_fail() {  # <log> <expected text> <label>
    if ( cd "$TMP" && bash ./scripts/doctor.sh >"$TMP/$1" 2>&1 ); then
      fail "doctor passed: $3"
    elif grep -qF "$2" "$TMP/$1"; then
      pass "doctor fails: $3"
    else
      fail "doctor failed, but not on: $3"; tail -5 "$TMP/$1"
    fi
    cp "$TMP/.settings.bak" "$TMP/.claude/settings.json"
  }
  settings_edit 'h["SessionEnd"] = h.get("SessionEnd", []) + h.pop("Stop", [])'
  doctor_expect_fail .doctor5.log "stop-gate.sh is not registered under Stop" "stop-gate wired to SessionEnd instead of Stop"
  settings_edit 'h["PostToolUse"] = [e for e in h.get("PostToolUse", []) if "quality-gate.sh" not in json.dumps(e)]'
  doctor_expect_fail .doctor6.log "quality-gate.sh is not registered under PostToolUse" "quality-gate removed from PostToolUse"
  settings_edit 'd.setdefault("env", {})["SKIP_QUALITY_GATE"] = "1"'
  ( cd "$TMP" && bash ./scripts/doctor.sh >"$TMP/.doctor7.log" 2>&1 ) || true
  grep -qF "The quality gate is bypassed in .claude/settings" "$TMP/.doctor7.log" \
    && pass "doctor warns when settings.json bypasses the gate" || fail "doctor did not warn about the settings.json bypass"
  cp "$TMP/.settings.bak" "$TMP/.claude/settings.json"; rm -f "$TMP/.settings.bak"
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
if ( cd "$TMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --diff >"$TMP/.diff0.log" 2>&1 ) \
   && grep -q 'Your installation is up to date' "$TMP/.diff0.log"; then
  pass "--diff on a current install: up to date"
else
  fail "--diff on a current install did not report up to date"; tail -12 "$TMP/.diff0.log"
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

echo "== upgrade preview (--diff) and what --upgrade can't fix (TAN-6277) =="
# --diff runs the real upgrade on a scratch copy, so its plan is exactly what
# --upgrade does. Set up one case of each kind, preview, check that nothing
# changed, then upgrade and check that the preview was right.
printf '#!/usr/bin/env bash\n# an older kit version\n' > "$TMP/$H1"
set_baseline "$TMP" "$H1" "$(hash_of "$TMP/$H1")"
# A template the installer used to overwrite outside the per-file logic: preview
# and upgrade summary must count it the same way (the first real 1.21.0 → HEAD
# preview said "29 to update" while the upgrade said "28 updated").
EX=".claude/commands.json.example"
printf '{"//": "an older example"}\n' > "$TMP/$EX"
set_baseline "$TMP" "$EX" "$(hash_of "$TMP/$EX")"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/.claude/hooks/retired-hook.sh"
printf '%s\t%s\n' "$(hash_of "$TMP/.claude/hooks/retired-hook.sh")" ".claude/hooks/retired-hook.sh" >> "$TMP/.kit-baseline"
python3 - "$TMP/.claude/settings.json" <<'PY'
import json, sys
f = sys.argv[1]
d = json.load(open(f))
for groups in d["hooks"].values():
    for g in groups:
        g["hooks"] = [h for h in g["hooks"] if "secret-scan.sh" not in h.get("command", "")]
d["hooks"].setdefault("PostToolUse", []).append(
    {"matcher": "Edit", "hooks": [{"type": "command", "command": ".claude/hooks/ghost.sh"}]})
json.dump(d, open(f, "w"), indent=2)
PY
BASELINE_BEFORE=$(hash_of "$TMP/.kit-baseline")
SETTINGS_BEFORE=$(hash_of "$TMP/.claude/settings.json")
if ( cd "$TMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --diff >"$TMP/.diff.log" 2>&1 ); then
  pass "--diff ran clean"
else
  fail "--diff failed"; tail -8 "$TMP/.diff.log"
fi
PREVIEW=$(sed "s/$(printf '\033')\[[0-9;]*m//g" "$TMP/.diff.log")
[[ "$PREVIEW" == *"Will be updated (2)"* && "$PREVIEW" == *"~ $H1"* && "$PREVIEW" == *"~ $EX"* ]] \
  && pass "--diff: the kit-changed hook and example will be updated" || fail "--diff did not plan exactly the updates of $H1 and $EX"
[[ "$PREVIEW" == *"Kept (2)"*"$H2"* ]] && pass "--diff: locally edited hooks are kept" || fail "--diff did not list the kept hooks"
for needle in "retired-hook.sh" ".claude/hooks/secret-scan.sh" ".claude/hooks/ghost.sh"; do
  [[ "$PREVIEW" == *"$needle"* ]] && pass "--diff reports $needle" || fail "--diff does not mention $needle"
done
if grep -q 'an older kit version' "$TMP/$H1" && [ "$(hash_of "$TMP/.kit-baseline")" = "$BASELINE_BEFORE" ] \
   && [ ! -e "$TMP/.kit-backup" ] && [ ! -e "$TMP/$H1.kit-new" ]; then
  pass "--diff changed nothing in the project"
else
  fail "--diff modified the project"
fi
( cd "$TMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --upgrade >"$TMP/.upgrade4.log" 2>&1 ) || fail "upgrade after the preview failed"
cmp -s "$KIT_ROOT/$H1" "$TMP/$H1" && cmp -s "$KIT_ROOT/$EX" "$TMP/$EX" \
  && pass "the previewed updates were applied" || fail "a previewed update was not applied"
[[ "$(upgrade_summary "$TMP/.upgrade4.log")" == *" 2 updated · 0 added · "* ]] \
  && pass "--upgrade counts exactly the 2 updates --diff previewed" || fail "upgrade summary differs from the preview: $(upgrade_summary "$TMP/.upgrade4.log")"
UPGRADE4=$(sed "s/$(printf '\033')\[[0-9;]*m//g" "$TMP/.upgrade4.log")
for needle in "retired-hook.sh" ".claude/hooks/secret-scan.sh" ".claude/hooks/ghost.sh"; do
  [[ "$UPGRADE4" == *"$needle"* ]] && pass "--upgrade reports $needle" || fail "--upgrade does not report $needle"
done
[ "$(hash_of "$TMP/.claude/settings.json")" = "$SETTINGS_BEFORE" ] \
  && pass "--upgrade left .claude/settings.json untouched" || fail "--upgrade modified .claude/settings.json"

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

# --- upgrade safety (TAN-6279): each case gets its own project under $XTMP ----
# kit <project> <log> [args…] — run this kit's install.sh in <project>.
kit() {
  local p="$1" log="$2"; shift 2
  ( cd "$p" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" "$@" >"$p/$log" 2>&1 < /dev/null )
}
# fresh <project> [args…] — a project with a fresh install of this kit.
fresh() {
  local p="$1"; shift
  mkdir -p "$p" && kit "$p" .install.log "$@"
}
# snap <dir> — every file (not following links) with its checksum; logs excluded.
snap() { find "$1" -type f ! -name '.*.log' -exec cksum {} + | LC_ALL=C sort; }
strip_log() { sed "s/$(printf '\033')\[[0-9;]*m//g" "$1"; }
# preview_counts <log> / upgrade_counts <log> — "updates adds conflicts"
preview_counts() {
  strip_log "$1" | awk '/ to update · / { print $1, $5, $9 } /Your installation is up to date/ { print 0, 0, 0 }'
}
upgrade_counts() { strip_log "$1" | awk '/Upgrade summary:/ { print $3, $6, $17 }'; }
# same_counts <project> <diff log> <upgrade log> <label>
same_counts() {
  local a b
  a=$(preview_counts "$1/$2"); b=$(upgrade_counts "$1/$3")
  if [ -n "$a" ] && [ "$a" = "$b" ]; then
    pass "$4: --diff and --upgrade agree ($a — updates adds conflicts)"
  else
    fail "$4: --diff said '${a:-?}', --upgrade did '${b:-?}' (updates adds conflicts)"
  fi
}

echo "== --diff never writes through a symlink (TAN-6279) =="
# The preview's scratch copy used to keep symlinks, so its upgrade wrote through
# .claude/hooks into the shared target — replacing an edit, with the backup left
# in the scratch dir and deleted.
P="$XTMP/linked"; SHARED="$XTMP/shared-hooks"
fresh "$P"
rm -f "$P/.kit-baseline"  # an install from before the record: changed files get replaced
mkdir -p "$SHARED" && mv "$P/.claude/hooks/"* "$SHARED/" && rmdir "$P/.claude/hooks" && ln -s "$SHARED" "$P/.claude/hooks"
echo '# my shared edit' >> "$SHARED/stop-gate.sh"
SHARED_BEFORE=$(snap "$SHARED"); PROJECT_BEFORE=$(snap "$P")
kit "$P" .diff.log --diff || fail "--diff failed on a symlinked .claude/hooks"
[ "$(snap "$SHARED")" = "$SHARED_BEFORE" ] && grep -q 'my shared edit' "$SHARED/stop-gate.sh" \
  && pass "--diff left the link's target untouched" || fail "--diff wrote through .claude/hooks into its target"
[ "$(snap "$P")" = "$PROJECT_BEFORE" ] && pass "--diff changed nothing in the project" || fail "--diff modified the project"
grep -q '.claude/hooks is a symlink — --upgrade writes through it' "$P/.diff.log" \
  && pass "--diff names the symlink --upgrade will write through" || fail "--diff does not mention the .claude/hooks symlink"
kit "$P" .upgrade.log --upgrade || fail "upgrade through a symlinked .claude/hooks failed"
same_counts "$P" .diff.log .upgrade.log "symlinked .claude/hooks"

echo "== --diff with CLAUDE.md -> AGENTS.md (TAN-6279) =="
P="$XTMP/agents-link"
fresh "$P"
rm -f "$P/.kit-baseline"
printf '# CLAUDE.md\n\nan older kit version\n' > "$P/AGENTS.md"
rm -f "$P/CLAUDE.md" && ln -s AGENTS.md "$P/CLAUDE.md"
kit "$P" .diff.log --diff || fail "--diff failed with CLAUDE.md -> AGENTS.md"
kit "$P" .upgrade.log --upgrade || fail "upgrade failed with CLAUDE.md -> AGENTS.md"
same_counts "$P" .diff.log .upgrade.log "CLAUDE.md -> AGENTS.md"
if grep -q '^ *~ AGENTS.md' <<<"$(strip_log "$P/.diff.log")"; then
  fail "--diff plans an update of AGENTS.md, which --upgrade never touches by that name"
else
  pass "--diff plans only the CLAUDE.md update"
fi

echo "== upgrade: a file with no entry in the record is replaced, with a backup (TAN-6279) =="
# The project had its own scripts/validate.sh; install skipped the existing
# scripts/, so .kit-baseline has no entry for it. A file without an entry can be
# a local edit, an older kit file or the project's own and they can't be told
# apart, so the kit's version lands and the previous copy is kept and named.
P="$XTMP/own-script"
mkdir -p "$P/scripts" && echo 'echo my own validate' > "$P/scripts/validate.sh"
cp "$P/scripts/validate.sh" "$XTMP/own-validate.sh"
fresh "$P"
kit "$P" .diff.log --diff || fail "--diff failed with an own scripts/validate.sh"
kit "$P" .upgrade.log --upgrade || fail "upgrade failed with an own scripts/validate.sh"
cmp -s "$KIT_ROOT/scripts/validate.sh" "$P/scripts/validate.sh" && pass "the kit's scripts/validate.sh lands" \
  || fail "scripts/validate.sh was not updated"
OWN_BACKUP=$(find "$P/.kit-backup" -type f -name validate.sh 2>/dev/null | head -n 1)
[ -n "$OWN_BACKUP" ] && cmp -s "$XTMP/own-validate.sh" "$OWN_BACKUP" && pass "the previous copy is in .kit-backup/" \
  || fail "no backup of the replaced scripts/validate.sh"
grep -q "the install record doesn't list it; your copy is in .kit-backup/" "$P/.upgrade.log" \
  && pass "the log names the file and where its copy went" || fail "the log doesn't name the backup"
same_counts "$P" .diff.log .upgrade.log "a file with no entry in the record"
kit "$P" .upgrade2.log --upgrade || fail "second upgrade failed"
[[ "$(upgrade_counts "$P/.upgrade2.log")" == "0 0 0" ]] && pass "the next upgrade is quiet" \
  || fail "next upgrade: $(upgrade_counts "$P/.upgrade2.log")"

echo "== the stale report never calls the project's own files the kit's (TAN-6279) =="
# Older installs recorded every existing script and skill in .kit-manifest, so a
# pre-baseline --diff told users to remove their own files.
P="$XTMP/own-listed"
mkdir -p "$P/scripts" "$P/.claude/skills/my-own-skill"
echo 'echo deploy' > "$P/scripts/deploy.sh"; echo '# mine' > "$P/.claude/skills/my-own-skill/SKILL.md"
fresh "$P"
stale_list() {  # <log> — the items of the "remove them" section
  strip_log "$1" | awk '/remove them if nothing uses them/ { f = 1; next } f && /^ +- / { print; next } { f = 0 }'
}
# With .kit-baseline: install skipped the existing .claude/skills/, but .kit-manifest lists my-own-skill.
kit "$P" .diff.log --diff || fail "--diff failed"
[[ "$(stale_list "$P/.diff.log")" != *my-own-skill* ]] && pass "baseline install: own skill not called stale" \
  || fail "baseline install: --diff says to remove the project's own .claude/skills/my-own-skill"
# Without it (an install from before the record), as 1.21.0 left the manifest:
rm -f "$P/.kit-baseline"
printf 'scripts/deploy.sh\n.claude/skills/my-own-skill\n' >> "$P/.kit-manifest"
kit "$P" .diff2.log --diff || fail "--diff failed"
STALE=$(stale_list "$P/.diff2.log")
[[ "$STALE" != *deploy.sh* && "$STALE" != *my-own-skill* ]] && pass "pre-baseline install: own files not called stale" \
  || fail "pre-baseline install: --diff says to remove the project's own files: $(echo $STALE)"
grep -q 'may be your own' "$P/.diff2.log" && grep -q 'scripts/deploy.sh' "$P/.diff2.log" \
  && pass "pre-baseline install: listed paths shown, hedged" || fail "pre-baseline install: listed paths not shown with hedged wording"

echo "== upgrade keeps CLAUDE.md's own template (TAN-6279) =="
# A generic install from before .kit-baseline, retitled by the user, then the
# project gains a package.json: the upgrade used to auto-detect node-api, replace
# CLAUDE.md and record #template node-api for good.
P="$XTMP/retitled"
fresh "$P"
rm -f "$P/.kit-baseline"
awk 'NR == 1 { $0 = "# CLAUDE.md — Acme Billing" } { print }' "$P/CLAUDE.md" > "$P/CLAUDE.md.tmp" && mv "$P/CLAUDE.md.tmp" "$P/CLAUDE.md"
echo '- Acme rule: never touch the ledger' >> "$P/CLAUDE.md"
cp "$P/CLAUDE.md" "$XTMP/retitled-claude.md"
echo '{"name":"acme","version":"1.0.0"}' > "$P/package.json"
kit "$P" .diff.log --diff || fail "--diff failed"
kit "$P" .upgrade.log --upgrade || fail "upgrade failed"
cmp -s "$XTMP/retitled-claude.md" "$P/CLAUDE.md" && pass "a CLAUDE.md of unknown template is left untouched" \
  || fail "upgrade replaced a retitled CLAUDE.md ($(head -n 1 "$P/CLAUDE.md"))"
grep -q 'Auto-detected template' "$P/.upgrade.log" && fail "upgrade auto-detected a template for an existing CLAUDE.md" \
  || pass "no template auto-detected for an existing CLAUDE.md"
grep -q '^#template' "$P/.kit-baseline" && fail ".kit-baseline records a template: $(grep '^#template' "$P/.kit-baseline")" \
  || pass "no template recorded for it"
grep -q 'CLAUDE.md left untouched' "$P/.upgrade.log" && grep -q 'CLAUDE.md left untouched' "$P/.diff.log" \
  && pass "--diff and --upgrade both say why CLAUDE.md is untouched" || fail "CLAUDE.md skipped silently"
same_counts "$P" .diff.log .upgrade.log "retitled CLAUDE.md"

echo "== --upgrade counts every file it creates (TAN-6279) =="
P="$XTMP/add-wiki"
fresh "$P"
kit "$P" .diff.log --wiki --diff || fail "--wiki --diff failed"
kit "$P" .upgrade.log --wiki --upgrade || fail "--wiki --upgrade failed"
[ "$(preview_counts "$P/.diff.log" | awk '{ print $2 }')" -gt 0 ] 2>/dev/null && pass "adding --wiki adds files" || fail "adding --wiki added nothing"
same_counts "$P" .diff.log .upgrade.log "standard, then --wiki"
P="$XTMP/add-standard"
fresh "$P" --profile minimal
kit "$P" .diff.log --diff || fail "--diff failed"
kit "$P" .upgrade.log --upgrade || fail "upgrade failed"
same_counts "$P" .diff.log .upgrade.log "minimal, then standard"
kit "$P" .diff2.log --diff && grep -q 'Your installation is up to date' "$P/.diff2.log" \
  && pass "minimal, then standard: next --diff is up to date" || fail "minimal, then standard: next --diff is not up to date"

echo "== --diff with a relative --local path (TAN-6279) =="
# The preview's nested run works from its scratch dir, where ../cck-kit is gone.
P="$XTMP/relative"
ln -s "$KIT_ROOT" "$XTMP/cck-kit"
fresh "$P"
if ( cd "$P" && bash ../cck-kit/install.sh --local ../cck-kit --diff >"$P/.diff.log" 2>&1 < /dev/null ) \
   && grep -q 'Your installation is up to date' "$P/.diff.log"; then
  pass "--diff works with --local ../cck-kit"
else
  fail "--diff with a relative --local failed"; tail -3 "$P/.diff.log"
fi

echo "== --upgrade and --diff refuse to run without a hash tool (TAN-6279) =="
# An upgrade without one replaced files but recorded no hashes, leaving stale
# baseline entries that caused false conflicts later.
SHIM="$XTMP/nohash-bin"; mkdir -p "$SHIM"
OLDIFS=$IFS; IFS=:
for d in $PATH; do
  [ -d "$d" ] || continue
  for f in "$d"/*; do
    n=${f##*/}
    case "$n" in sha256sum|shasum*|python|python3*) continue ;; esac
    [ -x "$f" ] && [ ! -e "$SHIM/$n" ] && ln -s "$f" "$SHIM/$n"
  done
done
IFS=$OLDIFS
P="$XTMP/nohash"
fresh "$P"
printf '#!/usr/bin/env bash\n# an older kit version\n' > "$P/.claude/hooks/secret-scan.sh"
BEFORE=$(snap "$P")
if ( cd "$P" && env PATH="$SHIM" bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --upgrade >"$P/.upgrade.log" 2>&1 < /dev/null ); then
  fail "--upgrade ran without a hash tool"
else
  pass "--upgrade stops without a hash tool"
fi
grep -q 'No sha256 tool found' "$P/.upgrade.log" && pass "it says why" || fail "no message about the missing hash tool";
[ "$(snap "$P")" = "$BEFORE" ] && pass "nothing in the project changed" || fail "--upgrade without a hash tool changed the project"
( cd "$P" && env PATH="$SHIM" bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --diff >"$P/.diff.log" 2>&1 < /dev/null ) \
  && fail "--diff ran without a hash tool" || pass "--diff stops without a hash tool"
P="$XTMP/nohash-fresh"; mkdir -p "$P"
if ( cd "$P" && env PATH="$SHIM" bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" >"$P/.install.log" 2>&1 < /dev/null ); then
  pass "a fresh install still works without a hash tool"
else
  fail "a fresh install failed without a hash tool"; tail -3 "$P/.install.log"
fi
assert_absent "$P/.kit-baseline"
grep -q '.kit-baseline not written' "$P/.install.log" && pass "it warns that no baseline was written" || fail "no warning about the missing baseline"

echo "== a waiting .kit-new is never overwritten (TAN-6279) =="
P="$XTMP/kit-new"
fresh "$P"
echo '# my local tweak' >> "$P/$H3"
set_baseline "$P" "$H3" "$(hash_of "$P/VERSION")"  # the kit last shipped something else here
echo 'my half-done merge' > "$P/$H3.kit-new"
kit "$P" .diff.log --diff || fail "--diff failed"
kit "$P" .upgrade.log --upgrade || fail "upgrade failed"
grep -q 'my half-done merge' "$P/$H3.kit-new" && pass "the earlier .kit-new is untouched" || fail "upgrade overwrote $H3.kit-new"
cmp -s "$KIT_ROOT/$H3" "$P/$H3.kit-new.1" && pass "the kit's version went to .kit-new.1" || fail "no $H3.kit-new.1 with the kit's version"
grep -q "$H3.kit-new.1" "$P/.upgrade.log" && pass "the upgrade names .kit-new.1" || fail "the upgrade doesn't say where the kit's version went"
same_counts "$P" .diff.log .upgrade.log "earlier .kit-new"

echo "== a plain re-run over an older install doesn't freeze kit files (TAN-6279) =="
# Such a re-run records only the two or three files it copied. Reading that as
# "the kit wrote everything it lists" would leave every other kit file behind.
P="$XTMP/rerun-partial"
fresh "$P"
rm -f "$P/.kit-baseline"  # an install from before the record
printf '#!/usr/bin/env bash\n# an older kit version\n' > "$P/.claude/hooks/secret-scan.sh"
printf '# an older kit version\n' > "$P/agent_docs/hooks.md"
kit "$P" .rerun.log --profile minimal || fail "a plain re-run failed"
kit "$P" .upgrade.log --upgrade || fail "the upgrade after the re-run failed"
cmp -s "$KIT_ROOT/.claude/hooks/secret-scan.sh" "$P/.claude/hooks/secret-scan.sh" \
  && cmp -s "$KIT_ROOT/agent_docs/hooks.md" "$P/agent_docs/hooks.md" \
  && pass "the kit's own files are updated" || fail "kit files were left behind after a partial record"
[ -z "$(find "$P" -name '*.kit-new*')" ] && pass "no .kit-new was written for them" \
  || fail "the upgrade wrote .kit-new files for the kit's own files"
kit "$P" .upgrade2.log --upgrade || fail "the second upgrade failed"
[[ "$(upgrade_counts "$P/.upgrade2.log")" == "0 0 0" ]] && pass "and the next upgrade is quiet" \
  || fail "next upgrade: $(upgrade_counts "$P/.upgrade2.log")"

echo "== a module the record doesn't list is updated too (TAN-6279) =="
# A plain upgrade records the core kit; WIKI.md and ARTIFACTS.md aren't in it.
P="$XTMP/module-cover"
fresh "$P" --wiki --html
rm -f "$P/.kit-baseline"
printf '# an older kit version\n' > "$P/WIKI.md"
printf '# an older kit version\n' > "$P/ARTIFACTS.md"
kit "$P" .upgrade1.log --upgrade || fail "the plain upgrade failed"
kit "$P" .upgrade2.log --upgrade --wiki --html || fail "the module upgrade failed"
cmp -s "$KIT_ROOT/WIKI.md" "$P/WIKI.md" && cmp -s "$KIT_ROOT/ARTIFACTS.md" "$P/ARTIFACTS.md" \
  && pass "module files are updated" || fail "module files were left behind"
[ -z "$(find "$P" -maxdepth 1 -name '*.kit-new*')" ] && pass "no .kit-new for them either" \
  || fail "the upgrade wrote .kit-new files for module files"

echo "== a CLAUDE.md the kit never wrote is never replaced (TAN-6279) =="
# Claude Code's /init writes a CLAUDE.md whose first line is "# CLAUDE.md" too,
# so a first line alone used to "identify" it as the kit's generic template.
P="$XTMP/init-claude"
fresh "$P"
rm -f "$P/.kit-baseline"
printf '# CLAUDE.md\n\nThis file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.\n\n## My own rules\n' > "$P/CLAUDE.md"
cp "$P/CLAUDE.md" "$XTMP/init-claude.md"
kit "$P" .diff.log --diff || fail "--diff failed"
kit "$P" .upgrade.log --upgrade || fail "the upgrade failed"
cmp -s "$XTMP/init-claude.md" "$P/CLAUDE.md" && pass "a CLAUDE.md written by /init survives the upgrade" \
  || fail "the upgrade replaced a CLAUDE.md the kit never wrote"
grep -q "none of the kit's sections" "$P/.upgrade.log" && grep -q "none of the kit's sections" "$P/.diff.log" \
  && pass "--diff and --upgrade both say why" || fail "neither run says why CLAUDE.md was left alone"
same_counts "$P" .diff.log .upgrade.log "a CLAUDE.md of the user's own"

echo "== a broken *.sh link of your own doesn't stop the upgrade (TAN-6279) =="
# chmod +x over .claude/hooks/*.sh and scripts/*.sh used to take the run down
# halfway, every time, while --diff reported success.
P="$XTMP/dangling-own"
fresh "$P"
ln -s ../../nowhere.sh "$P/.claude/hooks/zz-mine.sh"
ln -s ../nowhere.sh "$P/scripts/zz-mine.sh"
printf '#!/usr/bin/env bash\n# an older kit version\n' > "$P/.claude/hooks/secret-scan.sh"
set_baseline "$P" ".claude/hooks/secret-scan.sh" "$(hash_of "$P/.claude/hooks/secret-scan.sh")"
kit "$P" .diff.log --diff || fail "--diff failed"
kit "$P" .upgrade.log --upgrade || fail "the upgrade stopped on a broken *.sh link"
grep -q 'Upgrade complete' "$P/.upgrade.log" && pass "the upgrade ran to the end" || fail "the upgrade stopped halfway"
cmp -s "$KIT_ROOT/.claude/hooks/secret-scan.sh" "$P/.claude/hooks/secret-scan.sh" && pass "and did its work" \
  || fail "the upgrade didn't update the hook"
same_counts "$P" .diff.log .upgrade.log "a broken *.sh link of your own"

echo "== an upgrade doesn't write through a hard link (TAN-6279) =="
# Writing into the existing file reached every other name for that inode, so an
# edit the user had made through their own path was lost from both.
P="$XTMP/hardlink"
fresh "$P"
rm -f "$P/.kit-baseline"
printf '#!/usr/bin/env bash\n# an older kit version\n' > "$P/.claude/hooks/auto-format.sh"
mkdir -p "$P/tools" && ln "$P/.claude/hooks/auto-format.sh" "$P/tools/fmt.sh"
echo '# my edit through tools/fmt.sh' >> "$P/tools/fmt.sh"
kit "$P" .upgrade.log --upgrade || fail "the upgrade failed"
grep -q 'my edit through tools/fmt.sh' "$P/tools/fmt.sh" && pass "the user's other name for the file keeps its content" \
  || fail "the upgrade wrote through a hard link"
cmp -s "$KIT_ROOT/.claude/hooks/auto-format.sh" "$P/.claude/hooks/auto-format.sh" && pass "the kit file is updated" \
  || fail "the kit file was left stale"

echo "== .NET below the root (TAN-6279) =="
P="$XTMP/dotnet-nested"
mkdir -p "$P/src/App" && echo '<Project Sdk="Microsoft.NET.Sdk" />' > "$P/src/App/App.csproj"
fresh "$P"
cmp -s "$KIT_ROOT/examples/dotnet/CLAUDE.md" "$P/CLAUDE.md" && pass "src/App/App.csproj gets the dotnet template" \
  || fail "src/App/App.csproj did not get the dotnet template ($(head -n 1 "$P/CLAUDE.md"))"
P="$XTMP/dotnet-node"
mkdir -p "$P/src/App" && echo '<Project Sdk="Microsoft.NET.Sdk" />' > "$P/src/App/App.csproj"
echo '{"name":"front","version":"1.0.0"}' > "$P/package.json"
fresh "$P"
cmp -s "$KIT_ROOT/examples/node-api/CLAUDE.md" "$P/CLAUDE.md" && pass "a root package.json still wins over a nested .csproj" \
  || fail "a nested .csproj overrode the root package.json"

echo ""
if [ "$FAILS" -eq 0 ]; then
  echo "install-test: ALL PASS"
else
  echo "install-test: $FAILS FAIL"
  exit 1
fi
