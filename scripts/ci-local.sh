#!/usr/bin/env bash
#
# ci-local.sh — run the Validate workflow's checks on this machine.
#
# GitHub-hosted Actions may be unavailable (see RELEASING.md). This runs the
# same checks as .github/workflows/validate.yml, on the current OS only, so a
# branch can be verified before it is pushed or merged. Every check runs even
# after one fails; the exit code is non-zero if any failed.
#
# Needs: bash, git, python3, node/npx (markdownlint), lychee (link check,
# `brew install lychee`). The link check needs network access.
#
# Usage: ./scripts/ci-local.sh          (from anywhere inside the repo)
# As a pre-push hook:  ln -s ../../scripts/ci-local.sh .git/hooks/pre-push
#

set -uo pipefail

cd "$(git rev-parse --show-toplevel)" || exit 1

# The markdownlint-cli2 version markdownlint-cli2-action@v19 runs in CI.
MARKDOWNLINT_CLI2=markdownlint-cli2@0.17.2

FAILED=()
PASSED=0

check() {
  local name="$1"; shift
  echo ""
  echo "=== $name"
  if "$@"; then
    PASSED=$((PASSED + 1))
  else
    FAILED+=("$name")
  fi
}

markdown_lint() {
  npx --yes "$MARKDOWNLINT_CLI2" --config .markdownlint.json \
    '**/*.md' '!node_modules/**' '!CHANGELOG.md'
}

link_check() {
  if ! command -v lychee >/dev/null 2>&1; then
    echo "lychee is not installed (brew install lychee)." >&2
    return 1
  fi
  # Same arguments as the CI step; the glob is lychee's, not the shell's.
  lychee --no-progress --exclude-path node_modules '**/*.md'
}

agents_md_sync() {
  ./scripts/gen-agents-md.sh . >/dev/null || return 1
  if ! git diff --exit-code -- AGENTS.md; then
    echo "AGENTS.md is stale — run scripts/gen-agents-md.sh and commit." >&2
    return 1
  fi
}

check "Markdown Lint"           markdown_lint
check "Link Check"              link_check
check "Template Validation"     ./scripts/check-templates.sh
check "KitBench"                ./scripts/run-bench.sh
check "Install smoke test"      bash scripts/test-install.sh
check "Other-kit refusal"       bash scripts/test-other-kit.sh
check "CLI smoke test"          bash scripts/test-cli.sh
check "Manifest Sync"           ./scripts/sync-manifest.sh --check
check "Scaffold Check"          ./scripts/check-scaffold.sh
check "AGENTS.md Sync"          agents_md_sync
check "Strict Settings Sync"    ./scripts/gen-strict-settings.sh --check
check "Skill Validation"        ./scripts/validate-skills.sh
check "Counts"                  ./scripts/check-counts.sh
check "Pipefail Grep Guard"     ./scripts/check-pipefail-grep.sh

echo ""
echo "=== Summary: $PASSED passed, ${#FAILED[@]} failed"
if [ "${#FAILED[@]}" -gt 0 ]; then
  printf '  FAILED: %s\n' "${FAILED[@]}"
  exit 1
fi
