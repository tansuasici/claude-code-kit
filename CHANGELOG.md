# Changelog

All notable changes to Claude Code Kit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-13

### Added

- Core `CLAUDE.md` instruction set with session boot, plan-first workflow, scope discipline, and verification rules
- `CODEBASE_MAP.md` project mapping template
- 9 agent behavior guides in `agent_docs/` (workflow, debugging, testing, conventions, subagents, hooks, skills, contracts, prompting)
- 9 deterministic hooks: protect-files, branch-protect, block-dangerous-commands, conventional-commit, secret-scan, auto-lint, auto-format, task-complete-notify, skill-extract-reminder
- 4 custom agents: code-reviewer, security-reviewer, qa-reviewer, planner
- Skill extraction system with skill-extractor meta-skill
- Session state tracking via `tasks/` (todo, lessons, decisions, handoff)
- 3 stack templates: Next.js, Node API, Python FastAPI
- One-line installer (`install.sh`) with `--template`, `--profile`, `--upgrade`, `--diff`, `--gitignore` flags
- Uninstaller (`uninstall.sh`) with `--dry-run`, `--keep-tasks`, `--force` flags
- Utility scripts: doctor.sh, validate.sh, statusline.sh, convert.sh
- CI validation workflow (markdown lint, link check, template validation)

[1.0.0]: https://github.com/tansuasici/claude-code-kit/releases/tag/v1.0.0
