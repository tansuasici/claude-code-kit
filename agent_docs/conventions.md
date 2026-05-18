# Code Conventions

These are sensible defaults. Override them in `CLAUDE.project.md` if your team has different standards.

---

## File Naming

| Type | Convention | Example |
|------|-----------|---------|
| Source files | kebab-case or match framework convention | `user-service.ts`, `UserService.java` |
| Test files | same name + `.test` or `.spec` | `user-service.test.ts` |
| Config files | lowercase, dotfiles where conventional | `.eslintrc.js`, `tsconfig.json` |
| Docs | UPPER for root, kebab-case for guides | `README.md`, `setup-guide.md` |

---

## Project Structure Principles

- Group by feature/domain, not by type (prefer `user/` over `controllers/`)
- Keep related files close together
- Shared utilities go in `lib/` or `utils/` — not in feature folders
- One clear entry point per module
- If a folder has 1 file, it probably shouldn't be a folder

---

## Naming

### General Rules

- Names should describe **what**, not **how**
- Longer scope = longer name (module-level > local variable)
- Booleans: use `is`, `has`, `should`, `can` prefix
- Functions: use verb prefix (`get`, `create`, `update`, `delete`, `validate`, `parse`)
- Constants: UPPER_SNAKE_CASE for true constants, camelCase for config

### Anti-patterns

| Bad | Better | Why |
|-----|--------|-----|
| `data`, `info`, `item` | `user`, `invoice`, `cartItem` | Too vague |
| `processData` | `validateUserInput` | What does "process" mean? |
| `flag`, `temp`, `x` | `isActive`, `cachedResult`, `retryCount` | Meaningless |
| `handleClick` (in backend) | `submitOrder` | UI terminology in business logic |

---

## Comments

### When to comment

- **Why** something is done a non-obvious way
- **Constraints** that aren't visible in code (rate limits, external API quirks)
- **TODO** with context for known shortcuts or tech debt

### When NOT to comment

- What the code does (if the code is readable)
- Obvious type annotations
- Section dividers (`// ======= UTILS =======`)
- Commented-out code (delete it, git has history)

---

## Error Handling

- Fail fast and loud — don't swallow errors silently
- Use typed errors / error codes, not just strings
- Handle errors at the right level (not too early, not too late)
- Log errors with context (what was happening, what input caused it)
- Don't catch errors you can't handle — let them bubble up

---

## Imports

- Group imports: stdlib/framework → external deps → internal modules
- Prefer named exports over default exports (easier to grep)
- No circular imports — if you need one, your architecture needs work
- Import from the public API of a module, not from internal files

---

## Git Hygiene

### Branches

```text
feat/short-description
fix/short-description
refactor/short-description
chore/short-description
```

### Commits

- One logical change per commit
- Commit message explains **why**, diff shows **what**
- Don't commit: `.env`, `node_modules`, build artifacts, IDE configs, OS files
- Don't commit broken code to main (even as WIP)

### Merging Pull Requests

- **Use squash merge only** (`gh pr merge --squash`).
- Merge commits with `--merge` produce a synthesized merge commit whose body inherits the feature branch's HEAD subject. release-please then sees both the original commit AND the merge commit as separate `feat:`/`fix:` entries — every PR shows up twice in the changelog.
- Squash merging produces one commit on `main` with the PR title as subject. release-please records one entry. Linear history.
- Rebase merge avoids the duplicate problem too but pollutes `main` with the branch's intermediate commits.
- Both `claude-code-kit` and `claude-code-kit-web` are configured GitHub-side to accept squash only — the other strategies are disabled at repo level.

---

## Compact Output Flags

Bash output is the #1 context-window consumer in agentic sessions. The `bash-budget.sh` PostToolUse hook tracks cumulative output cost and warns once when the session crosses `$BASH_BUDGET_THRESHOLD` (default 50 000 tokens). To stay under the line, prefer the compact form of common commands. The verbose form is fine for one-shot inspection; reach for the compact form once a command appears in a loop or is run on a large repo.

| Verbose | Compact | When to use the compact form |
|---------|---------|------------------------------|
| `git status` | `git status --short` | Exploring repo state; the long form repeats the same hints every call |
| `git diff` | `git diff --stat` (then `git diff <file>` selectively) | Surveying a change set before drilling in |
| `git log` | `git log --oneline -n 20` | Recent-history scan; full bodies needed rarely |
| `pytest` | `pytest -q --tb=line` | Smoke / pass-fail check; full traceback only on red |
| `cargo test` | `cargo test --quiet` | Compile + pass/fail summary; expand on failure |
| `cargo build` | `cargo build --message-format=short` | Build error count; full diagnostics on demand |
| `go test ./...` | `go test -count=1 ./... 2>&1 \| tail -40` | Trim the per-package PASS spam, surface the tail |
| `npm test` | `npm test --silent` | Drops setup chatter; keep verbose for the failing case |
| `rg "pat" .` | `rg --count "pat" .` or `rg -l "pat" .` | Counts or filenames first; widen to context only after a target picks itself |
| `find . -name '*.x'` | `fd -e x` (or `rg --files \| rg '\.x$'`) | Faster + shorter listing |
| `tree` | `ls -F` or `tree -L 2 -I 'node_modules\|.git'` | Bounded depth and exclusions |
| `kubectl logs` | `kubectl logs --tail=200` | Avoid full-history dump; widen only after sampling |
| `docker logs` | `docker logs --tail=200 --since=10m` | Same — bounded by time and lines |
| `cat <file>` | `head -50 <file>` / `tail -50 <file>` | Sample first; full Read via the Read tool is cheaper than `cat` in long files |

When the hook fires its one-shot warning, switch to the compact column for high-volume commands for the rest of the session. Avoid piping large outputs through `cat`/`echo` echoes — they double the token count without adding signal.

---

## Code Review Expectations

When reviewing or preparing code for review:

- Every change should be explainable in 1-2 sentences
- If you can't explain why a change is needed, don't make it
- Prefer readability over cleverness
- Prefer explicit over implicit
- Prefer boring, proven patterns over novel approaches
