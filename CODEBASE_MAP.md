# CODEBASE_MAP.md

## What
<!-- One paragraph: what this project does -->

## Why
<!-- Purpose, who uses it, business context -->

## Tech Stack
<!-- Framework, language, key libraries -->

## Key Commands
| Action     | Command         |
|------------|-----------------|
| Dev        | `[command]`     |
| Build      | `[command]`     |
| Test       | `[command]`     |
| Typecheck  | `[command]`     |
| Lint       | `[command]`     |

---

## Directory Structure
```text
src/
  ├── [module]/       # what it does
  ├── [module]/       # what it does
  └── [module]/       # what it does
```

## Critical Files
<!-- Most important files Claude should know about -->
| File | Purpose |
|------|---------|
| `src/...` | ... |
| `src/...` | ... |

---

## Architecture
<!-- 3–5 sentences: data flow, key patterns, important constraints -->
<!-- Prefer file:line references over inline code blocks -->

Key patterns:
- `src/services/auth.ts:34` — authentication flow
- `src/api/routes/` — all API endpoints
- `src/lib/` — shared utilities

---

## Data Flow
<!-- Optional: how data moves through the system -->
```text
[Client] → [API Layer] → [Service Layer] → [DB/External]
```

---

## External Dependencies
<!-- APIs, services, third-party integrations the agent should know about -->
| Service | Purpose | Docs |
|---------|---------|------|
| ... | ... | ... |

---

## Known Constraints
<!-- Things Claude must NOT do, env limitations, gotchas -->
- ...

## Environment
<!-- .env vars, config files, setup notes -->
- Config: `[file]`
- Secrets: `[how managed]`
