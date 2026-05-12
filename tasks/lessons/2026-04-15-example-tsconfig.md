---
title: Edited wrong tsconfig and broke the build
created: 2026-04-15
updated: 2026-04-15
tags: [typescript, build, config]
problem_type: tool
source: correction
confidence: high
top_rule: false
status: active
related: []
---

# Edited wrong tsconfig and broke the build

> This file is an **example** that ships with the kit to show the lesson format. Delete it when you start recording your own lessons, or keep it as a reference.

## Issue

Changed `tsconfig.json` instead of `tsconfig.build.json`. The dev server still ran, but the production build broke because the production-only path mapping lives in the build-specific config.

## Root Cause

Assumed there was only one `tsconfig.*` file without listing the directory first. The project has multiple TypeScript configs that serve different scopes (dev vs build vs test).

## Rule

Before editing any `tsconfig*.json` (or `vite.config.*`, `next.config.*`, `webpack.config.*`, `*.eslintrc.*`), run `ls <pattern>` to enumerate all variants. Confirm which one is the right target before opening it.

## Verification

```bash
ls tsconfig*.json     # see all variants
cat package.json | jq '.scripts'   # check which config each script references
```

## References

- Equivalent risk applies to monorepos with workspace-level configs that override package-level ones.
