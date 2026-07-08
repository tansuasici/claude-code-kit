---
title: Kit ships bash to macOS + Linux — write portable grep/sed/sort or the macOS CI leg fails
created: 2026-07-08
updated: 2026-07-08
tags: [bash, portability, macos, ci]
problem_type: tool
source: review
confidence: high
top_rule: false
status: active
related: []
supersedes: []
applies_to: [tooling, hooks, testing]
contradicts: []
related_decisions: []
---

## Issue

Shell that passes on Linux CI misbehaves on macOS: `sed -i` without a backup suffix errors, `grep -P` (PCRE) is unsupported, and `sort` without a fixed locale collates differently — so an artifact regenerated on macOS fails the Linux `--check` (and vice versa).

## Root Cause

The kit's hooks and scripts run on end-user machines, and most are macOS with BSD coreutils — but a naive CI only exercises Linux/GNU. BSD and GNU differ on in-place-edit syntax, regex engines, and byte collation.

## Rule

Write portable shell: avoid GNU-only flags; use `LC_ALL=C sort` for deterministic byte order; reach for `python3` on non-trivial text transforms (already the kit's convention for JSON); never `sed -i` without an explicit backup suffix. Keep the macOS CI leg green — it's the canary.

## Verification

`run-bench.sh`, `test-install.sh`, and `test-cli.sh` run on `ubuntu-latest` AND `macos-latest` in `.github/workflows/validate.yml`. Concrete guard already in place: `scripts/sync-manifest.sh` wraps its `sort` in `LC_ALL=C` so the manifest is byte-identical on both platforms.

## References

- `.github/workflows/validate.yml` — the `kitbench`, `install-test`, and `cli-test` jobs use a `[ubuntu-latest, macos-latest]` matrix specifically to catch this.
