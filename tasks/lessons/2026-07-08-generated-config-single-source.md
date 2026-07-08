---
title: Never hand-maintain a second copy of generated config — generate it + drift-check in CI
created: 2026-07-08
updated: 2026-07-08
tags: [ci, drift, config, single-source]
problem_type: process
source: review
confidence: high
top_rule: false
status: active
related: []
supersedes: []
applies_to: [tooling, verification]
contradicts: []
related_decisions: []
---

## Issue

The strict-profile settings lived as a 237-line embedded heredoc in `install.sh` — a second, hand-maintained copy of the standard `.claude/settings.json`. It had zero test coverage: a JSON or hook-ordering regression in it would ship silently, and it could drift from the base structure with nothing to catch it (TAN-4689).

## Root Cause

Two hand-maintained sources of the same structure always drift. The strict copy was "the standard settings plus a small delta," but nothing regenerated it from the base and no CI check compared the two.

## Rule

When one artifact is "another artifact plus a delta," don't copy it — **generate** it from the base + an explicit delta, commit the generated file, and add a CI `--check` that regenerates and diffs. This is already the kit's pattern for `.kit-manifest`, `AGENTS.md`, and now `.claude/settings.strict.json`. One source of truth; drift caught pre-merge, not in a user's install.

## Verification

`scripts/gen-strict-settings.sh --check`, `scripts/sync-manifest.sh --check`, and the AGENTS.md regenerate-and-`git diff --exit-code` job all run in `.github/workflows/validate.yml`. The same discipline underlies `scripts/check-counts.sh` (a single declared count, CI-asserted).

## References

- TAN-4689 (strict settings extraction).
- [[2026-07-08-protect-changes-false-positives]] — a check nobody can trust is no check at all.
