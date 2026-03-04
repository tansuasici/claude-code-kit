# Hooks Guide

Hooks are shell scripts that run automatically at specific points in Claude Code's workflow. Unlike CLAUDE.md instructions (which are advisory), hooks are **deterministic** — they always execute.

---

## Included Hooks

### PreToolUse (runs BEFORE a tool executes)

| Hook | File | What it does |
|------|------|-------------|
| **protect-files** | `.claude/hooks/protect-files.sh` | Blocks edits to `.env`, credentials, private keys, lock files |
| **branch-protect** | `.claude/hooks/branch-protect.sh` | Blocks direct push to `main`/`master` and force pushes |
| **block-dangerous-commands** | `.claude/hooks/block-dangerous-commands.sh` | Blocks `rm -rf /`, `git reset --hard`, `DROP TABLE`, etc. |

### PostToolUse (runs AFTER a tool executes)

| Hook | File | What it does |
|------|------|-------------|
| **auto-lint** | `.claude/hooks/auto-lint.sh` | Runs linter after file edits (eslint, ruff, gofmt, clippy, rubocop) |
| **auto-format** | `.claude/hooks/auto-format.sh` | Runs formatter after file edits (prettier, black, gofmt, rustfmt) |
| **secret-scan** | `.claude/hooks/secret-scan.sh` | Scans for API keys, tokens, passwords, private keys in edited files |

### Stop (runs when Claude finishes)

| Hook | File | What it does |
|------|------|-------------|
| **task-complete-notify** | `.claude/hooks/task-complete-notify.sh` | Desktop notification + sound on macOS/Linux |

---

## How It Works

Hooks are configured in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/protect-files.sh" }
        ]
      }
    ]
  }
}
```

- **matcher**: which tools trigger the hook (regex pattern)
- **exit 0**: allow the action
- **exit 2**: block the action (PreToolUse only)

The hook receives tool input as JSON via stdin.

---

## Enabling / Disabling Hooks

### Disable a specific hook

Remove or comment out its entry in `.claude/settings.json`.

### Disable auto-lint and auto-format

These are NOT enabled by default in `settings.json` because they can be slow or conflict with project-specific configs. To enable them, add to the PostToolUse section:

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

---

## Writing Your Own Hooks

### Template

```bash
#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | cut -d'"' -f4)
# Extract other fields as needed from the JSON input

# Your logic here

exit 0  # allow (or exit 2 to block in PreToolUse)
```

### Tips

- Keep hooks fast — they run on every tool call
- Use `exit 0` for pass, `exit 2` for block
- Output to stdout is shown to Claude as feedback
- Test hooks manually: `echo '{"tool_name":"Edit","tool_input":{"file_path":".env"}}' | .claude/hooks/your-hook.sh`
