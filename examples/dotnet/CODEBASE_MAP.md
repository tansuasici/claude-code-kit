# CODEBASE_MAP.md

## What

<!-- One paragraph: what this application/service does and who uses it. -->
A .NET [web API / web app / worker / library] that [does X for Y].

## Why

<!-- The problem it solves and the core constraints (latency, throughput, hosting, compliance). -->

## Tech Stack

- **Runtime**: .NET (see `TargetFramework` in the `.csproj` files and `global.json`)
- **Web**: <!-- ASP.NET Core minimal APIs / MVC controllers / Blazor / none -->
- **Persistence**: <!-- EF Core + PostgreSQL / SQL Server / Dapper / none -->
- **Messaging / jobs**: <!-- MassTransit, Hangfire, hosted services, or none -->
- **Logging**: <!-- Microsoft.Extensions.Logging + Serilog / OpenTelemetry -->
- **Testing**: <!-- xUnit / NUnit / MSTest + FluentAssertions / Testcontainers -->

## Key Commands

| Action | Command |
|--------|---------|
| Restore | `dotnet restore` |
| Build | `dotnet build` |
| Run | `dotnet run --project src/<App>` |
| Test | `dotnet test` |
| Format check | `dotnet format --verify-no-changes` |
| Add a migration | `dotnet ef migrations add <Name> --project src/<Infrastructure> --startup-project src/<App>` |
| Apply migrations | `dotnet ef database update --project src/<Infrastructure> --startup-project src/<App>` |

## Directory Structure

```text
.
├── <Solution>.sln              # solution — every project is listed here
├── global.json                 # SDK pin (optional)
├── Directory.Build.props       # shared MSBuild settings (optional)
├── Directory.Packages.props    # central package versions (optional)
├── src/
│   ├── <App>/                  # host: Program.cs, endpoints/controllers, DI wiring
│   ├── <Domain>/               # entities, domain logic (no framework dependencies)
│   └── <Infrastructure>/       # EF Core DbContext, migrations, external clients
└── tests/
    └── <App>.Tests/            # unit + integration tests
```

## Critical Files

| File | Purpose |
|------|---------|
| `src/<App>/Program.cs` | Host builder, DI registrations, middleware pipeline order (protected) |
| `src/<App>/appsettings.json` | Non-secret configuration defaults |
| `src/<Infrastructure>/Migrations/` | EF Core migrations (protected — never edit an applied one) |
| `*.csproj` / `Directory.Packages.props` | Target framework and NuGet dependencies (protected) |
| <!-- add your domain's core files --> | |

## Architecture

<!-- Layering (endpoint → application service → domain → infrastructure), DI lifetimes, request pipeline, background work. -->

## Known Constraints

<!-- SDK/runtime version floor, hosting target (container, IIS, Azure App Service), perf budgets, AOT/trimming. -->

## Environment

<!-- Required environment variables, user-secrets keys, connection strings, local dev setup (docker compose for the database?). -->
