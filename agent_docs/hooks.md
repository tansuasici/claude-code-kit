# Hooks Guide

Hooks are shell scripts that run automatically at specific points in Claude Code's workflow. Unlike CLAUDE.md instructions (which are advisory), hooks are **deterministic** — they always execute.

Philosophy: **Use prompts for guidance. Use hooks for behavior that should run every time.** When a rule contains "always", "never", "block", "record", "run", or "verify", it belongs in a hook.

---

## Included Hooks

### SessionStart (runs once, at the start of a session)

| Hook | File | What it does |
|------|------|-------------|
| **session-start** | `.claude/hooks/session-start.sh` | Auto-injects Tier 1 context: confirms CODEBASE_MAP/CLAUDE.project presence, top rules from `tasks/lessons/_index.md`, active task from `tasks/todo.md`, current git branch. Replaces the prompt rule "read Tier 1 files at session start". |

### UserPromptSubmit (runs before the model sees each user prompt)

| Hook | File | What it does |
|------|------|-------------|
| **prompt-router** | `.claude/hooks/prompt-router.sh` | Keyword-based context injection. If the prompt mentions auth, billing, migrations, deploy, or dependencies, it injects a one-line reminder for that domain. |
| **skill-extract-reminder** | `.claude/hooks/skill-extract-reminder.sh` | Strict profile only. Nudges the agent to consider extracting a skill if it discovered something non-obvious. |

### PreToolUse (runs BEFORE a tool executes)

| Hook | File | What it does |
|------|------|-------------|
| **protect-files** | `.claude/hooks/protect-files.sh` | Blocks edits to `.env`, credentials, private keys, lock files. **Secret protection.** |
| **protect-changes** | `.claude/hooks/protect-changes.sh` | Blocks edits to dependency manifests, migrations, auth/security paths, and core build configs unless `CLAUDE_APPROVED=1`. **Architectural protection.** Enforces CLAUDE.md → Protected Changes. |
| **branch-protect** | `.claude/hooks/branch-protect.sh` | Blocks direct push to `main`/`master` and force pushes |
| **block-dangerous-commands** | `.claude/hooks/block-dangerous-commands.sh` | Blocks `rm -rf /`, `git reset --hard`, `DROP TABLE`, etc. |
| **conventional-commit** | `.claude/hooks/conventional-commit.sh` | Enforces conventional commit message format |

### PostToolUse (runs AFTER a tool executes)

| Hook | File | What it does |
|------|------|-------------|
| **secret-scan** | `.claude/hooks/secret-scan.sh` | Scans edited files for API keys, tokens, passwords |
| **unicode-scan** | `.claude/hooks/unicode-scan.sh` | Detects invisible Unicode (Glassworm vector) |
| **loop-detect** | `.claude/hooks/loop-detect.sh` | Warns at 4 edits, blocks at 6 edits to the same file |
| **quality-gate** | `.claude/hooks/quality-gate.sh` | Runs a fast typecheck/lint after Edit/Write, writes `.hook-state/last_quality_gate.json`. Does NOT block — `stop-gate.sh` does the blocking based on the persisted result. |

### Stop (runs when Claude tries to finish a turn)

| Hook | File | What it does |
|------|------|-------------|
| **stop-gate** | `.claude/hooks/stop-gate.sh` | Reads `.hook-state/last_quality_gate.json`; if status is "failed", blocks completion with exit 2. Bypass with `SKIP_QUALITY_GATE=1` env var. Enforces CLAUDE.md → Verification (Mandatory Order). |
| **task-complete-notify** | `.claude/hooks/task-complete-notify.sh` | Desktop notification + sound on macOS/Linux. Runs AFTER stop-gate so failed gates don't trigger the success ping. |

### SessionEnd (runs when the session ends)

| Hook | File | What it does |
|------|------|-------------|
| **session-end** | `.claude/hooks/session-end.sh` | Appends a JSON audit line to `reports/session-audit.log` with session id, exit reason, and last quality-gate status. |

### Optional (installed but not enabled by default)

These hooks are included in the kit but **not enabled** in the standard profile. They can be slow or conflict with project-specific configs.

| Hook | File | Event | What it does |
|------|------|-------|-------------|
| **auto-lint** | `.claude/hooks/auto-lint.sh` | PostToolUse | Runs linter with --fix after file edits (eslint, ruff, gofmt, clippy, rubocop) |
| **auto-format** | `.claude/hooks/auto-format.sh` | PostToolUse | Runs formatter after file edits (prettier, black, gofmt, rustfmt) |
| **skill-compliance** | `.claude/hooks/skill-compliance.sh` | PostToolUse | Checks edited files against active skills and surfaces relevant checklists |
| **skill-extract-reminder** | `.claude/hooks/skill-extract-reminder.sh` | UserPromptSubmit | Reminds to extract reusable skills from session discoveries |

---

## State Files

Three hooks share state through transient files at the project root. These are **self-gitignored** (the hook writes a local `.gitignore` inside the directory the first time it creates state). You don't need to add them to your project's root `.gitignore`.

| File | Written by | Read by | Purpose |
|------|-----------|---------|---------|
| `.hook-state/last_quality_gate.json` | `quality-gate.sh` | `stop-gate.sh`, `session-end.sh` | Most recent verification result: `{status, exit_code, tool, edited_file, duration_seconds, stderr_tail}` |
| `reports/session-audit.log` | `session-end.sh` | (operator review) | One JSON line per session: timestamp, session_id, reason, transcript_path, last_quality_gate |

Both directories are created on demand. Delete them anytime — the next hook run re-creates them.

**Persistence note**: `last_quality_gate.json` is written when a verification *runs*; if `quality-gate.sh` skips (no suitable tool for the file extension, no `tsconfig.json`, etc.) the previous state is left intact. That means a failed `.py` followed by an unrelated `.md` edit keeps `stop-gate.sh` blocking until you re-edit the `.py` and the gate flips back to passed. This is intentional — failures should not be cleared by activity on unrelated files.

---

## Escape Hatches

Some hooks block actions or completion. When they get in the way (broken test infra, intentional hot-fix, etc.) use these environment variables:

| Variable | Effect |
|----------|--------|
| `CLAUDE_APPROVED=1` | `protect-changes.sh` skips its block. Record the rationale in `tasks/decisions.md` (ADR template) — that is the agreed audit trail. |
| `SKIP_QUALITY_GATE=1` | `stop-gate.sh` allows completion even with a failed gate. Use sparingly; the failure is still recorded in `.hook-state/last_quality_gate.json`. |
| `CLAUDE_SKIP_QUALITY_GATE=1` | Alias for the above. |

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
| secret-scan | | ✓ | ✓ |
| unicode-scan | | ✓ | ✓ |
| loop-detect | | ✓ | ✓ |
| quality-gate | | ✓ | ✓ |
| stop-gate | | ✓ | ✓ |
| task-complete-notify | | ✓ | ✓ |
| session-end | | ✓ | ✓ |
| auto-lint | | | ✓ |
| auto-format | | | ✓ |
| skill-compliance | | | ✓ |
| skill-extract-reminder | | | ✓ |

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

- Keep hooks fast — they run on every tool call. Quality-gate runs verification under a 30s timeout.
- Use `exit 0` for pass, `exit 2` for block
- Output to stderr is shown to Claude as feedback regardless of exit code
- Output to stdout in JSON form (for SessionStart/UserPromptSubmit) is parsed by Claude Code and injected as context
- For Stop hooks: avoid infinite loops. If you block, make sure the condition can become false (e.g., read a state file, don't re-evaluate the same condition forever).
- Test hooks manually: `echo '{"tool_name":"Edit","tool_input":{"file_path":".env"}}' | .claude/hooks/your-hook.sh`
- For hooks that read state, fall back gracefully when the state file doesn't exist (e.g., a fresh checkout).
