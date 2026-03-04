# CODEBASE_MAP.md — Python FastAPI Example

## What
A REST API built with FastAPI and Python. Handles [domain] operations for [consumers/clients].

## Why
[Business context — why this API exists, who consumes it]

## Tech Stack
- **Runtime**: Python 3.12
- **Framework**: FastAPI
- **ORM**: SQLAlchemy 2.0 (async)
- **Migrations**: Alembic
- **Validation**: Pydantic v2
- **Auth**: JWT (python-jose)
- **Testing**: pytest + httpx (async test client)
- **Linting**: ruff
- **Type checking**: mypy

## Key Commands
| Action     | Command                          |
|------------|----------------------------------|
| Dev        | `uvicorn app.main:app --reload`  |
| Test       | `pytest`                         |
| Typecheck  | `mypy .`                         |
| Lint       | `ruff check .`                   |
| Format     | `ruff format .`                  |
| Migrate    | `alembic upgrade head`           |
| New migration | `alembic revision --autogenerate -m "description"` |

---

## Directory Structure
```
app/
  ├── api/
  │   ├── v1/
  │   │   ├── endpoints/    # Route handlers grouped by domain
  │   │   └── router.py     # Aggregates all v1 routers
  │   └── deps.py           # Shared dependencies (get_db, get_current_user)
  ├── models/               # SQLAlchemy ORM models
  ├── schemas/              # Pydantic request/response schemas
  ├── services/             # Business logic layer
  ├── repositories/         # Database query layer
  ├── core/
  │   ├── config.py         # Settings via pydantic-settings
  │   ├── security.py       # JWT, password hashing
  │   └── database.py       # Engine, session factory
  └── main.py               # FastAPI app, startup events
alembic/                    # Database migrations
tests/
  ├── conftest.py           # Fixtures (test DB, client, auth)
  ├── test_users.py
  └── test_items.py
```

## Critical Files
| File | Purpose |
|------|---------|
| `app/main.py` | App creation, router registration, middleware |
| `app/core/config.py` | All settings (reads from env vars) |
| `app/core/database.py` | Async engine, session factory |
| `app/core/security.py` | JWT encode/decode, password hash/verify |
| `app/api/deps.py` | `get_db()`, `get_current_user()` dependencies |

---

## Architecture
Layered architecture with FastAPI dependency injection. Routes → Services → Repositories → Database.

Key patterns:
- `app/api/deps.py` — dependency injection for DB sessions and auth
- `app/schemas/` — Pydantic models for all API input/output
- `app/services/` — business logic, called by route handlers
- `app/repositories/` — all SQLAlchemy queries live here

---

## Data Flow
```
[Client] → [FastAPI Middleware] → [Depends (auth, DB)] → [Endpoint] → [Service] → [Repository] → [PostgreSQL]
```

---

## Known Constraints
- Use `async def` for all I/O-bound route handlers
- Pydantic v2 syntax (`model_validator` not `validator`)
- SQLAlchemy 2.0 style queries (`select(Model).where(...)`)
- Alembic autogenerate doesn't catch all changes — always review migrations
- Settings loaded from environment variables via `pydantic-settings`

## Environment
- Config: `.env` (gitignored), see `.env.example` for required variables
- Secrets: JWT_SECRET_KEY, DATABASE_URL — managed via environment variables
