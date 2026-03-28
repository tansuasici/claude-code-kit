# Changelog

All notable changes to Claude Code Kit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.3](https://github.com/tansuasici/claude-code-kit/compare/v1.3.2...v1.3.3) (2026-03-28)


### Bug Fixes

* resolve review findings ([#36](https://github.com/tansuasici/claude-code-kit/issues/36), [#37](https://github.com/tansuasici/claude-code-kit/issues/37), [#38](https://github.com/tansuasici/claude-code-kit/issues/38), [#39](https://github.com/tansuasici/claude-code-kit/issues/39)) ([ad13bd1](https://github.com/tansuasici/claude-code-kit/commit/ad13bd1e66cc3ac3839d17e02c191a5ee1fcfb82))
* resolve review findings across scripts, hooks, and docs ([5809d4c](https://github.com/tansuasici/claude-code-kit/commit/5809d4c1f8d355afab66a22484b2ff4490471f2e))

## [1.3.2](https://github.com/tansuasici/claude-code-kit/compare/v1.3.1...v1.3.2) (2026-03-28)


### Features

* add Glassworm invisible Unicode detection hook (`unicode-scan.sh`) — defends against supply chain attacks using invisible characters ([#32](https://github.com/tansuasici/claude-code-kit/issues/32))
* add template-based skill generation system — shared blocks, `.tmpl` templates, and `build-skills.sh` build script ([#29](https://github.com/tansuasici/claude-code-kit/issues/29))
* convert 3 skills to templates as proof-of-concept (code-quality-audit, testing-audit, dead-code-audit)
* add 6 shared content blocks: preamble, scope-rules, verification-order, plan-first, context-gathering, report-footer


### Bug Fixes

* close #30 (retro skill) and #31 (office-hours skill) — already implemented in v1.3.0

## [1.3.1](https://github.com/tansuasici/claude-code-kit/compare/v1.3.0...v1.3.1) (2026-03-23)


### Bug Fixes

* resolve doc inconsistencies and harden scripts ([87614bb](https://github.com/tansuasici/claude-code-kit/commit/87614bb07ef30f129df62fafb00904afd6ae897f))
* resolve doc inconsistencies, add project overlay dirs, harden scripts ([4abcceb](https://github.com/tansuasici/claude-code-kit/commit/4abcceb6d67942dd41b7ac3ab825b82aed15dc5b))

## [1.3.0](https://github.com/tansuasici/claude-code-kit/compare/v1.2.1...v1.3.0) (2026-03-19)


### Features

* add 17 skills, dead-code-remover agent, auto-detect, enhanced hooks, gen-skill-docs ([#25](https://github.com/tansuasici/claude-code-kit/issues/25)) ([404e746](https://github.com/tansuasici/claude-code-kit/commit/404e7468822fc1cee0d8a3a5af6931766fb47d1d))


### Bug Fixes

* resolve 32 review findings across shell scripts, hooks, docs, and CI ([#23](https://github.com/tansuasici/claude-code-kit/issues/23)) ([1d5a845](https://github.com/tansuasici/claude-code-kit/commit/1d5a8450c49a317a7857581716f024dae78d92b4))

## [1.2.1](https://github.com/tansuasici/claude-code-kit/compare/v1.2.0...v1.2.1) (2026-03-13)


### Bug Fixes

* add --repo flag to gh workflow dispatch in release CI ([#21](https://github.com/tansuasici/claude-code-kit/issues/21)) ([f5d9a11](https://github.com/tansuasici/claude-code-kit/commit/f5d9a1104124187e671df9362932ea3d2e984f8f))
* auto-trigger CI checks on release-please PRs ([#19](https://github.com/tansuasici/claude-code-kit/issues/19)) ([27f47fa](https://github.com/tansuasici/claude-code-kit/commit/27f47fac937f78956e190ffe3bd1fe1958ccb412))
* report commit statuses on release PR head SHA ([#22](https://github.com/tansuasici/claude-code-kit/issues/22)) ([1ea0de2](https://github.com/tansuasici/claude-code-kit/commit/1ea0de20d42a50060e1d6c5cec757762bb642107))

## [1.2.0](https://github.com/tansuasici/claude-code-kit/compare/v1.1.0...v1.2.0) (2026-03-13)


### Features

* add 7 skill writing principles to skills guide ([#16](https://github.com/tansuasici/claude-code-kit/issues/16)) ([88bcab8](https://github.com/tansuasici/claude-code-kit/commit/88bcab8d1597bfe4e6228bca9d5dd6a7610bfd39))
* add skill validator script with doctor.sh integration ([#13](https://github.com/tansuasici/claude-code-kit/issues/13)) ([e737e3d](https://github.com/tansuasici/claude-code-kit/commit/e737e3d9e85ebf8101e85ff88be1ef21ff2de2c8))
* add skill-compliance hook for post-edit skill verification ([#15](https://github.com/tansuasici/claude-code-kit/issues/15)) ([591ca30](https://github.com/tansuasici/claude-code-kit/commit/591ca30523b00b9b82f41c05b6db2198b1a350fa))
* add skill-generator meta-skill for project-specific coding standards ([#14](https://github.com/tansuasici/claude-code-kit/issues/14)) ([fc28b89](https://github.com/tansuasici/claude-code-kit/commit/fc28b89f17916d8470cb969edee69eb00e47c8f1))
* extended skill folder structure ([#12](https://github.com/tansuasici/claude-code-kit/issues/12)) ([cc6e59d](https://github.com/tansuasici/claude-code-kit/commit/cc6e59d84fab782a27c9efbbb9209654460bd372))


### Bug Fixes

* align Three-Agent Pattern ASCII art diagram ([#17](https://github.com/tansuasici/claude-code-kit/issues/17)) ([75d675f](https://github.com/tansuasici/claude-code-kit/commit/75d675fec4d9f0acbe78751e34198a055842a362))
* harden shell scripts for robustness and edge cases ([#11](https://github.com/tansuasici/claude-code-kit/issues/11)) ([d6cb48c](https://github.com/tansuasici/claude-code-kit/commit/d6cb48cd6a0702223c75459d71e01f5d65caa262))
* sync VERSION with release and fix release-please config ([#9](https://github.com/tansuasici/claude-code-kit/issues/9)) ([f6b2124](https://github.com/tansuasici/claude-code-kit/commit/f6b2124a4ec5dcd00d09f3eff9b2443cfa497ab9))

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
