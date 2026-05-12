# Language-Specific Error Patterns

Lookup table of frequently misdiagnosed errors and their common root causes. Use to accelerate hypothesis formation in Phase 2 of `/debug`.

Not exhaustive — these are errors that **waste the most investigation time** when diagnosed wrong. If you do not see your error here, fall back to first-principles investigation.

## Python

| Error | Common Root Cause |
|---|---|
| `ImportError` / `ModuleNotFoundError` | Venv not activated, missing `pip install`, missing `__init__.py` |
| `TypeError: X got an unexpected keyword argument` | Function signature changed, wrong overload |
| `AttributeError: 'NoneType'` | Upstream query returned None, missing null check |
| Django `OperationalError: no such table` | Missing migration — run `makemigrations` + `migrate` |
| `RecursionError: maximum recursion depth` | Circular import or unintended self-call |

## TypeScript / JavaScript

| Error | Common Root Cause |
|---|---|
| `TS2322: Type X is not assignable to type Y` | Missing generic param, null not in union, async return type |
| `Cannot find module` | tsconfig `paths` misconfigured, missing `package.json` exports field |
| Next.js hydration mismatch | Server/client component boundary issue, browser-only API in SSR |
| `TypeError: X is not a function` | Default vs named export mismatch, circular dependency |
| `Unhandled Promise Rejection` | Missing `await`, swallowed catch, fire-and-forget async |

## Go

| Error | Common Root Cause |
|---|---|
| `undefined: X` | Unexported (lowercase) identifier, missing import, wrong build tag |
| `cannot use X as type Y` | Interface not satisfied — check method signature and pointer receiver |
| `fatal error: concurrent map writes` | Shared map without mutex — use `sync.Map` or add locking |
| `context deadline exceeded` | Upstream timeout — check context propagation chain |

## Rust

| Error | Common Root Cause |
|---|---|
| `borrow of moved value` | Use `clone()`, pass reference, or restructure ownership |
| `lifetime does not live long enough` | Add explicit lifetime annotations or restructure to avoid references |
| `the trait X is not implemented for Y` | Missing `derive`, wrong generic bounds, need `impl` block |
| `cannot borrow as mutable more than once` | Split borrows or use `RefCell` / `Cell` for interior mutability |
