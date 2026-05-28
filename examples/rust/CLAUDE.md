# CLAUDE.md — Rust Project

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

### Rust
- Honor the edition + toolchain pinned in `Cargo.toml` / `rust-toolchain.toml`; don't change them without approval.
- Errors: return `Result<T, E>` with a typed error enum (`thiserror` for libraries, `anyhow` for binaries — match what the project uses). Propagate with `?`. **No `.unwrap()` / `.expect()` in non-test code** unless an invariant is documented inline.
- Prefer borrowing over cloning. Don't sprinkle `.clone()` to silence the borrow checker — restructure ownership instead.
- `unsafe` requires explicit approval and a `// SAFETY:` comment justifying every invariant.
- Model state with the type system: use enums + exhaustive `match` over boolean flags; make illegal states unrepresentable.
- Async: pick the runtime already in use (`tokio` / `async-std`); don't block the executor with sync I/O. Don't hold a non-`Send` guard across an `.await`.
- Public items get `///` doc comments; keep modules cohesive and re-export a clean crate API from `lib.rs`.

### Style
- `rustfmt` is non-negotiable — match it exactly.
- Clippy is part of the definition of done: the build must be clean under `cargo clippy -- -D warnings`.
- Tests live in `#[cfg(test)] mod tests` (unit) and `tests/` (integration). Use `assert_eq!` / `assert!` from std.

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
- New dependencies or `Cargo.toml` / `Cargo.lock` changes
- Editing the edition, `rust-toolchain`, or feature flags
- Any `unsafe` block
- Public crate API (signatures, trait bounds, re-exports) changes
- Database schema / migration changes
- Auth / permission logic
- `build.rs`, CI, or deployment config changes

---

## Verification (Mandatory Order)
1. `cargo fmt --check`
2. `cargo clippy --all-targets -- -D warnings`
3. `cargo check --all-targets`
4. `cargo test`
5. `cargo build --release` (catches release-only issues)
6. Smoke test: run the binary / hit the endpoint, verify real behavior
7. Optional before merge: `/review-pipeline` for multi-lens audit over the PR diff

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
