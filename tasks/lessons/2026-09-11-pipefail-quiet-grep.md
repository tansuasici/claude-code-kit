---
title: A quiet grep fed by a pipe loses its match under pipefail — the guard silently does not fire
created: 2026-09-11
updated: 2026-09-11
tags: [bash, pipefail, sigpipe, hooks, guardrails]
problem_type: bug
source: review
confidence: high
top_rule: true
status: active
related: []
supersedes: []
applies_to: [hooks, tooling, verification]
contradicts: []
related_decisions: []
---

## Issue

`scripts/doctor.sh` reported a different set of "orphan hooks" from run to run on
an unchanged tree — naming hooks that are wired in `settings.json`. Measured: a
phantom warning in **4 of 100 runs**.

The same shape sat in the safety hooks. `block-dangerous-commands.sh` and
`branch-protect.sh` matched with `echo "$COMMAND" | grep -qE`, so a matched
`rm -rf /` could have its match dropped and the block simply not fire.
`secret-scan.sh` and `unicode-scan.sh` used `if ! file … | grep -qi text`, where
a dropped match makes a text file look binary and it is skipped **unscanned**.

## Root Cause

`grep -q` exits the instant it matches and closes the read end of the pipe. If
the writer has not finished, it takes `SIGPIPE` and exits 141. Under
`set -o pipefail` the pipeline adopts that status, so an `if` takes the `else`
branch **even though grep matched**. `set -e` never aborts, because the pipeline
is an `if` condition — the failure is silent by construction.

Captured directly, reading `PIPESTATUS` before any intervening test could
clobber it:

```text
ANOMALY hook=protect-files.sh echo=141 grep=0 recheck=1
```

Payload size does not predict it: isolated loops showed 0 failures in 3000 trials
at every size from 64 B to 64 KB, while the same pipeline inside the real script
failed ~0.14% of the time. The race needs the surrounding process context, so
"the piped value is short, therefore it is safe" is not a judgement anyone can
make correctly — including the first triage of this bug, which scoped the fix to
large payloads and was wrong.

## Rule

Never pipe into a quiet grep inside a script that sets `pipefail`. Use a
herestring, or a bash substring test when the needle is a fixed string:

```bash
grep -qE "$PATTERN" <<< "$VALUE"      # regex
[[ "$HAYSTACK" == *"$NEEDLE"* ]]      # fixed string, no subprocess at all
```

The rule takes no account of payload size on purpose — a size-based exemption is
exactly the reasoning that let this ship.

## Verification

```bash
PATTERN='[^|]\|[[:space:]]*grep[[:space:]]+(-[a-zA-Z]*q[a-zA-Z]*|--quiet)([[:space:]]|$)'
for f in $(git ls-files '*.sh'); do
  grep -q 'pipefail' "$f" || continue
  grep -nE "$PATTERN" "$f"
done
```

Must print nothing. CI enforces it as the **Pipefail Grep Guard** job, which
reported all 46 hits on the pre-fix tree.

## References

- PR #196 — 46 call sites replaced, guard job added. TAN-5273, TAN-4746.
- `.github/workflows/validate.yml` → `pipefail-grep-guard`
- A single call site was fixed this way once before, with a comment explaining
  why, and the pattern was left everywhere else — which is why the fix ships a
  guard rather than another point fix. See [[2026-07-08-bsd-gnu-portability]]
  for the sibling rule about shell portability in the same scripts.
