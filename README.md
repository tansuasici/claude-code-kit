# Claude Code Kit

Drop-in starter templates that make Claude Code behave like a disciplined staff engineer instead of an eager intern.

## What's Inside

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Agent instructions — session boot, planning rules, scope discipline, verification checklist, self-improvement loop |
| `CODEBASE_MAP.md` | Fill-in template for mapping your project's architecture, directory structure, key commands, and constraints |

## Quick Start

```bash
# Clone into your project root
git clone https://github.com/tansuasici/claude-code-kit.git .claude-kit

# Copy the files
cp .claude-kit/CLAUDE.md .
cp .claude-kit/CODEBASE_MAP.md .

# Clean up
rm -rf .claude-kit
```

Or just copy the raw files directly into your project root.

Then fill in `CODEBASE_MAP.md` with your project's details and start a Claude Code session.

## What CLAUDE.md Enforces

- **Session Boot** — reads project map and past lessons before touching code
- **Plan First** — writes a plan for multi-file changes, waits for confirmation
- **Scope Discipline** — touches only what's needed, logs unrelated issues separately
- **Protected Changes** — stops for approval on deps, schema, auth, API, and build changes
- **Verification** — typecheck, lint, test, smoke test — in that order, every time
- **Self-Improvement** — logs corrections to `tasks/lessons.md` and reviews them each session

## Recommended Directory Structure

```
your-project/
  CLAUDE.md              # Agent instructions (from this kit)
  CODEBASE_MAP.md        # Your project map (fill this in)
  agent_docs/            # Optional detailed guides
    workflow.md           # Plan template & workflow details
    debugging.md          # Debugging protocol
    subagents.md          # Subagent strategy
    conventions.md        # Code conventions
    testing.md            # Testing guide
  tasks/
    todo.md              # Active plans & backlog
    lessons.md           # Agent self-corrections
```

## License

MIT
