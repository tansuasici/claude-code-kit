---
title: [Short title — what went wrong, one line]
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags: [tag1, tag2]
problem_type: tool      # tool | process | bug | knowledge
source: correction      # correction | review | discovery
confidence: high        # high | medium | low
top_rule: false         # true to surface this in _index.md → Top Rules
status: active          # active | archived | superseded
related: []             # slugs of related lessons (free-form, untyped — kept for backward compat)
# --- Typed relations (all optional; consumed by scripts/lesson-graph.sh) ---
supersedes: []          # slugs of OLDER lessons this one replaces (the old ones should set status: superseded)
applies_to: []          # canonical topic tags — e.g. [scope-discipline, plan-first, verification]
contradicts: []         # slugs of lessons whose rule conflicts with this one (graph script warns on loops)
related_decisions: []   # ADR slugs from tasks/decisions.md — e.g. [adr-003]
---

## Issue

<!-- What went wrong, concretely. Include the symptom the user or agent observed. -->

## Root Cause

<!-- Why it happened. What assumption was wrong, what step was skipped, what context was missing. -->

## Rule

<!-- The single rule to apply going forward. Phrase as an imperative the agent can act on. -->

## Verification

<!-- How to check this rule was followed. A command, a code pattern, a checklist line. Skip if not applicable. -->

## References

<!-- Optional. Links to related code, PR, docs, or sibling lessons via [[slug]]. -->
