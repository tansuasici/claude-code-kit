# CODEBASE_MAP.md

## What

<!-- One paragraph: what this crate/binary does and who uses it. -->
A Rust [CLI / service / library crate] that [does X for Y].

## Why

<!-- The problem it solves and the core constraints (safety, latency, footprint). -->

## Tech Stack

- **Language**: Rust (edition + toolchain pinned in `Cargo.toml` / `rust-toolchain.toml`)
- **Async runtime**: <!-- tokio / async-std / none -->
- **Web / RPC**: <!-- axum, actix-web, tonic — or none -->
- **Error handling**: <!-- thiserror (libs) / anyhow (bins) -->
- **Persistence**: <!-- sqlx, diesel, sea-orm — or none -->
- **Testing**: `cargo test` <!-- + proptest / insta if used -->

## Key Commands

| Action | Command |
|--------|---------|
| Build | `cargo build` |
| Release build | `cargo build --release` |
| Run | `cargo run` |
| Test | `cargo test` |
| Lint (deny warnings) | `cargo clippy --all-targets -- -D warnings` |
| Format | `cargo fmt` |
| Check | `cargo check --all-targets` |
| Docs | `cargo doc --open` |

## Directory Structure

```text
.
├── src/
│   ├── main.rs         # binary entry point (or lib.rs for a library)
│   ├── lib.rs          # crate root + public API re-exports
│   └── <module>/       # cohesive modules
├── tests/              # integration tests
├── benches/            # benchmarks (optional)
├── Cargo.toml          # crate manifest + dependencies (protected)
└── Cargo.lock          # pinned dependency graph
```

## Critical Files

| File | Purpose |
|------|---------|
| `Cargo.toml` | Crate metadata, edition, dependencies (protected) |
| `src/main.rs` / `src/lib.rs` | Entry point / crate API surface |
| `src/error.rs` | Error enum(s) (`thiserror`) if centralized |
| <!-- add your core modules --> | |

## Architecture

<!-- Module boundaries, ownership/lifetime strategy, async task structure. -->

## Known Constraints

<!-- MSRV (minimum supported Rust version), no_std?, unsafe policy, perf budgets. -->

## Environment

<!-- Required env vars, secrets, local dev setup, feature flags. -->
