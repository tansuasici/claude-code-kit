# CODEBASE_MAP.md — Node.js API Example

## What
A REST API service built with Express.js and TypeScript. Handles [domain] operations for [consumers/clients].

## Why
[Business context — why this API exists, who consumes it]

## Tech Stack
- **Runtime**: Node.js 22
- **Framework**: Express.js
- **Language**: TypeScript
- **Database**: PostgreSQL via Knex.js (query builder)
- **Validation**: Zod
- **Auth**: JWT (jsonwebtoken)
- **Testing**: Jest + Supertest

## Key Commands
| Action     | Command                  |
|------------|--------------------------|
| Dev        | `npm run dev`            |
| Build      | `npm run build`          |
| Test       | `npm test`               |
| Typecheck  | `npx tsc --noEmit`      |
| Lint       | `npm run lint`           |
| Migrate    | `npx knex migrate:latest`|
| Seed       | `npx knex seed:run`      |

---

## Directory Structure
```text
src/
  ├── routes/          # Express route definitions
  ├── controllers/     # Request handling (validate → call service → respond)
  ├── services/        # Business logic layer
  ├── repositories/    # Database queries
  ├── middleware/       # Auth, error handling, validation, logging
  ├── types/           # TypeScript type definitions
  └── utils/           # Shared helpers
migrations/            # Database migrations
seeds/                 # Test/dev seed data
```

## Critical Files
| File | Purpose |
|------|---------|
| `src/app.ts` | Express app setup, middleware registration |
| `src/server.ts` | Entry point, starts the HTTP server |
| `src/middleware/auth.ts` | JWT verification, role checking |
| `src/middleware/error.ts` | Global error handler |
| `knexfile.ts` | Database connection config |

---

## Architecture
Layered architecture: Routes → Controllers → Services → Repositories → Database.

Key patterns:
- `src/middleware/auth.ts` — JWT verification, attaches `req.user`
- `src/middleware/error.ts` — catches all errors, returns consistent JSON
- `src/repositories/` — all SQL lives here, nowhere else
- Controllers validate input with Zod, then delegate to services

---

## Data Flow
```text
[Client] → [Express Middleware (auth, logging)] → [Controller (validate)] → [Service (logic)] → [Repository (SQL)] → [PostgreSQL]
```

---

## Known Constraints
- All DB queries must use parameterized queries (no string interpolation)
- JWT secret must be in environment variables
- Rate limiting is applied globally in production
- Migrations must be reversible (include `down` function)

## Environment
- Config: `.env` (gitignored), see `.env.example` for required variables
- Secrets: JWT_SECRET, DATABASE_URL — managed via environment variables
