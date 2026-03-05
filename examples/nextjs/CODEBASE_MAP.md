# CODEBASE_MAP.md — Next.js Example

## What
A full-stack web application built with Next.js 15 and App Router. Handles [product/service] for [users/audience].

## Why
[Business context — why this project exists, who uses it]

## Tech Stack
- **Framework**: Next.js 15 (App Router)
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **Database**: PostgreSQL via Prisma ORM
- **Auth**: NextAuth.js v5
- **Testing**: Vitest + React Testing Library + Playwright (e2e)

## Key Commands
| Action     | Command                |
|------------|------------------------|
| Dev        | `npm run dev`          |
| Build      | `npm run build`        |
| Test       | `npm test`             |
| Typecheck  | `npx tsc --noEmit`    |
| Lint       | `npm run lint`         |
| E2E        | `npx playwright test`  |
| DB migrate | `npx prisma migrate dev` |

---

## Directory Structure
```text
app/
  ├── (auth)/          # Auth-related pages (login, register)
  ├── (dashboard)/     # Protected dashboard pages
  ├── api/             # API route handlers
  └── layout.tsx       # Root layout
components/
  ├── ui/              # Reusable UI primitives (Button, Input, Modal)
  └── features/        # Feature-specific components
lib/
  ├── db.ts            # Prisma client instance
  ├── auth.ts          # Auth configuration
  └── utils.ts         # Shared utilities
prisma/
  └── schema.prisma    # Database schema
```

## Critical Files
| File | Purpose |
|------|---------|
| `app/layout.tsx` | Root layout, providers, global styles |
| `lib/auth.ts` | Auth config, session handling |
| `lib/db.ts` | Database client, connection management |
| `middleware.ts` | Route protection, redirects |
| `prisma/schema.prisma` | Database schema, all models |

---

## Architecture
Next.js App Router with Server Components by default. Data fetching happens in Server Components or server actions — no client-side `useEffect` for data loading.

Key patterns:
- `app/(dashboard)/layout.tsx` — authenticated layout wrapper, checks session
- `app/api/` — REST endpoints for external integrations
- `lib/db.ts` — singleton Prisma client
- Server actions in `app/actions/` for form mutations

---

## Data Flow
```text
[Browser] → [Middleware (auth check)] → [Server Component / API Route] → [Prisma] → [PostgreSQL]
```

---

## Known Constraints
- Server Components cannot use hooks or browser APIs
- Prisma client must be a singleton (see `lib/db.ts`)
- Middleware runs on Edge Runtime — limited Node.js API access
- `NEXT_PUBLIC_` vars are baked into the client bundle at build time

## Environment
- Config: `.env.local` (gitignored)
- Secrets: managed via environment variables (Vercel / hosting platform)
