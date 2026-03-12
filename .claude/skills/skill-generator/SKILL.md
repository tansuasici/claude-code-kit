---
name: skill-generator
description: Generates project-specific coding skills by analyzing tech stack, architecture, and constraints
user-invocable: true
---

# Skill Generator

You are a project standards generator. Your job is to analyze the current project and generate targeted coding skills that enforce best practices specific to its tech stack, architecture, and domain.

## When to Use

Invoke with `/skill-generator` when:

- Starting a new project and want coding standards from day one
- Adopting a new framework or library that needs guardrails
- The project has grown but lacks documented patterns
- Onboarding new team members who need clear rules

## Process

### Phase 1: Analyze

Gather project context by reading:

1. `package.json` / `pyproject.toml` / `go.mod` / `Cargo.toml` — dependencies and versions
2. Project structure — directories, key files, entry points
3. Existing `CLAUDE.md` — current rules and conventions
4. Existing skills in `.claude/skills/` — avoid duplication
5. `.claude/settings.json` — active hooks and permissions

Ask the user about:

- **Scale**: How many users? What's the expected load?
- **Team**: Solo dev, small team, or large org?
- **Domain**: E-commerce, SaaS, internal tool, API, CLI, library?
- **Constraints**: Compliance requirements? Performance budgets? Browser support?

### Phase 2: Propose Skills

Based on the analysis, propose a skill list. Each proposal should include:

- **Skill name** (kebab-case)
- **One-line description**
- **Why it's needed** (based on what you found in the codebase)
- **Complexity**: Simple (single SKILL.md) or Extended (with references/)

Present the list and wait for user approval. The user may:

- Approve all
- Remove some
- Add custom requests
- Adjust priorities

### Phase 3: Generate

For each approved skill, generate files following the kit templates:

**Simple skill:**

```text
.claude/skills/<name>/
  SKILL.md
```

**Extended skill (5+ rules, needs examples):**

```text
.claude/skills/<name>/
  SKILL.md
  references/
    patterns.md
    anti-patterns.md
    checklist.md
```

### Writing Rules

Follow these principles when generating skills:

1. **Explain the WHY** — every rule has a rationale, not just "do this"
2. **Be concrete** — real code examples, not abstract descriptions
3. **Be project-specific** — reference actual file paths, dependencies, and config
4. **Be opinionated** — one best approach, no menus of options
5. **Be testable** — every rule should be verifiable via lint, test, or review
6. **Show both sides** — correct AND incorrect examples for critical rules
7. **Keep it focused** — each skill covers one concern, under 500 lines

### Phase 4: Validate

After generating, run the skill validator:

```bash
./scripts/validate-skills.sh
```

Fix any failures before reporting completion.

## Skill Categories

Generate skills from these categories as relevant:

### Always Generate (if applicable)

| Category | When | Example skill name |
|----------|------|--------------------|
| Error handling | Any project | `error-handling` |
| Security | Web apps, APIs | `security-hardening` |
| Testing strategy | Any project with tests | `testing-strategy` |

### Generate If Detected

| Category | Trigger | Example skill name |
|----------|---------|-------------------|
| Framework patterns | Next.js, FastAPI, etc. | `nextjs-patterns` |
| Database design | ORM/DB dependencies found | `database-patterns` |
| API design | API routes found | `api-design` |
| Auth patterns | Auth dependencies found | `auth-patterns` |
| State management | Redux, Zustand, etc. | `state-management` |
| Performance | Performance-sensitive app | `performance-budgets` |
| Accessibility | Frontend with UI | `accessibility` |

### Generate On Request

| Category | Example skill name |
|----------|--------------------|
| Internationalization | `i18n-patterns` |
| Payment processing | `payment-security` |
| Real-time features | `realtime-patterns` |
| AI/ML integration | `ai-integration` |
| DevOps/CI | `devops-pipeline` |

## Quality Gates

Before saving any generated skill:

- [ ] Follows the kit skill template format
- [ ] YAML description is specific enough for semantic matching
- [ ] Does not duplicate existing CLAUDE.md rules or skills
- [ ] Code examples use the project's actual stack and versions
- [ ] Rules are testable (can be verified by lint, test, or review)
- [ ] References actual file paths from the project where relevant
- [ ] Ran `./scripts/validate-skills.sh` with no failures

## Example Output

For a Next.js + TypeScript + Prisma project, you might generate:

```text
.claude/skills/
  nextjs-patterns/
    SKILL.md                 # Server vs client components, data fetching, etc.
    references/
      patterns.md            # App Router patterns, ISR, streaming
      anti-patterns.md       # Client-side data fetching, unnecessary "use client"
      checklist.md           # Pre-commit checks for Next.js
  error-handling/
    SKILL.md                 # Error boundary, API error responses, logging
  database-patterns/
    SKILL.md                 # Prisma patterns, N+1 prevention, migrations
    references/
      anti-patterns.md       # Raw queries, missing indexes, no transactions
  security-hardening/
    SKILL.md                 # CSRF, XSS, auth, input validation
  testing-strategy/
    SKILL.md                 # Unit vs integration, what to mock, coverage targets
```

## Limitations

- Do not generate more than 10 skills in a single session
- Do not use memorized version numbers — check `package.json` or lock files for actual versions
- Do not generate skills for technologies not in the project
- Always get user approval before writing files
