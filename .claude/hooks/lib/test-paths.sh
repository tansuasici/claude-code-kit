#!/usr/bin/env bash
#
# test-paths.sh — "is this a test file?" and "does this source file have one?"
#
# Source it:  source "$HOOK_LIB/test-paths.sh"
#
#   is_test_file <path>           0 when the path is a test by convention
#   test_source_candidate <path>  0 when the path is source we expect a test for
#   test_exists_for <path>        0 when a test file for <path> exists on disk
#
# One rule, asked in one direction. A test "belongs to" a source file when its
# name follows that language's convention for the source's stem — `calc.ts` →
# `calc.test.ts`, `calc.py` → `test_calc.py`, `calc.go` → `calc_test.go`. The
# reverse question (which sources does THIS test cover?) is never asked: the
# caller re-asks test_exists_for for each file it is tracking instead, so there
# is a single matching rule to get wrong.
#
# Convention only — file names and directory layout. Nothing here reads file
# content: a test that exists but asserts nothing is a problem for the test
# runner, not for a path check, and reading edited files in a PostToolUse hook
# would cost an I/O per edit for a worse answer.
#
# Deliberately conservative: when a language has no path convention for tests,
# its files are not candidates at all. A false "this file owes a test" is the
# expensive error — under the strict profile it blocks completion — while a
# false "it has one" only means the nudge stays quiet.
#
#   Not candidates: shell (no convention, and the kit's own hooks are shell),
#   Rust (`#[cfg(test)]` lives inside the source file, indistinguishable by
#   path), and everything the quality gate already treats as non-code.
#

# Extensions whose tests have a path convention, and the candidate names for a
# stem in each. Kept as a case block rather than an associative array: bash 3.2.
# _tp_candidates <stem> <ext> — prints one candidate file name per line.
_tp_candidates() {
  local stem="$1" ext="$2" e kind
  case "$ext" in
    ts|tsx|js|jsx|mjs|cjs|mts|cts)
      for kind in test spec; do
        for e in ts tsx js jsx mjs cjs mts cts; do
          printf '%s.%s.%s\n' "$stem" "$kind" "$e"
        done
      done
      # A file of the same name inside a test directory counts too
      # (tests/calc.ts next to src/calc.ts).
      for e in ts tsx js jsx mjs cjs mts cts; do
        printf '%s.%s\n' "$stem" "$e"
      done
      ;;
    py)    printf 'test_%s.py\n%s_test.py\n' "$stem" "$stem" ;;
    go)    printf '%s_test.go\n' "$stem" ;;
    cs)    printf '%sTests.cs\n%sTest.cs\n' "$stem" "$stem" ;;
    java)  printf '%sTest.java\n%sTests.java\n%sIT.java\n' "$stem" "$stem" "$stem" ;;
    kt)    printf '%sTest.kt\n%sTests.kt\n' "$stem" "$stem" ;;
    rb)    printf '%s_spec.rb\n%s_test.rb\n' "$stem" "$stem" ;;
    php)   printf '%sTest.php\n' "$stem" ;;
    swift) printf '%sTests.swift\n%sTest.swift\n' "$stem" "$stem" ;;
    *)     return 1 ;;
  esac
}

is_test_file() {
  local path="$1" base
  base=$(basename "$path")
  case "$base" in
    *.test.*|*.spec.*|*_test.*|*-test.*|test_*.py|conftest.py) return 0 ;;
    *Test.cs|*Tests.cs|*Test.java|*Tests.java|*IT.java|*Test.kt|*Tests.kt) return 0 ;;
    *_spec.rb|*Test.php|*Tests.swift|*Test.swift) return 0 ;;
  esac
  case "/$path/" in
    */__tests__/*|*/__specs__/*|*/tests/*|*/test/*|*/spec/*|*/specs/*) return 0 ;;
    */Tests/*|*/Test/*|*/e2e/*|*/integration-tests/*) return 0 ;;
  esac
  return 1
}

test_source_candidate() {
  local path="$1" base ext
  base=$(basename "$path")
  case "$base" in
    *.*) ext=$(printf '%s' "${base##*.}" | tr '[:upper:]' '[:lower:]') ;;
    *) return 1 ;;  # Makefile, Dockerfile, LICENSE — not gated
  esac
  _tp_candidates x "$ext" >/dev/null 2>&1 || return 1
  ! is_test_file "$path" || return 1
  # Not behaviour of its own: type declarations, config, stories, barrels,
  # package scaffolding, generated and minified output.
  case "$base" in
    *.d.ts|*.d.mts|*.d.cts) return 1 ;;
    *.config.*|*.conf.*|*rc.js|*rc.ts|*rc.cjs|*rc.mjs) return 1 ;;
    *.stories.*|*.story.*) return 1 ;;
    index.ts|index.tsx|index.js|index.jsx|index.mjs|index.cjs) return 1 ;;
    __init__.py|setup.py|manage.py|conftest.py) return 1 ;;
    *.generated.*|*_pb2.py|*_pb2_grpc.py|*.pb.go|*_generated.go) return 1 ;;
    *.min.js|*.min.ts) return 1 ;;
    AssemblyInfo.cs|*.Designer.cs|GlobalUsings.cs) return 1 ;;
  esac
  # Dependencies, build output, and the migrations the protected-change rule
  # already owns.
  case "/$path/" in
    */node_modules/*|*/vendor/*|*/.venv/*|*/venv/*|*/__pycache__/*|*/.git/*) return 1 ;;
    */dist/*|*/build/*|*/out/*|*/.next/*|*/target/*|*/bin/*|*/obj/*|*/coverage/*) return 1 ;;
    */migrations/*|*/migrate/*) return 1 ;;
  esac
  return 0
}

# _tp_dirs <dir> — <dir>, its test subdirectories, and the test directories of
# up to four ancestors. One line per existing directory.
_tp_dirs() {
  local dir="$1" i=0 sub
  while [ -n "$dir" ] && [ "$dir" != "/" ] && [ "$i" -lt 5 ]; do
    for sub in __tests__ __specs__ tests test spec specs Tests Test; do
      [ -d "$dir/$sub" ] && printf '%s\n' "$dir/$sub"
    done
    i=$((i + 1))
    dir=$(dirname "$dir")
  done
  return 0
}

test_exists_for() {
  local path="$1" dir base stem ext name
  dir=$(dirname "$path")
  base=$(basename "$path")
  stem="${base%.*}"
  ext=$(printf '%s' "${base##*.}" | tr '[:upper:]' '[:lower:]')
  local cands
  cands=$(_tp_candidates "$stem" "$ext") || return 1

  # Cheap pass: the conventional names next to the file.
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    [ -f "$dir/$name" ] && [ "$dir/$name" != "$path" ] && return 0
  done <<<"$cands"

  # Test directories at or above the file. One bounded find per directory, with
  # every candidate name in a single expression — a nudge must not cost a tree walk.
  command -v find >/dev/null 2>&1 || return 1
  local -a args=()
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    if [ "${#args[@]}" -eq 0 ]; then
      args=(-name "$name")
    else
      args+=(-o -name "$name")
    fi
  done <<<"$cands"
  [ "${#args[@]}" -gt 0 ] || return 1

  local tdir hit
  while IFS= read -r tdir; do
    [ -n "$tdir" ] || continue
    hit=$(find "$tdir" -maxdepth 4 -type f \( "${args[@]}" \) 2>/dev/null) || hit=""
    [ -n "$hit" ] && return 0
  done <<<"$(_tp_dirs "$dir")"
  return 1
}
