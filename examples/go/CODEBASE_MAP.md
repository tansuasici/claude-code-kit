# CODEBASE_MAP.md

## What

<!-- One paragraph: what this service/CLI does and who uses it. -->
A Go [service / CLI / library] that [does X for Y].

## Why

<!-- The problem it solves and the core constraints (latency, throughput, footprint). -->

## Tech Stack

- **Language**: Go (see `go.mod` for the pinned version)
- **HTTP / RPC**: <!-- net/http, chi, gin, gRPC, connect — pick one and state it -->
- **Persistence**: <!-- database/sql + pgx / sqlc / GORM, or none -->
- **Config**: <!-- env vars, viper, flags -->
- **Logging**: <!-- slog (stdlib), zap, zerolog -->
- **Testing**: standard `testing` + `go test -race` <!-- + testify if used -->

## Key Commands

| Action | Command |
|--------|---------|
| Build | `go build ./...` |
| Run | `go run ./cmd/<app>` |
| Test (with race detector) | `go test ./... -race` |
| Coverage | `go test ./... -cover` |
| Vet | `go vet ./...` |
| Lint | `golangci-lint run` |
| Format | `gofmt -w . && goimports -w .` |
| Tidy modules | `go mod tidy` |

## Directory Structure

```text
.
├── cmd/<app>/          # main packages (entry points)
├── internal/           # private application code (not importable externally)
│   ├── <domain>/       # domain logic
│   └── platform/       # db, http, config wiring
├── pkg/                # exported, reusable packages (if any)
├── go.mod / go.sum     # module definition + checksums
└── Makefile            # common task shortcuts (optional)
```

## Critical Files

| File | Purpose |
|------|---------|
| `go.mod` | Module path, Go version, dependency set (protected) |
| `cmd/<app>/main.go` | Process entry point + wiring |
| `internal/platform/` | DB / HTTP / config bootstrap |
| <!-- add your domain's core packages --> | |

## Architecture

<!-- Layering (handler → service → repository), context flow, concurrency model. -->

## Known Constraints

<!-- Go version floor, CGO on/off, deployment target, perf budgets. -->

## Environment

<!-- Required env vars, secrets management, local dev setup (docker-compose?). -->
