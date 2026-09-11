#!/usr/bin/env bash
#
# roots.sh — where a hook's work belongs: the package, the worktree, the state.
#
# Source it:  source "$HOOK_LIB/roots.sh"
#
#   package_root <path>       Nearest dir at or above <path> (file or dir) with a
#                             project marker — package.json, pyproject.toml, go.mod,
#                             Cargo.toml, *.csproj, *.sln, global.json,
#                             Directory.Build.props — or a .git entry. The dir a
#                             check runs in. Empty when there is none below /.
#   worktree_root <path>      Top of the git worktree holding <path>. Empty outside
#                             git or without git installed.
#   hook_project_root [path]  The project a result for <path> belongs to: normally
#                             CLAUDE_PROJECT_DIR; another worktree's root when <path>
#                             sits in a different worktree of the same repository.
#                             Its .hook-state/ is where that result is stored.
#
# Why not always CLAUDE_PROJECT_DIR: it stays at the directory the session started
# in, even after Claude — or an isolated subagent — moves into a git worktree. The
# hook payload's `cwd` follows; CLAUDE_PROJECT_DIR does not. A worktree's results
# must neither block nor clear another worktree's, and its checks must run against
# its own copy of the code.
#
# `.git` is tested with -e, not -d: in a linked worktree (and a submodule) it is a file.
#

_has_project_marker() {
  local d="$1" f
  for f in package.json pyproject.toml go.mod Cargo.toml global.json Directory.Build.props; do
    if [ -f "$d/$f" ]; then
      return 0
    fi
  done
  for f in "$d"/*.csproj "$d"/*.sln; do
    if [ -f "$f" ]; then
      return 0
    fi
  done
  [ -e "$d/.git" ]
}

package_root() {
  local dir="$1" next
  [ -d "$dir" ] || dir=$(dirname "$dir")
  case "$dir" in /*) ;; *) dir="$PWD/$dir" ;; esac
  while [ "$dir" != "/" ]; do
    if _has_project_marker "$dir"; then
      printf '%s\n' "$dir"
      return 0
    fi
    next=$(dirname "$dir")
    [ "$next" = "$dir" ] && break
    dir="$next"
  done
  return 0
}

worktree_root() {
  local dir="$1"
  command -v git >/dev/null 2>&1 || return 0
  [ -d "$dir" ] || dir=$(dirname "$dir")
  git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true
}

# _git_common_dir <worktree> — the repository's shared .git dir, as a physical
# path. Equal for every worktree of one repository, different across repositories.
_git_common_dir() {
  local d
  d=$(git -C "$1" rev-parse --git-common-dir 2>/dev/null) || return 0
  case "$d" in /*) ;; *) d="$1/$d" ;; esac
  (cd "$d" 2>/dev/null && pwd -P) || true
}

hook_project_root() {
  local project="${CLAUDE_PROJECT_DIR:-$PWD}" path="${1:-}" wt pwt wt_common
  if [ -n "$path" ]; then
    wt=$(worktree_root "$path")
    pwt=$(worktree_root "$project")
    # Only another worktree of the SAME repository moves the result. A nested,
    # independent repo (or a submodule) under the project keeps the project's state,
    # where stop-gate.sh reads it.
    if [ -n "$wt" ] && [ -n "$pwt" ] && [ "$wt" != "$pwt" ]; then
      wt_common=$(_git_common_dir "$wt")
      if [ -n "$wt_common" ] && [ "$wt_common" = "$(_git_common_dir "$pwt")" ]; then
        printf '%s\n' "$wt"
        return 0
      fi
    fi
  fi
  printf '%s\n' "$project"
}
