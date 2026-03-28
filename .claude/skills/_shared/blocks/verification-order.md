## Verification Order

If this skill produces code changes, verify in this exact order before marking complete:
1. **Typecheck** — `tsc --noEmit`, `mypy`, `go vet`, etc.
2. **Lint** — `eslint`, `ruff`, `golangci-lint`, `clippy`, etc.
3. **Test** — `npm test`, `pytest`, `go test`, `cargo test`, etc.
4. **Smoke test** — verify real behavior (call endpoint, open page, run CLI)

Do not skip steps. Do not mark the task complete until all four pass.
