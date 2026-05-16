#!/usr/bin/env bash
#
# protect-changes.sh — PreToolUse hook
#
# Blocks edits to architectural files (dependency manifests, migrations,
# auth/security paths) without explicit approval. Enforces CLAUDE.md
# "Protected Changes (Approval Required)" rule deterministically — prompt
# alone is not enough because the agent can decide to proceed silently.
#
# Distinct from protect-files.sh (which blocks secret-bearing files like
# .env and private keys). This hook is about *architectural* protection.
#
# Bypass: set CLAUDE_APPROVED=1 in the environment for the duration of the
# session, or pass it explicitly to the hook subshell. Reasoning behind the
# approval must be recorded in tasks/decisions.md (ADR template).
#

set -euo pipefail

INPUT=$(cat)
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
source "$HOOK_LIB/json-parse.sh"

TOOL_NAME=$(parse_json_field "tool_name")

case "$TOOL_NAME" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(parse_json_field "file_path")
[ -z "$FILE_PATH" ] && exit 0

# Escape hatch
if [ "${CLAUDE_APPROVED:-0}" = "1" ]; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")
# Normalise the path for prefix matching (strip leading ./ and leading slash for comparison)
NORM=$(echo "$FILE_PATH" | sed 's|^\./||')

BLOCKED=false
REASON=""

# Dependency manifests — adding/removing dependencies is a protected change
case "$BASENAME" in
  package.json|pyproject.toml|requirements.txt|requirements-*.txt|Pipfile|Gemfile|Cargo.toml|go.mod|composer.json|build.gradle|build.gradle.kts|pom.xml)
    BLOCKED=true
    REASON="dependency manifest — new dependencies require explicit approval (CLAUDE.md → Protected Changes)"
    ;;
esac

# Migrations & schema files
if [ "$BLOCKED" = false ]; then
  case "$NORM" in
    */migrations/*|migrations/*|*/migrate/*|migrate/*|*/schema.sql|schema.sql|*/schema.prisma|schema.prisma)
      BLOCKED=true
      REASON="database migration/schema — confirm rollback plan and production impact"
      ;;
  esac
fi

# Auth / security paths
if [ "$BLOCKED" = false ]; then
  case "$NORM" in
    */auth/*|auth/*|*/security/*|security/*|*/permissions/*|permissions/*|*/middleware/auth*|*/lib/auth/*)
      BLOCKED=true
      REASON="auth/security path — verify threat model and add tests before editing"
      ;;
  esac
fi

# Build system / core architecture configs (basename match)
if [ "$BLOCKED" = false ]; then
  case "$BASENAME" in
    Dockerfile|docker-compose.yml|docker-compose.yaml|Makefile|tsconfig.json|tsconfig.*.json|vite.config.ts|vite.config.js|next.config.js|next.config.mjs|next.config.ts|webpack.config.js|rollup.config.js|tailwind.config.js|tailwind.config.ts)
      BLOCKED=true
      REASON="build config — core architecture change, requires plan and approval"
      ;;
  esac
fi

# CI workflows (path match — basename alone won't catch e.g. ci.yml under .github/workflows/)
if [ "$BLOCKED" = false ]; then
  case "$NORM" in
    .github/workflows/*.yml|.github/workflows/*.yaml|*/.github/workflows/*.yml|*/.github/workflows/*.yaml)
      BLOCKED=true
      REASON="CI workflow — pipeline change, requires plan and approval"
      ;;
  esac
fi

if [ "$BLOCKED" = true ]; then
  cat <<EOF >&2
BLOCKED by protect-changes.sh: $FILE_PATH
Reason: $REASON

To proceed:
  1. Stop and present 2+ approaches with tradeoffs (per CLAUDE.md → Protected Changes)
  2. Record the decision in tasks/decisions.md using the ADR template
  3. Re-run with CLAUDE_APPROVED=1 in the environment

Projects can override this list via .claude/hooks/project/ (see hooks.md).
EOF
  exit 2
fi

exit 0
