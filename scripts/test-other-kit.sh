#!/usr/bin/env bash
#
# test-other-kit.sh — install.sh and uninstall.sh next to another Claude kit
#
# Usage: bash scripts/test-other-kit.sh
#        OTHER_KITS=/dir bash scripts/test-other-kit.sh
#
# The other kit is faked: the two files only it ships and a CLAUDE.md are all
# the check looks at, and all a refused run must leave alone.
#
# With OTHER_KITS set to a folder holding checkouts named marketing, design and
# research, the last section also runs their real installers, in both orders.
# CI doesn't, so its result doesn't depend on those repos' main branches.
#
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

KIT="$PWD"
pass=0; fail=0
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n%s\n' "$1" "$2"; }

fresh_dir() { mktemp -d "$work/repo.XXXXXX"; }

KITS=(marketing design research)
PROFILES=(minimal standard strict)

# This kit installs into the current folder; no terminal, so no prompt can wait.
install_here()   { local d="$1"; shift; (cd "$d" && bash "$KIT/install.sh" --local "$KIT" "$@") </dev/null 2>&1; }
uninstall_here() { local d="$1"; shift; (cd "$d" && bash "$KIT/uninstall.sh" "$@") </dev/null 2>&1; }

# add_other_kit DIR KIT → DIR now also holds the two files only that kit ships
add_other_kit() {
  mkdir -p "$1/.claude/hooks"
  case "$2" in
    marketing) printf 'x\n' | tee "$1/MARKETING_MAP.md" > "$1/.claude/hooks/claim-scan.sh" ;;
    design)    printf 'x\n' | tee "$1/DESIGN_MAP.md" > "$1/.claude/hooks/motion-gate.sh" ;;
    research)  printf 'x\n' | tee "$1/MANUSCRIPT_MAP.md" > "$1/.claude/hooks/citation-gate.sh" ;;
  esac
}

# other_kit KIT → a folder that looks like another kit's install
other_kit() {
  local d; d=$(fresh_dir)
  add_other_kit "$d" "$1"
  printf 'other kit rules\n' > "$d/CLAUDE.md"
  printf 'other kit hook\n' > "$d/.claude/hooks/session-start.sh"
  printf '%s' "$d"
}

snapshot() { (cd "$1" && find . -type f -exec cksum {} + | LC_ALL=C sort); }

# refuses LABEL install_here|uninstall_here DIR [FLAGS…] → exit 2, the reason on stderr, the folder untouched
refuses() {
  local label="$1" run="$2" dir="$3"; shift 3
  local before out code
  before=$(snapshot "$dir")
  out=$("$run" "$dir" "$@"); code=$?
  if [ "$code" -eq 2 ] && [[ "$out" == *"another Claude kit"* ]] && [ "$(snapshot "$dir")" = "$before" ]; then
    ok "$label"
  else
    bad "$label" "  exit=$code: $out"
  fi
}

# passes LABEL EXIT OUTPUT [TEST…] → EXIT is 0 and the test command, if any, holds
passes() {
  local label="$1" code="$2" output="$3"; shift 3
  if [ "$code" -eq 0 ] && { [ $# -eq 0 ] || "$@"; }; then ok "$label"; else bad "$label" "  exit=$code: $output"; fi
}
has()     { [ -e "$1" ]; }
gone()    { [ ! -e "$1" ]; }
is_mine() { [ "$(cat "$1")" = "mine" ]; }

echo "install refuses another kit's folder"
for kit in "${KITS[@]}"; do
  refuses "install: $kit" install_here "$(other_kit "$kit")"
done
for profile in "${PROFILES[@]}"; do
  refuses "install --profile $profile" install_here "$(other_kit marketing)" --profile "$profile"
done
refuses "install --upgrade" install_here "$(other_kit marketing)" --upgrade
refuses "install --diff"    install_here "$(other_kit marketing)" --diff

d=$(other_kit marketing); before=$(snapshot "$d")
out=$(cd "$d" && bash "$KIT/bin/cli.sh" init </dev/null 2>&1); code=$?
if [ "$code" -eq 2 ] && [ "$(snapshot "$d")" = "$before" ]; then ok "the npx entry point exits 2 too"; else bad "the npx entry point exits 2 too" "  exit=$code: $out"; fi

echo "uninstall refuses another kit's folder"
for kit in "${KITS[@]}"; do
  refuses "uninstall: $kit" uninstall_here "$(other_kit "$kit")" --force
done
refuses "uninstall --dry-run"      uninstall_here "$(other_kit marketing)" --dry-run
refuses "uninstall --keep-project" uninstall_here "$(other_kit marketing)" --force --keep-project

echo "uninstall and upgrade refuse when both kits are here"
for kit in "${KITS[@]}"; do
  d=$(fresh_dir); install_here "$d" >/dev/null; add_other_kit "$d" "$kit"
  refuses "uninstall: this kit and $kit" uninstall_here "$d" --force
  refuses "upgrade: this kit and $kit"   install_here   "$d" --upgrade
done

echo "not another kit: a map or a hook alone"
for map in MARKETING_MAP.md DESIGN_MAP.md MANUSCRIPT_MAP.md; do
  d=$(fresh_dir); printf 'mine\n' > "$d/$map"
  out=$(install_here "$d"); code=$?
  passes "a repo's own $map installs" "$code" "$out" has "$d/.claude/hooks/secret-scan.sh"
  out=$(install_here "$d" --upgrade); code=$?
  passes "and this kit upgrades next to it" "$code" "$out"
  out=$(uninstall_here "$d" --force); code=$?
  passes "and uninstalls next to it" "$code" "$out" gone "$d/.claude/hooks/secret-scan.sh"
  passes "and it stays" 0 "" is_mine "$d/$map"
done

d=$(fresh_dir); mkdir -p "$d/.claude/hooks"; printf 'mine\n' > "$d/.claude/hooks/session-start.sh"
out=$(install_here "$d"); code=$?
passes "a repo's own session-start hook installs" "$code" "$out" has "$d/CLAUDE.md"
passes "and stays" 0 "" is_mine "$d/.claude/hooks/session-start.sh"

echo "the subfolder the message points at"
d=$(other_kit marketing); before=$(snapshot "$d")
msg=$(install_here "$d")
if [[ "$msg" == *"mkdir -p code"* ]]; then ok "the refusal names the subfolder"; else bad "the refusal names the subfolder" "  $msg"; fi
mkdir -p "$d/code"
out=$(install_here "$d/code"); code=$?
passes "installs into the subfolder" "$code" "$out" has "$d/code/.claude/hooks/secret-scan.sh"
out=$(install_here "$d/code" --upgrade); code=$?
passes "upgrades in the subfolder" "$code" "$out"
out=$(uninstall_here "$d/code" --force); code=$?
passes "uninstalls from the subfolder" "$code" "$out" gone "$d/code/CLAUDE.md"
rm -rf "$d/code"
if [ "$(snapshot "$d")" = "$before" ]; then ok "the root kit is untouched"; else bad "the root kit is untouched" "  root changed"; fi

echo "this kit alone still installs, upgrades, previews and uninstalls"
for profile in "${PROFILES[@]}"; do
  d=$(fresh_dir)
  out=$(install_here "$d" --profile "$profile"); code=$?
  passes "$profile: install" "$code" "$out" has "$d/.claude/hooks/commit-gate.sh"
  out=$(install_here "$d" --upgrade --profile "$profile"); code=$?
  passes "$profile: upgrade" "$code" "$out"
  out=$(install_here "$d" --diff --profile "$profile"); code=$?
  passes "$profile: --diff" "$code" "$out"
  out=$(uninstall_here "$d" --force); code=$?
  passes "$profile: uninstall" "$code" "$out" gone "$d/.claude/hooks/secret-scan.sh"
done

echo "the way out the uninstall message gives"
d=$(other_kit marketing)
mv "$d/MARKETING_MAP.md" "$work/moved.md"
out=$(uninstall_here "$d" --force --keep-tasks --keep-project); code=$?
mv "$work/moved.md" "$d/MARKETING_MAP.md"
passes "moving the map aside lets it run" "$code" "$out" has "$d/MARKETING_MAP.md"

if [ -z "${OTHER_KITS:-}" ]; then
  echo "real kits: skipped, OTHER_KITS is not set"
else
  install_other() { local kit="$1" dir="$2"; shift 2; bash "$OTHER_KITS/$kit/install.sh" "$dir" "$@" </dev/null >/dev/null 2>&1; }
  marker() {
    case "$1" in
      marketing) echo MARKETING_MAP.md ;;
      design)    echo DESIGN_MAP.md ;;
      research)  echo MANUSCRIPT_MAP.md ;;
    esac
  }

  echo "real kits, in both orders"
  for kit in "${KITS[@]}"; do
    d=$(fresh_dir); git -C "$d" init -q
    if ! install_other "$kit" "$d"; then bad "$kit installs" "  exit=$?"; continue; fi
    for profile in "${PROFILES[@]}"; do
      refuses "$kit first: install --profile $profile" install_here "$d" --profile "$profile"
    done
    refuses "$kit first: uninstall" uninstall_here "$d" --force

    for profile in "${PROFILES[@]}"; do
      d=$(fresh_dir); git -C "$d" init -q; install_here "$d" --profile "$profile" >/dev/null
      before=$(snapshot "$d")
      install_other "$kit" "$d"; code=$?
      if [ "$code" -eq 2 ] && [ "$(snapshot "$d")" = "$before" ]; then
        ok "this kit first ($profile): $kit refuses and changes nothing"
      else
        bad "this kit first ($profile): $kit refuses and changes nothing" "  exit=$code"
      fi

      # Two kits in one folder, as an installer without this check left them. The
      # overlay and task files are the first kit's: installers keep those.
      d=$(fresh_dir); git -C "$d" init -q; install_other "$kit" "$d"
      before=$(snapshot "$d")
      mine=$(fresh_dir); install_here "$mine" --profile "$profile" >/dev/null
      rsync -a --exclude CLAUDE.project.md --exclude linear.md --exclude tasks "$mine/" "$d/"
      refuses "$kit and this kit ($profile): uninstall" uninstall_here "$d" --force
      refuses "$kit and this kit ($profile): upgrade"   install_here   "$d" --upgrade

      # The way out the message gives, followed to the end.
      mark=$(marker "$kit")
      mv "$d/$mark" "$work/moved"
      out=$(uninstall_here "$d" --force --keep-tasks --keep-project); code=$?
      mkdir -p "$(dirname "$d/$mark")"; mv "$work/moved" "$d/$mark"
      passes "$kit and this kit ($profile): the way out removes this kit" "$code" "$out" gone "$d/.claude/hooks/secret-scan.sh"
      install_other "$kit" "$d" --force; code=$?
      missing=$(LC_ALL=C comm -13 <(snapshot "$d") <(printf '%s\n' "$before"))
      if [ "$code" -eq 0 ] && [ -z "$missing" ]; then
        ok "$kit and this kit ($profile): rerunning $kit's installer with --force restores all its files"
      else
        bad "$kit and this kit ($profile): rerunning $kit's installer with --force restores all its files" "  exit=$code, missing or changed: $missing"
      fi
    done
  done
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
