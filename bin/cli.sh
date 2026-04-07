#!/usr/bin/env bash
#
# claude-code-kit CLI — npm distribution entry point
#
# Usage:
#   npx claude-code-kit init                    # Fresh install in current directory
#   npx claude-code-kit init --upgrade          # Upgrade existing installation
#   npx claude-code-kit init --profile strict   # Install with strict profile
#   npx claude-code-kit init --template nextjs  # Install with stack template
#   npx claude-code-kit doctor                  # Health check
#   npx claude-code-kit convert [target]        # Export to other formats
#   npx claude-code-kit generate agents-md      # Generate AGENTS.md
#

set -euo pipefail

# Resolve the kit root (where package files live)
KIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  cat <<'USAGE'
Claude Code Kit — Staff-engineer discipline for AI coding agents

Usage:
  claude-code-kit init [options]        Install kit into current directory
  claude-code-kit doctor                Check installation health
  claude-code-kit convert [target]      Export agents (cursor|windsurf|aider|agents-md|all)
  claude-code-kit generate agents-md    Generate AGENTS.md from project sources

Init options:
  --upgrade              Upgrade existing installation
  --profile <name>       Installation profile (minimal|standard|strict)
  --template <name>      Stack template (nextjs|node-api|python-fastapi)
  --dest <path>          Target directory (default: current directory)

Examples:
  npx claude-code-kit init
  npx claude-code-kit init --profile strict --template nextjs
  npx claude-code-kit init --upgrade
  npx claude-code-kit doctor
USAGE
}

CMD="${1:-}"

case "$CMD" in
  init)
    shift
    # Run install.sh with the kit as the source (skip git clone)
    export CLAUDE_CODE_KIT_LOCAL="$KIT_ROOT"
    bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" "$@"
    ;;
  doctor)
    if [ -f "./scripts/doctor.sh" ]; then
      bash ./scripts/doctor.sh
    else
      echo "Error: doctor.sh not found. Run 'claude-code-kit init' first."
      exit 1
    fi
    ;;
  convert)
    shift
    if [ -f "./scripts/convert.sh" ]; then
      bash ./scripts/convert.sh "${1:-all}"
    else
      echo "Error: convert.sh not found. Run 'claude-code-kit init' first."
      exit 1
    fi
    ;;
  generate)
    shift
    TARGET="${1:-}"
    case "$TARGET" in
      agents-md)
        if [ -f "./scripts/gen-agents-md.sh" ]; then
          bash ./scripts/gen-agents-md.sh .
        else
          echo "Error: gen-agents-md.sh not found. Run 'claude-code-kit init' first."
          exit 1
        fi
        ;;
      *)
        echo "Unknown generate target: $TARGET"
        echo "Available: agents-md"
        exit 1
        ;;
    esac
    ;;
  help|--help|-h)
    usage
    ;;
  version|--version|-v)
    cat "$KIT_ROOT/VERSION" | tr -d '[:space:]' | sed 's/#.*//'
    echo ""
    ;;
  "")
    usage
    ;;
  *)
    echo "Unknown command: $CMD"
    echo ""
    usage
    exit 1
    ;;
esac
