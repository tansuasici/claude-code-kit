---
title: Blanket protected-path blocking trains users to bypass the gate — scope by intent
created: 2026-07-08
updated: 2026-07-08
tags: [hooks, guardrails, false-positives]
problem_type: process
source: correction
confidence: high
top_rule: false
status: active
related: []
supersedes: []
applies_to: [hooks, scope-discipline]
contradicts: []
related_decisions: [adr-016]
---

## Issue

`protect-changes.sh` blocked every edit under any `*/auth/*` directory plus all build configs. On a typical frontend that meant constant `BLOCKED` prompts on presentational components (`components/auth/LoginForm.tsx`) and on routinely-edited config files (CLA-48).

## Root Cause

A guardrail that fires on too broad a pattern produces false-positive fatigue. Users respond by setting `CLAUDE_APPROVED=1` globally or uninstalling — so the gate ends up protecting nothing. Blanket path matching ignored **intent** (UI vs auth logic) and **context** (which profile the user opted into).

## Rule

Scope guardrails by intent and profile, not blanket paths. Keep hard blocks for genuine risk (auth logic, dependencies, migrations, CI); exclude presentational paths (`*/components/*`); make the most aggressive checks opt-in per profile (build-config block only when `CCK_PROTECT_BUILD_CONFIGS=1`, set by the strict profile). A gate users bypass wholesale is worse than a narrower gate they keep.

## Verification

KitBench pins the scoped behavior: s23 (strict blocks build config), s24 (standard warns), s25 (UI component allowed), s06 (backend auth still blocks). Run `./scripts/run-bench.sh`.

## References

- `tasks/decisions.md` → ADR-016.
- [[2026-07-08-generated-config-single-source]] — same theme: a check nobody trusts (because it drifts / over-fires) provides no protection.
