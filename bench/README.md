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
| s22 | `session-start-prior-session-verdict-kept` | A prior session's failing verdict doesn't block a new session's stop, and `session-start.sh` keeps it — the prior session's own stop still blocks *(multi-step)* |
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
| s42 | `quality-gate-uses-declared-lint-fail` | `.claude/commands.json` declares `lint: false` → gate runs it, records `failed` |
| s43 | `quality-gate-uses-declared-lint-pass` | `.claude/commands.json` declares `lint: true` → gate runs it, records `passed` |
| s44 | `journal-fold-redacts-secrets` | `journal-fold.sh` masks secret values (`api_key=…`, `Bearer …`) before folding notes into the durable `tasks/handoff-*.md`, leaving prose intact — TAN-4733 |
| s45 | `notify-waiting-noops-when-unconfigured` | No notifier configured → exit 0, nothing sent |
| s46 | `notify-waiting-handles-empty-payload` | Empty Notification payload → exit 0, no crash |
| s47 | `notify-waiting-ntfy-remote-configured` | `ntfy` topic configured → the remote notifier is selected |
| s48 | `notify-waiting-pushover-remote-configured` | Pushover credentials configured → the remote notifier is selected |
| s49 | `session-start-top-rules-clean` | Top Rules inject the rule itself, not the `AUTO-GENERATED` marker comments around it |
| s50 | `session-start-no-top-rules` | Empty Top Rules section → no "Top rules" block at all, not the "*No top rules yet*" placeholder |
| s51 | `quality-gate-worktree-isolation` | A broken edit inside a git worktree is stored in that worktree (not the main checkout) and still blocks the session's stop from either checkout; another session's stop is allowed *(multi-step, real `git worktree add`)* |
| s52 | `quality-gate-fix-unblocks-stop` | Broken edit → stop blocked → file fixed → gate passes → stop allowed *(multi-step)* |
| s53 | `quality-gate-timeout-kills-check` | A hanging declared check is killed at `CCK_QUALITY_GATE_TIMEOUT` together with its background child → status `timeout`, no process left running |
| s54 | `quality-gate-unrelated-pass-keeps-failure` | `a.py` fails, then `b.py` passes → the verdict stays `failed` and stop is blocked on `a.py` *(multi-step)* |
| s55 | `stop-gate-reverifies-stale-file` | A passing file changes without an Edit → stop re-runs its check: broken content blocks, fixed content is allowed *(multi-step)* |
| s56 | `compaction-keeps-failing-verdict` | `session-start` with `source: compact` keeps the per-file state → a failing file still blocks stop *(multi-step)* |
| s57 | `quality-gate-missing-declared-command-errors` | Declared lint isn't installed (exit 127) → status `error`, not `failed`, and stop is blocked *(multi-step)* |
| s58 | `quality-gate-unsupported-file-unverified` | `.rb` after a passing `.py` → recorded `skipped`, Claude told it is NOT verified, listed in `unverified_files`, stop names it without blocking *(multi-step)* |
| s59 | `quality-gate-docs-edit-not-gated` | A Markdown-only edit records nothing and never blocks *(multi-step)* |
| s60 | `quality-gate-shell-syntax` | A broken `.sh` fails `bash -n` |
| s61 | `quality-gate-invalid-commands-json-errors` | Malformed `commands.json` → status `error` and stop blocked; once fixed, stop re-verifies with the declared check and allows *(multi-step)* |
| s62 | `quality-gate-dotnet-build` | `.cs` edit builds the nearest `.csproj` (fake `dotnet` on PATH): good passes, broken fails and blocks stop *(multi-step)* |
| s63 | `quality-gate-dotnet-declared-command` | A declared `typecheck` runs for `.cs` edits instead of the gate's own `dotnet build` |
| s64 | `quality-gate-dotnet-missing-skipped` | No `dotnet` on PATH → `.cs` edit `skipped` (tool-unavailable), reported as NOT verified, never passed *(multi-step)* |
| s65 | `protect-changes-blocks-csproj` | Edit to a `.csproj` → exit 2 (dependency manifest) |
| s66 | `quality-gate-commands-json-unknown-key` | A mistyped key (`typcheck`) in `commands.json` → config `error` naming the key, stop blocked *(multi-step)* |
| s67 | `quality-gate-declared-check-disabled` | `lint: ""` → edit recorded `skipped` (disabled), NOT verified — no guessed check runs |
| s68 | `quality-gate-declared-timeout` | `timeout` in `commands.json` cuts off a slow declared check → status `timeout` |
| s69 | `stop-gate-worktree-cwd-keeps-main-failure` | A failure in the main checkout still blocks a stop whose `cwd` is a git worktree — stop-gate checks `CLAUDE_PROJECT_DIR`'s state and the worktree's *(multi-step, real `git worktree add`)* |
| s70 | `quality-gate-late-pass-keeps-newer-failure` | A slow scope-wide check that passes after a later run of its scope failed doesn't overwrite that failure or re-hash the broken file as verified |
| s71 | `quality-gate-concurrent-runs-keep-every-record` | Twelve concurrent gate runs on broken files → all twelve failures recorded (locked state, unique temp files) and listed at stop |
| s72 | `stop-gate-unreadable-state-blocks` | A torn `quality-gate-state.json` blocks stop with reset instructions instead of reading as empty; a later gate run exits 2 saying it can't record *(multi-step)* |
| s73 | `stop-gate-broken-python3-still-blocks` | A `python3` stub that exits 1 counts as absent: the jq / bash readers see the failed summary and stop is blocked *(multi-step)* |
| s74 | `quality-gate-leftover-process-bounded` | A declared check that exits but leaves a process holding its output: the hook returns within the limit (output goes to a file) |
| s75 | `stop-gate-non-ascii-path-blocks` | A failing file under `Çalışma proj/` with `PYTHONIOENCODING=ascii` still blocks — UTF-8 helper I/O, helper failures fail closed *(multi-step)* |
| s76 | `quality-gate-declared-command-skips-outside-file` | A declared command doesn't verify `../sibling/util.py`: files outside the project root are auto-detected, fail and block *(multi-step)* |
| s77 | `quality-gate-perl-timeout-kills-group` | No python3 / `timeout` on PATH: the perl fallback kills the check's whole process group at the limit → `timeout`, no process left |
| s78 | `quality-gate-commands-json-infinite-timeout` | `"timeout": Infinity` in `commands.json` → config `error`, not a silent 30s default |
| s79 | `quality-gate-commands-json-bom` | A `commands.json` saved with a UTF-8 BOM is valid: the declared lint runs |
| s80 | `quality-gate-unrecorded-result-blocks` | The gate state can't be written → the run is `error`, the hook exits 2 so Claude hears it, and stop blocks on the file until a result is recorded *(multi-step)* |
| s81 | `quality-gate-broken-python3-skips-py` | A `python3` stub and no ruff: a valid `.py` edit is `skipped (tool-unavailable)` — NOT verified, never failed — and stop isn't blocked *(multi-step)* |
| s82 | `quality-gate-unwritable-state-dir-blocks` | A read-only `.hook-state`: the gate exits 2 saying the result can't be recorded, notes the file outside the project, and stop blocks *(multi-step)* |
| s83 | `quality-gate-unrecordable-noted-outside-project` | Nothing can be created in the project: an unedited project stops fine; an edit is noted in `$TMPDIR` and blocks stop *(multi-step)* |
| s84 | `stop-gate-no-python-keeps-every-failure` | No python3 and no jq: `a.sh` fails, `b.sh` passes → stop still blocks on `a.sh` (plain per-file log) *(multi-step)* |
| s85 | `stop-gate-no-python-reverifies-stale-file` | No python3: a passing file changed without an Edit is re-verified at stop — broken blocks, fixed is allowed *(multi-step)* |
| s86 | `stop-gate-no-python-per-file-state-fail-closed` | A per-file state that needs python3, read without it: blocks the session it holds records for, not a later session *(multi-step)* |
| s87 | `stop-gate-sees-edits-in-other-worktrees` | The session edits a file in another git worktree by absolute path: its stop (cwd = main) blocks on it; another session's doesn't *(multi-step)* |
| s88 | `stop-gate-renamed-file-keeps-scope-failure` | A scope-wide declared check fails, then the file is renamed: the failure still blocks stop |
| s89 | `stop-gate-deleted-file-clears-file-check` | A per-file check's failure goes away with the deleted file (guard for s88) |
| s90 | `session-start-keeps-other-sessions-failures` | Session B's SessionStart keeps session A's failure: B's stop is allowed, A's is blocked *(multi-step)* |
| s91 | `quality-gate-leftover-not-waited-for` | A finished check leaves a SIGTERM-ignoring process: the hook doesn't wait out a kill grace (the group is killed only on timeout) |
| s92 | `quality-gate-sigterm-ends-check` | SIGTERM to the gate mid-check ends the check and leaves no output file; stop re-verifies the run |
| s93 | `stop-gate-reverify-budget` | Two stale files, a 3s check, `CCK_STOP_REVERIFY_BUDGET=2`: re-verification stops at the budget and both files block *(multi-step)* |
| s94 | `stop-gate-no-python-mixed-sessions-fail-closed` | Without python3 or jq, a failing record with no session (or `"-"`) alongside another session's passing record still blocks *(multi-step)* |
| s95 | `session-start-clears-pre-v2-summary` | A pre-v2 `last_quality_gate.json` (no session_id) doesn't block a fresh session's first stop *(multi-step)* |

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

Variables, substituted in `payload`, `env` values, `setup_files` contents and `setup_commands`:
- `{TMPROOT}` — the per-scenario temp directory (e.g. for absolute paths inside payload)
- `{KIT_ROOT}` — the kit checkout root

All `expect.*` keys are optional. The minimum useful assertion is `exit_code`. Two more exist for bounded runs: `max_seconds` (the hook returned within N seconds) and `no_process` (no process whose command line matches these `pgrep -f` patterns is still running).

### Multi-step scenarios

When behavior spans several hook runs — a failed gate blocking stop until the file is fixed — replace the top-level `hook` / `payload` / `env` / `expect` with a `steps` list of them. Steps share one workdir and run in order; each can add `setup_files` (written just before it runs) and `cwd` (relative to the workdir). `setup_commands` run once in the workdir before the first step, for what files can't express:

```json
{
  "name": "sNN-short-descriptive-slug",
  "setup_commands": ["git init -q ."],
  "steps": [
    {
      "hook": ".claude/hooks/quality-gate.sh",
      "setup_files": { "src/app.py": "def hello(\n" },
      "payload": { "tool_name": "Edit", "tool_input": { "file_path": "{TMPROOT}/src/app.py" } },
      "expect": { "exit_code": 0 }
    },
    { "hook": ".claude/hooks/stop-gate.sh", "payload": {}, "expect": { "exit_code": 2 } }
  ]
}
```

Failures are reported per step (`step 2: exit_code: want 2, got 0`). A multi-step scenario's top-level `env` applies to every step (a step's own `env` wins), and `{PATH}` in an env value expands to the runner's `PATH` — so `"PATH": "{TMPROOT}/bin:{PATH}"` puts a fake tool from `setup_files` ahead of the real one (make it executable in `setup_commands`).

## What it deliberately does not do

- **No LLM-graded evals.** Hooks are deterministic shell scripts; their behaviour is grounded in exit codes and state-file content. LLM grading would re-introduce non-determinism.
- **No session replay.** The harness invokes hooks directly — one, or a short `steps` sequence — not a full Claude Code session.
- **No cross-tool coverage.** Adapters for Cursor/Codex/Devin are out of scope.
- **No remote scoreboard.** The bench prints results to stdout; CI's check status is the scoreboard.

## Why this exists

The kit's commitment is *"deterministic enforcement"* (ADR-003). Without a bench, that commitment is a vibe. KitBench turns the commitment into a contract — and every PR that touches a hook re-asserts it.

Past bugs that KitBench would have caught (and that several scenarios above directly regression-cover):

- v1.10.0: `composer.lock` slipped through `protect-files` (s02)
- v1.10.0: `EXIT_CODE=$?` after `|| true` always reported "passed" (s08)
- v1.10.0: basename-only match missed `.github/workflows/ci.yml` (s05)
- v1.10.0: word-boundary regex in `prompt-router.sh` rejected "authentication" (s12)
