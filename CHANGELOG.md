# Changelog

All notable changes to Claude Code Kit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0](https://github.com/tansuasici/claude-code-kit/compare/v1.0.0...v1.1.0) (2026-03-12)


### Features

* add --diff flag to install.sh and clean up README ([bab00a2](https://github.com/tansuasici/claude-code-kit/commit/bab00a269520179bfb058c3a5bec79cd1e56695d))
* add agent docs, stack templates, validation, and install script ([7a1880c](https://github.com/tansuasici/claude-code-kit/commit/7a1880c2be5b5894c9877a326d95e1fa4a563f5f))
* add agent frontmatter, QA reviewer agent, and multi-tool export script ([b949b89](https://github.com/tansuasici/claude-code-kit/commit/b949b899725f38b62fd51e72152bfd1eef8f15bf))
* add agent frontmatter, QA reviewer, and multi-tool export ([854e16a](https://github.com/tansuasici/claude-code-kit/commit/854e16a4e16540584e74894ea7845e8f226ae73b))
* add custom agent definitions (security-reviewer, code-reviewer, planner) ([a44d115](https://github.com/tansuasici/claude-code-kit/commit/a44d11578450eac575a27a8de096bad828b7cb3c))
* add GitHub Pages with Cayman theme ([2b5ea76](https://github.com/tansuasici/claude-code-kit/commit/2b5ea760a113f25d6d8e46a205a0c43ae918981c))
* add hooks system with 7 pre-built hooks ([e3c8db9](https://github.com/tansuasici/claude-code-kit/commit/e3c8db94af9414fa58864ab5c632f3ecc0329d20))
* add install profiles, upgrade mode, and doctor command ([7b28869](https://github.com/tansuasici/claude-code-kit/commit/7b2886905c70ca84e3fe21b3595785cd9d009bf0))
* add project logo to README ([c58e1db](https://github.com/tansuasici/claude-code-kit/commit/c58e1db5b1564fce143af3cc36ff8bb5a1500c2d))
* add project logo to README and assets ([425ccaa](https://github.com/tansuasici/claude-code-kit/commit/425ccaa190111293325dbc348cb0e2743a712bf5))
* add session handoff, decisions, statusline, permissions, conventional commits ([a2667b1](https://github.com/tansuasici/claude-code-kit/commit/a2667b17db135f8226e6a62e7bfcff7f91b073fb))
* add uninstall script and --gitignore flag ([964214f](https://github.com/tansuasici/claude-code-kit/commit/964214fd0cbdfacef39a175a466daf71b04ae4b4))
* add uninstall script and --gitignore flag for private installations ([c56787b](https://github.com/tansuasici/claude-code-kit/commit/c56787b01dc6507e987c58a159ebc930477fcf1d))
* enhance documentation with new sections on task contracts, context management, and agent behavior strategies ([283dd47](https://github.com/tansuasici/claude-code-kit/commit/283dd473ee07aaf2bf389a366f2171d00b32491c))
* implement skill extraction system with reminder hook and documentation ([b09627c](https://github.com/tansuasici/claude-code-kit/commit/b09627ca30bd4f2a68253d7623e1df21a8045603))
* remove GitHub Pages, add semantic versioning ([#4](https://github.com/tansuasici/claude-code-kit/issues/4)) ([3f69401](https://github.com/tansuasici/claude-code-kit/commit/3f69401530b7a30c4b8d0b76511a372b2085e185))


### Bug Fixes

* add workflow_dispatch trigger to release workflow ([#5](https://github.com/tansuasici/claude-code-kit/issues/5)) ([65899e9](https://github.com/tansuasici/claude-code-kit/commit/65899e95cd13dc6005846e66902f22e136fa1512))
* address 6 bugs and inconsistencies from review ([b4e9d26](https://github.com/tansuasici/claude-code-kit/commit/b4e9d2624532746e6f06216e0c1f0638dbb46d39))
* correct license year and author name ([4fe436d](https://github.com/tansuasici/claude-code-kit/commit/4fe436d063b4fc2e7ca88759e5e00083ec8952b4))
* exclude CHANGELOG.md from markdown lint ([#8](https://github.com/tansuasici/claude-code-kit/issues/8)) ([30fc0ad](https://github.com/tansuasici/claude-code-kit/commit/30fc0ada1ad5a663d9dc3da8701b121f757ced4a))
* harden shell scripts and align hook documentation ([91c9bdf](https://github.com/tansuasici/claude-code-kit/commit/91c9bdf027d3350d26c7d1537460c1ec2d82675c))
* make install.sh upgrade pick up new scripts and agents automatically ([3344ead](https://github.com/tansuasici/claude-code-kit/commit/3344ead6d54cb8296a8b5360f81f689231eab4c1))
* remove invalid extra-files param from release workflow ([#7](https://github.com/tansuasici/claude-code-kit/issues/7)) ([8a3fe77](https://github.com/tansuasici/claude-code-kit/commit/8a3fe77ea074150be14b5c2d011842c3fa7e5afe))
* remove trailing blank line in todo.md (MD012) ([2764bed](https://github.com/tansuasici/claude-code-kit/commit/2764bed703f6e9cb0cc94251e6b7dbea539f2573))
* update Markdown code blocks for consistency across documentation ([563b707](https://github.com/tansuasici/claude-code-kit/commit/563b7071f19b4b1046cab8d6f1812b02f0a2fb37))
* use remote_theme for GitHub Pages cayman theme ([73b2067](https://github.com/tansuasici/claude-code-kit/commit/73b20671e1b985adf83dd2e238f42b132a400bd8))
* wire decisions.md into session boot and protected changes workflow ([0e0014b](https://github.com/tansuasici/claude-code-kit/commit/0e0014b83cd9111f42b4ad7c7a24d9ec3f237927))

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
