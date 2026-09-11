---
title: A hook's stderr at exit 0 never reaches Claude — use additionalContext
created: 2026-09-11
updated: 2026-09-11
tags: [hooks, quality-gate]
problem_type: knowledge
source: review
confidence: high
top_rule: true
status: active
related: []
supersedes: []
applies_to: [hooks]
contradicts: []
related_decisions: [adr-019]
---

## Issue

The quality gate reported "NOT verified" and config errors on stderr and exited 0.
Claude never saw those messages. Per the Claude Code hooks docs, stderr at exit 0
goes only to the debug log. So does PostToolUse stdout at exit 0. The warnings
existed in the code, but Claude never got them.

## Root Cause

We assumed that anything a hook prints reaches the model. Claude sees hook output
in only two cases: exit 2, where stderr is fed back as a block, and structured
JSON on stdout.

## Rule

When a hook must tell Claude something without blocking, print
`{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"..."}}`
on stdout and exit 0. Use stderr only for messages that come with exit 2. Never
rely on exit-0 stderr for anything Claude has to act on.

## Verification

For any message Claude must act on, the hook's stdout carries an
`additionalContext` JSON object at exit 0 (or the message goes to stderr with
exit 2). A bench scenario for such a message asserts on stdout, not stderr.

## References

ADR-019 in `tasks/decisions.md`; `.claude/hooks/lib/gate-state.sh` (`finish` prints the context).
