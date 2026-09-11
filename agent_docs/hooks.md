# Hooks Guide

Hooks are shell scripts that run automatically at specific points in Claude Code's workflow. Unlike CLAUDE.md instructions (which are advisory), hooks are **deterministic** — they always execute.

Philosophy: **Use prompts for guidance. Use hooks for behavior that should run every time.** When a rule contains "always", "never", "block", "record", "run", or "verify", it belongs in a hook.

---

## Included Hooks

### SessionStart (runs at session start — and again after each compaction)

SessionStart fires with a `source`: `startup` / `resume` / `clear` for a fresh session, and `compact` mid-session right after a context compaction.

| Hook | File | What it does |
|------|------|-------------|
| **session-start** | `.claude/hooks/session-start.sh` | **On a new session** (`startup`/`resume`/`clear`): auto-injects Tier 1 context — confirms CODEBASE_MAP/CLAUDE.project presence, top rules from `tasks/lessons/_index.md`, active task from `tasks/todo.md`, current git branch, and **working-tree status** (modified/untracked counts + branch-ahead distance when dirty, with a "plan check" nudge). Resets the transient per-session state files. Silent on clean trees. **After a compaction** (`source=compact`): re-injects the working anchors the summary may have blurred — active task, top rules, any active `tasks/*_CONTRACT.md`, and the session journal — and does **not** reset session state (counters and the session clock must survive the compaction). This is the deterministic half of CLAUDE.md → After Compaction; `SessionStart(compact)` is the only compaction-time event whose `additionalContext` reaches the model (`PreCompact`/`PostCompact` cannot inject context). |

### UserPromptSubmit (runs before the model sees each user prompt)

| Hook | File | What it does |
|------|------|-------------|
| **prompt-router** | `.claude/hooks/prompt-router.sh` | Keyword-based context injection. If the prompt mentions auth, billing, migrations, deploy, or dependencies, it injects a one-line reminder for that domain. |
### PreToolUse (runs BEFORE a tool executes)

| Hook | File | What it does |
|------|------|-------------|
| **protect-files** | `.claude/hooks/protect-files.sh` | Blocks edits to `.env`, credentials, private keys, lock files. **Secret protection.** |
| **protect-changes** | `.claude/hooks/protect-changes.sh` | Blocks edits to dependency manifests, migrations, auth/security paths, and core build configs unless `CLAUDE_APPROVED=1`. **Architectural protection.** Enforces CLAUDE.md → Protected Changes. |
| **branch-protect** | `.claude/hooks/branch-protect.sh` | Blocks direct push to `main`/`master` and force pushes |
| **block-dangerous-commands** | `.claude/hooks/block-dangerous-commands.sh` | Blocks `rm -rf /`, `git reset --hard`, `DROP TABLE`, etc. |
| **conventional-commit** | `.claude/hooks/conventional-commit.sh` | Enforces conventional commit message format |
| **glob-guidance** | `.claude/hooks/glob-guidance.sh` | Matcher `Edit\|Write\|NotebookEdit`. **Non-blocking** path-scoped nudge for cross-cutting file patterns (test files, migrations) that don't map to one directory where a subdir `CLAUDE.md` would suffice. One-shot per pattern per session via `.hook-state/glob-guidance-fired`; emits to stderr (the PreToolUse feedback channel) and always exits 0. Customise the case table in the script. |
| **mcp-gate** | `.claude/hooks/mcp-gate.sh` | Matcher `mcp__.*`. MCP supply-chain / prompt-injection governance. Blocks (`exit 2`) any `mcp__<server>__<tool>` call whose `<server>` is absent from `.claude/mcp-allowlist.txt`. **Inert until you create that allowlist** — with no file it never blocks, only reminds once per session that MCP results are untrusted input. Copy `.claude/mcp-allowlist.txt.example` to turn enforcement on; audit with `/mcp-audit`. |

### PostToolUse (runs AFTER a tool executes)

| Hook | File | Matcher | What it does |
|------|------|---------|-------------|
| **secret-scan** | `.claude/hooks/secret-scan.sh` | `Edit\|Write\|NotebookEdit` | Scans edited files for API keys, tokens, passwords |
| **unicode-scan** | `.claude/hooks/unicode-scan.sh` | `Edit\|Write\|NotebookEdit` | Detects invisible Unicode (Glassworm vector) |
| **loop-detect** | `.claude/hooks/loop-detect.sh` | `Edit\|Write\|NotebookEdit` | Warns at 4 edits, blocks at 6 edits to the same file |
| **quality-gate** | `.claude/hooks/quality-gate.sh` | `Edit\|Write\|NotebookEdit` | Runs a fast typecheck/lint (or `bash -n`; for C#/.NET, `dotnet build` of the nearest project — 120s limit unless `CCK_QUALITY_GATE_TIMEOUT` is set) after Edit/Write and records the result per file in `.hook-state/quality-gate-state.json`, with `.hook-state/last_quality_gate.json` as the summary. Statuses: `passed`, `failed`, `timeout`, `error` (command not found or not executable, invalid `commands.json`), and `skipped` with a reason (no check for the file type, tool not installed) — a skipped code file is reported as NOT verified, never as passed. Docs, config and markup files aren't gated. Does NOT block — `stop-gate.sh` does the blocking based on the persisted result. Failures and unverified files reach Claude as PostToolUse `additionalContext`; stderr from a hook that exits 0 only reaches the debug log. If `.claude/commands.json` declares `typecheck`/`lint`, runs the declared command instead of guessing (single source of truth). A key set to `""` turns that check off (the edit is recorded as `skipped`, NOT verified); `timeout` sets the per-check limit; an unknown key or a non-string command is a config `error`. The check runs in the file's package root (nearest `package.json` / `pyproject.toml` / `go.mod` / `Cargo.toml` / `*.csproj` / `*.sln` …, stopping at the git worktree); the result is stored in the project's `.hook-state/` — or, for a file in another git worktree of the same repo, in that worktree's (`lib/roots.sh`). A check that runs past `CCK_QUALITY_GATE_TIMEOUT` (30s) is killed with its whole process group and recorded as `timeout`. |
| **bash-budget** | `.claude/hooks/bash-budget.sh` | `Bash` | Estimates cumulative Bash output token cost per session (chars / 4). One-shot stderr warning when `$BASH_BUDGET_THRESHOLD` (default 50000) is first crossed. Does NOT block — observability only. Writes `.hook-state/bash-budget.json`. |
| **read-budget** | `.claude/hooks/read-budget.sh` | `Read` | Estimates cumulative file-read token cost per session (chars / 4). One-shot stderr warning when `$READ_BUDGET_THRESHOLD` (default 100000) is first crossed — nudges tiered/on-demand loading. Does NOT block. Writes `.hook-state/read-budget.json`. |

### PostToolUseFailure (runs AFTER a tool call fails)

| Hook | File | What it does |
|------|------|-------------|
| **tool-failure-observe** | `.claude/hooks/tool-failure-observe.sh` | Fires when a tool call errors (Bash non-zero exit, failed Edit, …). **Pure observability** — it cannot prevent the failure. Counts failures per session by tool in `.hook-state/tool-failures.json`; `session-end.sh` folds the total (`metrics.tool_failures`) into the scorecard so a thrashing session is visible. Always exits 0. |

### StopFailure (runs when a turn ends on an API error)

| Hook | File | What it does |
|------|------|-------------|
| **stop-failure-observe** | `.claude/hooks/stop-failure-observe.sh` | Fires only when a turn ends on an API-level error (rate limit, auth, server) — **not** on a deliberate `stop-gate` block. Its stdout/exit are ignored by Claude Code (notification/logging only), so it just records the API-error count + last message in `.hook-state/stop-failures.json`. The scorecard (`metrics.api_errors`) uses it to tell "died on infra" from "skipped work". |

### Stop (runs when Claude tries to finish a turn)

| Hook | File | What it does |
|------|------|-------------|
| **stop-gate** | `.claude/hooks/stop-gate.sh` | Blocks completion (exit 2) while any file edited this session lacks a passing check: failed, timed out, errored, or changed since its check (stale files are re-verified at stop, at most 3 check scopes). Reads the state for the checkout the session is working in (the payload's `cwd`, so a session inside a git worktree reads that worktree's result). Files no check covers are listed but don't block. Bypass with `SKIP_QUALITY_GATE=1` env var. Enforces CLAUDE.md → Verification (Mandatory Order). |
| **task-complete-notify** | `.claude/hooks/task-complete-notify.sh` | Desktop notification + sound on macOS/Linux. Runs AFTER stop-gate so failed gates don't trigger the success ping. |

### SessionEnd (runs when the session ends)

| Hook | File | What it does |
|------|------|-------------|
| **session-end** | `.claude/hooks/session-end.sh` | Appends a JSON audit line to `reports/session-audit.log` with session id, exit reason, and last quality-gate status. |
| **journal-fold** | `.claude/hooks/journal-fold.sh` | Consumes `.hook-state/session-journal.md` (populated mid-session by the `/note` skill). If `[finding]` or `[decision]` entries are present, folds them into `tasks/handoff-<session-id>.md`. If only `[summary]` entries, discards. Always removes the journal so the next session starts clean. Silent when no journal exists. |

### Optional (installed but not enabled by default)

These hooks are included in the kit but **not enabled** in the standard profile. They can be slow or conflict with project-specific configs.

| Hook | File | Event | What it does |
|------|------|-------|-------------|
| **auto-lint** | `.claude/hooks/auto-lint.sh` | PostToolUse | Runs linter with --fix after file edits (eslint, ruff, gofmt, clippy, rubocop) |
| **auto-format** | `.claude/hooks/auto-format.sh` | PostToolUse | Runs formatter after file edits (prettier, black, gofmt, rustfmt) |
| **skill-compliance** | `.claude/hooks/skill-compliance.sh` | PostToolUse | Checks edited files against active skills and surfaces relevant checklists |
| **skill-extract-reminder** | `.claude/hooks/skill-extract-reminder.sh` | UserPromptSubmit | Reminds to extract reusable skills from session discoveries |
| **notify-waiting** | `.claude/hooks/notify-waiting.sh` | Notification | Pushes an out-of-terminal ping the moment Claude is **waiting** for you (input or a permission prompt) — so long autonomous runs (`/loop`, auto-mode, `/ship`) don't go dark. Local desktop notification (terminal-notifier / osascript / notify-send), silent if none present. Optional remote push (ntfy / Pushover) is **off by default**, opt-in via env. Strictly advisory — never blocks. Complements `task-complete-notify` (Stop = "done"; this = "waiting"). |

---

## State Files

Several hooks share state through transient files at the project root. Quality-gate results for files in another git worktree of the same repository go to that worktree's own `.hook-state/` instead, so parallel worktrees never block or clear each other (see `agent_docs/worktrees.md`). These are **self-gitignored** (the hook writes a local `.gitignore` inside the directory the first time it creates state). You don't need to add them to your project's root `.gitignore`.

| File | Written by | Read by | Purpose |
|------|-----------|---------|---------|
| `.hook-state/quality-gate-state.json` | `quality-gate.sh` | `stop-gate.sh` | Per-file results (`schema_version` 2): `runs[scope]` — latest result of each check scope `{command, kind, status, exit_code, reason, at, duration_s}`; `files[path]` — `{scope, hash, at}`, or `{status: "skipped", reason}` when no check applies. A file is verified while its scope's latest run passed and its sha256 is unchanged. Reset by `session-start.sh` on a new session, kept across a compaction. |
| `.hook-state/last_quality_gate.json` | `quality-gate.sh` | `stop-gate.sh` (fallback), `session-end.sh` | Summary: the latest run `{exit_code, tool, edited_file, duration_seconds, stderr_tail, last_run_status, reason}` plus the overall verdict — `status` is `failed` / `timeout` / `error` when any file blocks, else `stale`, `passed` or `skipped` — and `blocking_files`, `stale_files`, `unverified_files` |
| `.hook-state/bash-budget.json` | `bash-budget.sh` | `session-end.sh` (scorecard) | Cumulative Bash output token estimate for the session: `{schema_version, cumulative_tokens, threshold, warned, since_session_start, by_command_top5}` |
| `.hook-state/read-budget.json` | `read-budget.sh` | `session-end.sh` (scorecard) | Cumulative file-read token estimate for the session: `{schema_version, cumulative_tokens, threshold, warned, since_session_start, by_file_top5}` |
| `.hook-state/quality-gate-history.json` | `quality-gate.sh`, `stop-gate.sh` | `session-end.sh`, `/scorecard` | Per-session cumulative quality-gate metrics: `{runs, failures, last_status, last_tool, skip_gate_used}`. `skip_gate_used` is incremented by `stop-gate.sh` when the agent bypasses the gate. |
| `.hook-state/verification-ledger.json` | `quality-gate.sh` | `stop-gate.sh`, `/verification-status`, `/ship` | Append-only per-task verification evidence: `{schema_version, entries[{at, tool, status, exit_code, file, duration_s, reason?, scope?}], smoke_test, silent_failures, coverage}` (last 50). Edits no check could cover are logged too, as `skipped` with their reason. Auto-gates written by `quality-gate.sh`; manual slots (smoke test, silent-failure tally) filled via `/verification-status`. |
| `.hook-state/hook-firings.json` | every blocking hook (on `exit 2`) | `session-end.sh`, `/scorecard` | Per-session block counters: `{"protect-files": N, "protect-changes": N, "branch-protect": N, "block-dangerous-commands": N, "mcp-gate": N, "stop-gate": N}`. Reset by `session-start.sh` on a new session. |
| `.hook-state/glob-guidance-fired` | `glob-guidance.sh` | (self) | Plain text, one pattern-id per line (`tests`, `migrations`, …). One-shot ledger so each cross-cutting nudge fires once per session. Removed by `session-start.sh` on a new session. |
| `.hook-state/mcp-banner-fired` | `mcp-gate.sh` | (self) | Empty marker; presence means the once-per-session "MCP output is untrusted" reminder has fired. Removed by `session-start.sh` on a new session. |
| `.hook-state/tool-failures.json` | `tool-failure-observe.sh` | `session-end.sh` (scorecard) | Per-session tool-failure tally: `{schema_version, cumulative, by_tool}`. Reset by `session-start.sh`. |
| `.hook-state/stop-failures.json` | `stop-failure-observe.sh` | `session-end.sh` (scorecard) | Per-session API-error tally: `{schema_version, count, last_error}`. Reset by `session-start.sh`. |
| `.hook-state/session-meta.json` | `session-start.sh` | `session-end.sh` | Identity for the in-progress session: `{session_id, started_at, started_at_epoch}`. Used to compute `session_duration_seconds` and the mtime cutoff for `lessons_added` / `decisions_added`. |
| `reports/session-audit.log` | `session-end.sh` | `/scorecard`, operator review | One JSON line per session. **schema_version 2** records contain a `metrics` object (edits, blocks_fired, quality_gate, lessons_added, decisions_added, bash_token_estimate, compactions_observed, session_duration_seconds). v1 records (just identifiers + `last_quality_gate`) remain parseable. |

The transient `.hook-state/*` files are reset on every `session-start.sh` invocation so counters reflect only the current session. The audit log is append-only across sessions — `/scorecard` aggregates over the requested window.

Both directories are created on demand. Delete them anytime — the next hook run re-creates them.

**Persistence note**: results are per file. A failed `.py` stays failed until a check of that file — or of its whole scope, for project-wide checks such as `tsc` — passes; a pass on another file or an edit to a Markdown file doesn't clear it. A file that changes after its check (through Bash, a formatter, codegen) is stale, and `stop-gate.sh` re-verifies it instead of trusting the old pass. A file no check covers is recorded as `skipped` with a reason: reported as NOT verified, never counted as passed, and not blocking. The per-file state is reset on a new session and kept across a compaction.

---

## Escape Hatches

Some hooks block actions or completion. When they get in the way (broken test infra, intentional hot-fix, etc.) use these environment variables:

| Variable | Effect |
|----------|--------|
| `CLAUDE_APPROVED=1` | `protect-changes.sh` skips its block. Record the rationale in `tasks/decisions.md` (ADR template) — that is the agreed audit trail. |
| `SKIP_QUALITY_GATE=1` | `stop-gate.sh` allows completion even with a failed gate. **For failures unrelated to your change only** (broken infra, intentional WIP) — not to walk past a red gate your own edit caused; that's gaming the gate (see `agent_docs/auto-mode.md → Don't let the loop game the gate`). Use sparingly; the failure is still recorded in `.hook-state/last_quality_gate.json`. |
| `CLAUDE_SKIP_QUALITY_GATE=1` | Alias for the above. |
| `CCK_QUALITY_GATE_TIMEOUT=<seconds>` | Per-check time limit for `quality-gate.sh` (default 30). Past it the check's whole process group is killed and the run is recorded as `timeout`, which `stop-gate.sh` blocks on like a failure. Raise it for a legitimately slow check (a large `tsc`, a cold build). |
| `BASH_BUDGET_THRESHOLD=<n>` | Overrides the default 50000-token threshold used by `bash-budget.sh`. Set to a high number (e.g. 999999999) to suppress the warning entirely; set lower to surface it earlier. |
| `READ_BUDGET_THRESHOLD=<n>` | Overrides the default 100000-token threshold used by `read-budget.sh` (cumulative file-read cost). Same semantics as `BASH_BUDGET_THRESHOLD`. |

Set per-session (`export CLAUDE_APPROVED=1`) or per-command (`CLAUDE_APPROVED=1 claude ...`). Never put these in committed config — they defeat the purpose.

---

## How It Works

Hooks are configured in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|NotebookEdit",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/protect-files.sh" },
          { "type": "command", "command": ".claude/hooks/protect-changes.sh" }
        ]
      }
    ]
  }
}
```

- **matcher**: which tools trigger the hook (regex pattern). Not used for SessionStart/UserPromptSubmit/SessionEnd/Stop.
- **exit 0**: allow the action
- **exit 2**: block the action (PreToolUse only) or block completion (Stop only)
- **stdout**: for SessionStart and UserPromptSubmit, valid JSON of the form `{"additionalContext": "..."}` injects context into the model.
- **stderr**: shown to Claude as feedback regardless of exit code.

The hook receives tool input as JSON via stdin.

---

## Hook Profiles

The installer supports three profiles (`--profile minimal|standard|strict`). Each profile enables a different set of hooks:

| Hook | minimal | standard | strict |
|------|:-------:|:--------:|:------:|
| session-start | ✓ | ✓ | ✓ |
| prompt-router | | ✓ | ✓ |
| protect-files | ✓ | ✓ | ✓ |
| protect-changes | | ✓ | ✓ |
| branch-protect | ✓ | ✓ | ✓ |
| block-dangerous-commands | ✓ | ✓ | ✓ |
| conventional-commit | | ✓ | ✓ |
| glob-guidance | | ✓ | ✓ |
| mcp-gate | | ✓ | ✓ |
| secret-scan | | ✓ | ✓ |
| unicode-scan | | ✓ | ✓ |
| loop-detect | | ✓ | ✓ |
| quality-gate | | ✓ | ✓ |
| bash-budget | | ✓ | ✓ |
| read-budget | | ✓ | ✓ |
| tool-failure-observe | | ✓ | ✓ |
| stop-failure-observe | | ✓ | ✓ |
| stop-gate | | ✓ | ✓ |
| task-complete-notify | | ✓ | ✓ |
| session-end | | ✓ | ✓ |
| auto-lint | | | ✓ |
| auto-format | | | ✓ |
| skill-compliance | | | ✓ |
| skill-extract-reminder | | | ✓ |
| notify-waiting | | | ✓ |

The repository's `.claude/settings.json` represents the **standard** profile. The strict profile is generated by `install.sh` at install time.

---

## Enabling / Disabling Hooks

### Disable a specific hook

Remove or comment out its entry in `.claude/settings.json`.

### Enable optional hooks

To enable auto-lint and auto-format, add to the `PostToolUse` section in `.claude/settings.json`:

```json
{
  "matcher": "Edit|Write",
  "hooks": [
    { "type": "command", "command": ".claude/hooks/auto-lint.sh" },
    { "type": "command", "command": ".claude/hooks/auto-format.sh" }
  ]
}
```

### Enable notify-waiting (out-of-terminal "agent is waiting" ping)

Enabled by default in the **strict** profile. To turn it on elsewhere, add a `Notification` section to `.claude/settings.json`:

```json
"Notification": [
  { "hooks": [ { "type": "command", "command": ".claude/hooks/notify-waiting.sh" } ] }
]
```

With no further config it only fires a **local desktop notification** (via `terminal-notifier`/`osascript` on macOS, `notify-send` on Linux) and is silent where none is installed (CI, headless servers). To also get an **out-of-band push** on another device, opt in with env vars — nothing leaves the machine unless one of these is set:

| Variable | Effect |
|----------|--------|
| `CCK_NOTIFY_NTFY_URL` | Full [ntfy](https://ntfy.sh) topic URL (e.g. `https://ntfy.sh/my-secret-topic`). The waiting message is POSTed there. |
| `CCK_NOTIFY_PUSHOVER_TOKEN` + `CCK_NOTIFY_PUSHOVER_USER` | [Pushover](https://pushover.net) app token **and** user key — both required, or the Pushover branch is skipped. |
| `CCK_NOTIFY_DRY_RUN=1` | Suppresses the real desktop popup and, instead of calling `curl`, prints the remote target(s) to stderr. Use it to verify your config without spamming yourself: `CCK_NOTIFY_DRY_RUN=1 CCK_NOTIFY_NTFY_URL=https://ntfy.sh/t echo '{"message":"test"}' \| .claude/hooks/notify-waiting.sh`. |

The hook is strictly advisory: it always exits 0 and never blocks or mutates tool flow, so a missing binary or an unreachable push endpoint can't stall a run.

### Make secret-scan block instead of warn

Edit `secret-scan.sh` and change the final `exit 0` to `exit 2`.

### Loosen protect-changes for a specific project

Add a project-specific override under `.claude/hooks/project/`. Project hooks are configured separately in settings and are never modified by kit upgrades. Example: a hook that exits 0 for `package.json` if the project owner has pre-approved auto-updates.

---

## Writing Your Own Hooks

### Template

```bash
#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
source "$HOOK_LIB/json-parse.sh"

TOOL_NAME=$(parse_json_field "tool_name")
FILE_PATH=$(parse_json_field "file_path")

# Your logic here

exit 0  # allow (or exit 2 to block in PreToolUse / Stop)
```

### Output JSON (SessionStart, UserPromptSubmit)

For context-injecting hooks, write JSON to stdout:

```bash
printf '%s' "$context" | python3 -c \
  'import json,sys; print(json.dumps({"additionalContext": sys.stdin.read()}))'
```

The kit uses `python3` for safe JSON construction, falling back to `jq`, then to manual bash escaping. Match this pattern.

### Tips

- Keep hooks fast — they run on every tool call. Quality-gate runs each check under a 30s limit through `lib/run-with-timeout.sh`, which kills the whole process group on timeout — use it in any hook that spawns a tool.
- Use `exit 0` for pass, `exit 2` for block
- Output to stderr is shown to Claude as feedback regardless of exit code
- Output to stdout in JSON form (for SessionStart/UserPromptSubmit) is parsed by Claude Code and injected as context
- For Stop hooks: avoid infinite loops. If you block, make sure the condition can become false (e.g., read a state file, don't re-evaluate the same condition forever).
- Test hooks manually: `echo '{"tool_name":"Edit","tool_input":{"file_path":".env"}}' | .claude/hooks/your-hook.sh`
- For hooks that read state, fall back gracefully when the state file doesn't exist (e.g., a fresh checkout).
