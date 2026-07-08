---
title: CI npm publish fails EOTP — publish manually after the release cut
created: 2026-07-08
updated: 2026-07-08
tags: [release, npm, ci, 2fa]
problem_type: process
source: discovery
confidence: high
top_rule: false
status: active
related: []
supersedes: []
applies_to: [deploy, tooling]
contradicts: []
related_decisions: []
---

## Issue

Every release, the `npm publish` step in `.github/workflows/release.yml` fails with an `EOTP` error. release-please itself works — it opens the release PR, bumps `VERSION`, and tags `main` — but the automated publish leg goes red.

## Root Cause

The npm account requires 2FA (a time-based one-time password) for publish. CI has no way to supply a fresh OTP, and a 2FA-for-publish account rejects token-only publishes with `EOTP`. This is a standing environment fact, not a per-release regression.

## Rule

Treat the CI publish leg as expected-to-fail. Let release-please cut and tag the release as normal, then publish manually from a clean checkout of the tagged `main`:

```bash
npm publish --otp=<fresh 6-digit code>
```

Do not try to "fix" the red CI publish step by fiddling with tokens — it cannot satisfy interactive 2FA.

## Verification

After the release PR merges and CI's publish job fails on `EOTP`, run the manual publish above from `main`, then confirm the new version resolves: `npm view @tansuasici/claude-code-kit version`.

## References

- `RELEASING.md` documents the manual-publish step.
- Applies to any 2FA-protected npm package with automated release tooling.
