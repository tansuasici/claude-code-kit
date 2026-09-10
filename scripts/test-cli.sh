#!/usr/bin/env bash
#
# test-cli.sh — smoke test for bin/cli.sh, the npx entry point.
#
# test-install.sh exercises install.sh directly; this drives the CLI wrapper the
# way `npx @tansuasici/claude-code-kit <cmd>` does, so every subcommand
# (init, doctor, skills, convert, generate agents-md, --version) runs at least
# once and a broken subcommand fails the suite. CI runs it on ubuntu + macOS.
#
# Exit codes: 0 all assertions passed · 1 one or more failed
#

set -uo pipefail

KIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI="$KIT_ROOT/bin/cli.sh"
FAILS=0
pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; FAILS=$((FAILS + 1)); }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/cck-cli-test.XXXXXX")"
STMP="$(mktemp -d "${TMPDIR:-/tmp}/cck-cli-strict.XXXXXX")"
trap 'rm -rf "$TMP" "$STMP"' EXIT

# --- version (no install needed) --------------------------------------------
echo "== version =="
EXPECTED_VERSION="$(sed 's/ *#.*//' "$KIT_ROOT/VERSION" | tr -d '[:space:]')"
for flag in --version version -v; do
  got="$(bash "$CLI" "$flag" 2>/dev/null | tr -d '[:space:]')"
  [ "$got" = "$EXPECTED_VERSION" ] && pass "$flag -> $got" || fail "$flag -> '$got' (expected '$EXPECTED_VERSION')"
done

# --- help / unknown command --------------------------------------------------
echo "== help / unknown =="
CLI_HELP=$(bash "$CLI" --help 2>/dev/null || true)
grep -q "Usage:" <<< "$CLI_HELP" && pass "--help prints usage" || fail "--help missing usage"
if bash "$CLI" definitely-not-a-command >/dev/null 2>&1; then
  fail "unknown command exited 0"
else
  pass "unknown command exits non-zero"
fi

# --- subcommands that need an install must fail cleanly BEFORE init ----------
echo "== pre-install error paths =="
( cd "$TMP" && bash "$CLI" doctor >/dev/null 2>&1 ) && fail "doctor exited 0 with no install" || pass "doctor fails before init"
( cd "$TMP" && bash "$CLI" skills >/dev/null 2>&1 ) && fail "skills exited 0 with no install" || pass "skills fails before init"

# --- init (standard) — must match a direct install.sh run -------------------
echo "== init =="
echo '{"name":"cli-fixture","version":"1.0.0"}' > "$TMP/package.json"
if ( cd "$TMP" && bash "$CLI" init >"$TMP/.init.log" 2>&1 ); then
  pass "init ran clean"
else
  fail "init failed"; tail -8 "$TMP/.init.log"
fi
for f in CLAUDE.md .claude/settings.json .kit-manifest scripts/doctor.sh; do
  [ -e "$TMP/$f" ] && pass "init created $f" || fail "init missing $f"
done
[ -d "$TMP/.claude/skills" ] && pass "init created .claude/skills/" || fail "init missing skills dir"

# --- doctor (healthy install → exit 0) --------------------------------------
echo "== doctor =="
( cd "$TMP" && bash "$CLI" doctor >/dev/null 2>&1 ) && pass "doctor healthy after init" || fail "doctor failed on healthy install"

# --- skills (lists a count matching the installed skill dirs) ---------------
echo "== skills =="
skills_out="$( cd "$TMP" && bash "$CLI" skills 2>/dev/null )"
cli_count="$(printf '%s\n' "$skills_out" | grep -oE '[0-9]+ skills' | grep -oE '[0-9]+' | head -1)"
dir_count=0
for d in "$TMP/.claude/skills"/*/; do
  [ -d "$d" ] || continue
  case "$(basename "$d")" in _*) continue ;; esac
  [ -f "${d}SKILL.md" ] && dir_count=$((dir_count + 1))
done
if [ -n "$cli_count" ] && [ "$cli_count" -gt 0 ] && [ "$cli_count" = "$dir_count" ]; then
  pass "skills lists $cli_count (matches installed dirs)"
else
  fail "skills count '$cli_count' != installed dir count '$dir_count'"
fi

# --- generate agents-md → non-empty AGENTS.md -------------------------------
echo "== generate agents-md =="
( cd "$TMP" && bash "$CLI" generate agents-md >/dev/null 2>&1 ) && pass "generate agents-md ran" || fail "generate agents-md failed"
[ -s "$TMP/AGENTS.md" ] && pass "AGENTS.md is non-empty" || fail "AGENTS.md missing/empty"

# --- convert codex → AGENTS.md + .agents/skills/ ----------------------------
echo "== convert codex =="
( cd "$TMP" && bash "$CLI" convert codex >/dev/null 2>&1 ) && pass "convert codex ran" || fail "convert codex failed"
[ -s "$TMP/AGENTS.md" ] && pass "convert produced non-empty AGENTS.md" || fail "convert AGENTS.md missing/empty"
[ -d "$TMP/.agents/skills" ] && pass "convert produced .agents/skills/" || fail ".agents/skills/ missing"

# --- flag pass-through: init --profile strict reaches install.sh ------------
echo "== init --profile strict (flag pass-through) =="
echo '{"name":"cli-strict","version":"1.0.0"}' > "$STMP/package.json"
if ( cd "$STMP" && bash "$CLI" init --profile strict >"$STMP/.init.log" 2>&1 ); then
  pass "init --profile strict ran clean"
else
  fail "init --profile strict failed"; tail -8 "$STMP/.init.log"
fi
grep -q skill-extract-reminder.sh "$STMP/.claude/settings.json" 2>/dev/null \
  && pass "strict flag reached install.sh (strict-only hook present)" \
  || fail "strict flag not honored via CLI"

echo ""
if [ "$FAILS" -eq 0 ]; then
  echo "cli-test: ALL PASS"
else
  echo "cli-test: $FAILS FAIL"
  exit 1
fi
