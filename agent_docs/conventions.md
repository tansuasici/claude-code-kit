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

## Match Existing Style

When editing existing code, **match the style of the file you are in** — even if you'd write it differently from scratch. The rule on its own is one line, but the failure modes are subtle, so this section spells them out.

Why it matters: style drift inside a file is invisible until a diff reveals it. Then reviewers spend their attention on the diff noise instead of the actual change. Formatters catch some of this (Prettier, Black, gofmt); naming/async/comment patterns slip through.

This rule complements `CLAUDE.md → Scope Discipline` ("touch ONLY files directly required") — once you've decided to touch a file, the in-file style ratchets.

### Quote style

```ts
// File uses single quotes throughout
import { foo } from 'lib'
const greeting = 'hello'

// BAD — introduces double quotes that don't match the file
const farewell = "goodbye"

// GOOD — match the file
const farewell = 'goodbye'
```

The rule applies even when the surrounding file is "wrong" by your taste. If the codebase has chosen single quotes, you use single quotes.

### Indentation

```py
# File uses 4-space indentation
def existing():
    return 1

# BAD — 2-space indent inside a 4-space file
def added():
  return 2

# GOOD — match the file
def added():
    return 2
```

Same for tabs vs. spaces. The file decides, not you. (If you really think the project's choice is wrong, raise it as a separate issue under `tasks/todo.md → ## Not Now`.)

### Async / promise patterns

```js
// File uses async/await throughout
async function loadUser(id) {
  const data = await fetch(`/api/users/${id}`)
  return data.json()
}

// BAD — mixing in .then() chains
function loadOrder(id) {
  return fetch(`/api/orders/${id}`).then(r => r.json())
}

// GOOD — same shape as siblings
async function loadOrder(id) {
  const r = await fetch(`/api/orders/${id}`)
  return r.json()
}
```

If you must mix paradigms (e.g. consuming an old `.then()`-based API), wrap it locally so the rest of the file stays consistent.

### Naming convention

```py
# File is snake_case throughout
def get_user_by_id(user_id): ...
def list_active_orders(): ...

# BAD — camelCase function in a snake_case file
def listActiveProducts(): ...

# GOOD — match the file
def list_active_products(): ...
```

This applies inside a single file. Different files within the same project may have different conventions for legitimate reasons (e.g. framework code uses `camelCase`, app code uses `snake_case`). Match what you see in the file you're editing.

### Comment style

```ts
// File uses single-line `//` comments throughout
// computes the running average over the last N samples
function avg(samples) { ... }

// BAD — switching to block comments
/**
 * Computes the median.
 */
function median(samples) { ... }

// GOOD — match the file (use JSDoc only if the file already uses JSDoc)
// computes the median over the last N samples
function median(samples) { ... }
```

If the file uses JSDoc / docstrings / Doxygen comments on its functions, your new function gets one too. If it doesn't, you don't add one just because "they're nicer."

### Quick checklist before submitting an edit

- [ ] Quote style — matches the surrounding file
- [ ] Indentation — matches the surrounding file (spaces vs. tabs, width)
- [ ] Async pattern — `async/await` vs. `.then()` matches siblings
- [ ] Naming — function/variable casing matches siblings in the same file
- [ ] Comments — same style and density as the surrounding code

If you genuinely cannot follow one of these (e.g. the file is empty, or you're creating a new one), follow the project's overall convention as inferred from sibling files in the same directory.

### When this rule does not apply

- **Whole-file rewrites** when scoped as an explicit task ("rewrite `users.service.ts` in modern style") — the rule that gets ratcheted is *project-wide* convention, not the old file's drift.
- **New files** where there is no existing style to match — fall back to the project's overall convention.
- **Generated files** (codegen output, vendored deps) — leave them alone, they're not "yours".

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

## Code Review Expectations

When reviewing or preparing code for review:

- Every change should be explainable in 1-2 sentences
- If you can't explain why a change is needed, don't make it
- Prefer readability over cleverness
- Prefer explicit over implicit
- Prefer boring, proven patterns over novel approaches
