# CLAUDE.md — .NET Project

## Session Boot (Tiered)
At the start of every session, load context in tiers — not everything at once.

> _Partially enforced via_ `.claude/hooks/session-start.sh` _— it auto-injects pointers to Tier 1 files, the top rules, the active task, and the current branch. You still need to_ Read _the files themselves._

**Tier 1 — Always (project awareness):**
1. Read `CODEBASE_MAP.md`
2. Read `CLAUDE.project.md` if it exists

**Tier 2 — If continuing work (active task context):**
3. Read the latest `tasks/handoff-*.md` — only if one exists (indicates interrupted session)
4. Read `tasks/todo.md` — only if active tasks exist

**Tier 3 — On demand (load when relevant):**
5. `tasks/lessons/_index.md` — read the `## Top Rules` section (first 15 lines). Read individual lesson files only when a decision could repeat a past mistake.
6. `tasks/decisions.md` — read only when facing architectural choices or protected changes.

Restate the current task in 1-2 sentences before doing anything. Never start coding before Tier 1 is loaded.

---

## After Compaction
Context compaction can happen mid-session. When you detect a compaction (conversation summary, loss of earlier details):
1. Re-read `tasks/todo.md` — restore awareness of the current task plan
2. Re-read the specific files you were actively editing
3. Re-read any contract file (`tasks/*_CONTRACT.md`) if one was active
4. Re-read `tasks/lessons/_index.md` → `## Top Rules` section only
5. Re-read `.hook-state/session-journal.md` if it exists — pre-compaction findings journaled with `/note` (lives only inside the current session; folded into the handoff at session end)
6. Do NOT continue coding until you've re-established context

This is the single most important rule for long sessions.

---

## Tech-Specific Rules

### C# / .NET
- Target the framework the project already declares (`TargetFramework` in the `.csproj`, SDK pin in `global.json`); don't bump either without approval.
- Nullable reference types stay enabled. Don't silence a warning with `!` unless a comment says why the value can't be null.
- Async all the way: no `.Result`, `.Wait()` or `async void` (event handlers excepted). Accept a `CancellationToken` and pass it on to every awaited call that takes one.
- Constructor injection through the built-in container. No service locator (`IServiceProvider` in business code), no `static` mutable state.
- Configuration through `IOptions<T>` bound from `appsettings*.json` and environment variables. Secrets live in user-secrets or the environment, never in a committed `appsettings` file.
- Don't swallow exceptions: a `catch (Exception)` must log and rethrow or translate to a result. APIs return `ProblemDetails` for errors.
- Dispose what you create (`using` / `await using`); get `HttpClient` from `IHttpClientFactory`, never `new HttpClient()` per call.

### Data access (EF Core)
- Schema changes go through migrations (`dotnet ef migrations add <Name>`). Never edit a migration that has already been applied anywhere.
- Read-only queries use `AsNoTracking()`. Avoid N+1: project with `Select` or load related data with `Include` deliberately.
- Keep `DbContext` scoped per request; never share one across threads.

### Project layout & style
- Follow the existing solution layout (e.g. `src/<Project>/`, `tests/<Project>.Tests/`). New projects join the `.sln`.
- Match `.editorconfig` and `dotnet format` exactly — file-scoped namespaces, `var` usage and naming as the codebase already does.
- Tests use the framework the solution already uses (xUnit / NUnit / MSTest) and its assertion style; don't add a second one.

---

## Plan First
For any task touching 3+ files, architectural decisions, new dependencies, or workflow changes:
- Write a plan to `tasks/todo.md` using the template in `agent_docs/workflow.md`
- Do not implement until the plan is confirmed

---

## Scope Discipline
- Touch ONLY files directly required by the task
- Never refactor opportunistically
- Log unrelated issues under `tasks/todo.md > ## Not Now`
- State every assumption explicitly before acting on it

---

## Protected Changes (Approval Required)
Stop and request approval before:
- New NuGet packages or version changes (`PackageReference` in a `.csproj`, `Directory.Packages.props`)
- `TargetFramework`, `LangVersion` or `global.json` SDK changes; `Directory.Build.props` / `.targets`
- EF Core migrations or database schema changes
- Public API changes (controllers, contracts, shared packages)
- Auth / authorization logic (policies, schemes, middleware)
- Middleware pipeline order in `Program.cs`
- `Dockerfile`, CI, or deployment config changes

---

## Verification (Mandatory Order)
1. `dotnet build` — no errors; no new warnings (use `-warnaserror` if the project builds that way)
2. `dotnet format --verify-no-changes`
3. `dotnet test`
4. Smoke test: run the app (`dotnet run --project src/<App>`) and hit the endpoint / page you changed
5. Optional before merge: `/review-pipeline` for multi-lens audit over the PR diff

The quality gate builds the nearest project after each edit. A cold build is slow — declare a fast check in `.claude/commands.json` (`"typecheck": "dotnet build src/<App>/<App>.csproj --no-restore -nologo -v q"`) or raise `CCK_QUALITY_GATE_TIMEOUT`.

---

## Self-Improvement Loop
- After ANY correction from the user: add a lesson under `tasks/lessons/` using `tasks/lessons/_TEMPLATE.md` (file name: `<YYYY-MM-DD>-<slug>.md`)
- Format: frontmatter + Issue > Root Cause > Rule (see `tasks/lessons/_TEMPLATE.md`)
- Promote critical rules to `tasks/lessons/_index.md` → `## Top Rules` (set `top_rule: true`)
- Review `tasks/lessons/_index.md` at every session start

---

## Core Principles
- **Simplicity First**: smallest effective change, minimal impact
- **No Laziness**: find root causes, no temporary patches
- **Deterministic**: Plan → Implement → Verify → Review, every time

---

## Agent Docs
Read only what's relevant to the current task:
- Full workflow & plan template → `agent_docs/workflow.md`
- Debugging protocol → `agent_docs/debugging.md`
- Subagent strategy → `agent_docs/subagents.md`
- Code conventions → `agent_docs/conventions.md`
- Testing guide → `agent_docs/testing.md`
- Hooks guide → `agent_docs/hooks.md`
- Skills guide → `agent_docs/skills.md`
- Task contracts (completion criteria) → `agent_docs/contracts.md`
- Prompting & bias awareness → `agent_docs/prompting.md`
