# KitBench

Reproducible eval harness for the kit's behavioural claims.

The kit makes deterministic-enforcement promises (e.g. *"protected changes are blocked"*, *"completion is gated on quality"*, *"Tier 1 boot context is injected"*). KitBench turns those promises into pass/fail scenarios so they can be verified on every PR — no LLM, no network, no hand-waving.

## Run it

```bash
./scripts/run-bench.sh                  # all scenarios
./scripts/run-bench.sh --scenario s01   # one
./scripts/run-bench.sh --filter protect # name contains
./scripts/run-bench.sh --verbose        # print stdout/stderr per scenario
./scripts/run-bench.sh --json           # machine-readable summary
```

Exit codes: `0` all pass, `1` one or more fail, `2` runner error.

Each scenario runs in a **fresh temp directory** — no shared state between scenarios.

## What's covered

| # | Scenario | What it asserts |
|---|---|---|
| s01 | `protect-files-blocks-env` | Edit to `.env` → exit 2 |
| s02 | `protect-files-blocks-composer-lock` | Edit to `composer.lock` → exit 2 *(regression: lock-file bug from v1.10.0 review)* |
| s03 | `protect-changes-blocks-package-json` | Edit to `package.json` → exit 2 |
| s04 | `protect-changes-allows-with-claude-approved` | `CLAUDE_APPROVED=1` + edit `package.json` → exit 0 |
| s05 | `protect-changes-blocks-ci-workflow` | Edit `.github/workflows/ci.yml` → exit 2 *(regression: basename-with-slash bug)* |
| s06 | `protect-changes-blocks-auth-path` | Edit `src/auth/login.ts` → exit 2 |
| s07 | `quality-gate-passes-on-good-py` | Valid `.py` → state status `passed` |
| s08 | `quality-gate-fails-on-broken-py` | Syntax-error `.py` → state status `failed` *(regression: `EXIT_CODE=$?` after `\|\| true` bug)* |
| s09 | `stop-gate-blocks-on-failed-state` | Failed state → exit 2 |
| s10 | `stop-gate-allows-on-passed-state` | Passed state → exit 0 |
| s11 | `stop-gate-bypassed-with-skip-env` | `SKIP_QUALITY_GATE=1` + failed state → exit 0 |
| s12 | `prompt-router-injects-on-auth-inflection` | "authentication" → `additionalContext` non-empty *(regression: word-boundary bug)* |
| s13 | `prompt-router-quiet-on-neutral` | Neutral prompt → empty stdout |
| s14 | `session-start-injects-tier1` | Outputs valid JSON with `additionalContext` referencing `CODEBASE_MAP.md` |
| s15 | `session-end-writes-audit-line` | Appends one line to `reports/session-audit.log` |
| s16 | `session-start-working-tree-silent-on-clean` | Working Tree block stays out of `additionalContext` on a fresh-checkout (no `.git`) session — CLA-28 silent-on-clean guarantee |
| s17 | `lesson-resurface-smoke` | `scripts/lesson-resurface.sh` emits the pointer for an archived lesson matching the query vocabulary AND does NOT leak the lesson body's sentinel phrases — CLA-25 / CLA-32 pointer-only contract |
| s18 | `journal-fold-creates-handoff` | `.claude/hooks/journal-fold.sh` folds a `/note`-populated `.hook-state/session-journal.md` (with findings + decisions) into `tasks/handoff-<session-id>.md` at session end — CLA-33 |
| s19 | `journal-fold-folds-agent-handoff` | `journal-fold.sh` folds a non-empty `.hook-state/agent-handoff.md` (the inter-agent scratchpad) into `tasks/handoff-<session-id>.md` even with no journal present — CLA-37 |
| s20 | `subagent-pre-logs-invocation` | `subagent-pre.sh` (PreToolUse on Task) appends an open telemetry row to `.hook-state/agent-invocations.jsonl` — CLA-38 |
| s21 | `subagent-post-closes-invocation` | `subagent-post.sh` (PostToolUse on Task) closes the latest open telemetry row with `finished_at` + `duration_seconds` — CLA-38 |
| s22 | `session-start-clears-stale-quality-gate` | `session-start.sh` clears a stale `failed` `last_quality_gate.json` so a fresh session isn't blocked by a prior session's verdict — CLA-44 |
| s23 | `protect-changes-build-config-blocks-in-strict` | `CCK_PROTECT_BUILD_CONFIGS=1` + edit `tsconfig.json` → exit 2 — CLA-48 |
| s24 | `protect-changes-build-config-warns-in-standard` | Edit `tsconfig.json` without the env → exit 0 (advisory, no block) — CLA-48 |
| s25 | `protect-changes-allows-ui-component` | Edit `src/components/auth/LoginForm.tsx` → not blocked (UI ≠ auth logic) — CLA-48 |
| s26 | `block-dangerous-rm-system-path` | `sudo rm -rf /etc/nginx` → exit 2 (system path) |
| s27 | `block-dangerous-rm-no-preserve-root` | `rm -rf --no-preserve-root /` → exit 2 |
| s28 | `block-dangerous-allows-project-rm` | `rm -rf node_modules dist` → exit 0 (project-local, allowed) |
| s29 | `block-dangerous-chmod-system` | `chmod -R 777 /etc` → exit 2 (system path) |
| s30 | `block-dangerous-allows-chown-app` | `chown -R deploy:deploy /srv/app` → exit 0 (app path, allowed) |
| s31 | `branch-protect-blocks-push-u-main` | `git push -u origin main` → exit 2 |
| s32 | `branch-protect-blocks-refspec-dest-main` | `git push origin feature:main` → exit 2 (refspec destination is `main`) |
| s33 | `branch-protect-blocks-git-c-push-main` | `git -c color.ui=always push origin main` → exit 2 (`-c` flag can't smuggle past the matcher) |
| s34 | `branch-protect-allows-feature-branch` | `git push -u origin feat/search` → exit 0 (feature branch, allowed) |
| s35 | `conventional-commit-blocks-am-badmsg` | `git commit -am "updated stuff"` → exit 2 (non-conventional message) |
| s36 | `conventional-commit-allows-am-goodmsg` | `git commit -am "feat: add search endpoint"` → exit 0 (conventional message) |
| s37 | `loop-detect-blocks-on-repeated-edit` | Repeated `Edit` to `src/foo.ts` (pre-seeded loop log) → exit 2 |
| s38 | `loop-detect-quiet-on-first-edit` | First `Edit` to `src/bar.ts` → exit 0 (no loop yet) |
| s39 | `mcp-gate-blocks-unlisted-server` | Allowlist present, `mcp__github__*` not listed → exit 2 (blocked) |
| s40 | `mcp-gate-allows-listed-server` | `github` on the allowlist → `mcp__github__*` exit 0 (allowed) |
| s41 | `mcp-gate-inert-without-allowlist` | No allowlist file → exit 0, only the untrusted-input reminder fires |

## Add a scenario

Drop a JSON file in `bench/scenarios/sNN-<name>.json`:

```json
{
  "name": "sNN-short-descriptive-slug",
  "hook": ".claude/hooks/<your-hook>.sh",
  "setup_files": {
    "<relpath inside temp dir>": "<file content>"
  },
  "env": { "VAR": "value" },
  "payload": { "tool_name": "Edit", "tool_input": { "file_path": "{TMPROOT}/x" } },
  "expect": {
    "exit_code": 2,
    "stderr_contains": ["BLOCKED"],
    "stdout_contains": [],
    "stdout_not_contains": [],
    "stdout_empty": false,
    "stderr_not_contains": [],
    "state": [
      { "file": ".hook-state/<state>.json", "field": "status", "equals": "failed" }
    ],
    "file_grew": ["reports/session-audit.log"]
  },
  "notes": "Optional human-readable context — especially useful for regression scenarios."
}
```

Variables in string values:
- `{TMPROOT}` — the per-scenario temp directory (e.g. for absolute paths inside payload)
- `{KIT_ROOT}` — the kit checkout root

All `expect.*` keys are optional. The minimum useful assertion is `exit_code`.

## What it deliberately does not do

- **No LLM-graded evals.** Hooks are deterministic shell scripts; their behaviour is grounded in exit codes and state-file content. LLM grading would re-introduce non-determinism.
- **No session replay.** The harness invokes one hook at a time, not a full Claude Code session.
- **No cross-tool coverage.** Adapters for Cursor/Codex/Devin are out of scope.
- **No remote scoreboard.** The bench prints results to stdout; CI's check status is the scoreboard.

## Why this exists

The kit's commitment is *"deterministic enforcement"* (ADR-003). Without a bench, that commitment is a vibe. KitBench turns the commitment into a contract — and every PR that touches a hook re-asserts it.

Past bugs that KitBench would have caught (and that several scenarios above directly regression-cover):

- v1.10.0: `composer.lock` slipped through `protect-files` (s02)
- v1.10.0: `EXIT_CODE=$?` after `|| true` always reported "passed" (s08)
- v1.10.0: basename-only match missed `.github/workflows/ci.yml` (s05)
- v1.10.0: word-boundary regex in `prompt-router.sh` rejected "authentication" (s12)
