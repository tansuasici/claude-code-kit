# Task Board

Track current and upcoming tasks here. The agent updates this file as work progresses.

The task under **In Progress** carries an `h3` heading — `session-start.sh` reads
the first one and injects it as the session's active task.

---

## In Progress

### Verification-core batch — verification results and upgrades you can trust

One PR per item, each tracked in Linear. PR 0 jumps the queue: until `--upgrade`
updates changed files, none of the other fixes reach existing installs.

- [x] PR 0 — `--upgrade` updates kit-managed files against a per-file baseline (TAN-6269, ADR-017) — #205
- [x] PR 1a — worktree-aware roots and gate state, process-group timeout, multi-step bench scenarios (TAN-6270, ADR-018) — #208
- [ ] PR 1b — per-file scoped gate results + passed / failed / timeout / error / skipped statuses (TAN-6272, ADR-019)
- [ ] PR 2 — C#/.NET checks (`.cs`, `.csproj`, `.sln`) and a dotnet template
- [ ] PR 3 — `commands.json` schema validation; fast per-edit checks vs full test/build
- [ ] PR 4 — doctor behavioral self-test (broken code blocks, fix unblocks, compaction keeps state)
- [ ] PR 5 — upgrade diff report: leftover files, missing/dangling hook registrations

---

## Up Next

- Nothing queued. Parked scope lives under **Not Now**.

---

## Done

Shipped releases are recorded in `CHANGELOG.md` — release-please generates it
from Conventional Commits, so this section only carries work that has landed on
`main` since the last cut.

### Since v1.21.1

- [x] PR #203 — the README's collapsed "Manual install" recipe still copied
  `CODEBASE_MAP.md` and `tasks/` from the repo root, handing out the state that
  PRs 198 and 199 stopped `install.sh` from shipping — on GitHub, on the site's
  Introduction page, and in the LLM docs dump. Now copies from `scaffold/`.

---

## Not Now

Parked scope — deferred work, revisit when prioritized. (CLAUDE.md → Scope Discipline routes out-of-scope items here.)

- **Multi-language test-runner detection** beyond Python/Node/Go/Rust (Ruby, Java, etc.) — the quality gate detects a fixed runner set today. _(deferred from #33 hook-shift)_
- **HTTP/MCP-style hook handlers** — advanced handler types beyond the file-command hook model; flagged as out of scope. _(deferred from #33)_
- **Cross-tool hook adapter** — port the deterministic hook layer to Cursor/Codex/Devin formats. Tracked separately because hooks don't port cleanly (see the `convert.sh codex` note: discipline survives as AGENTS.md rules, enforcement stays Claude-Code-only). _(deferred from #33)_
- **Retro-clean existing installs** that already carry the foreign `tasks/` content from before #198. Deliberately not done: that content is user data now, and an upgrade that deleted files under `tasks/` would be the more dangerous behavior.
