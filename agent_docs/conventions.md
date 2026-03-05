# Code Conventions

These are sensible defaults. Override them in your project's CLAUDE.md if your team has different standards.

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

---

## Code Review Expectations

When reviewing or preparing code for review:

- Every change should be explainable in 1-2 sentences
- If you can't explain why a change is needed, don't make it
- Prefer readability over cleverness
- Prefer explicit over implicit
- Prefer boring, proven patterns over novel approaches
