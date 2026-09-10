# Task Board

Track current and upcoming tasks here. The agent updates this file as work progresses.

The task under **In Progress** carries an `h3` heading — `session-start.sh` reads
the first one and injects it as the session's active task.

---

## In Progress

_Nothing in progress._

---

## Up Next

- Nothing queued. Parked scope lives under **Not Now**.

---

## Done

Shipped releases are recorded in `CHANGELOG.md` — release-please generates it
from Conventional Commits, so this section only carries work that has landed on
`main` since the last cut.

### Since v1.21.0

- [x] **TAN-5273** / PR #196 — a quiet grep fed by a pipe lost its match under
  `pipefail`, so `doctor.sh` invented orphan-hook warnings (4 of 100 runs) and
  the `rm -rf` / secret-scan / unicode-scan guards could silently fail open.
  All 46 call sites replaced with herestrings or bash substring tests; a
  **Pipefail Grep Guard** CI job keeps the pattern out. Lesson:
  `tasks/lessons/2026-09-11-pipefail-quiet-grep.md` (`top_rule`).
- [x] PR #195 — `test-install.sh` now asserts the strict profile wires
  `notify-waiting.sh`; without it a `gen-strict-settings.sh` regression that
  dropped the Notification hook would have passed CI silently.
- [x] **TAN-6213** / PR #198 — a fresh install copied this repo's own `tasks/`
  into the user's project: its live board, 15 ADRs, 4 real lessons and an
  internal spike spec. `scaffold/tasks/` is now the single distribution source.
  Separately, `package.json`'s `files` array supersedes `.npmignore`, so
  `.claude/settings.local.json` shipped in the published 1.21.0 tarball; `files`
  now names `.claude/` subpaths explicitly and the dead `.npmignore` is gone.
  Guarded by `scripts/check-scaffold.sh` + a **Scaffold Check** CI job.
- [x] **TAN-6217** / PR #201 — `validate.sh` and `doctor.sh` warned on clean
  trees: a bare `...` read as an unfilled placeholder (fired on 3 of the 6
  example maps the kit ships), `WIKI.md`/`ARTIFACTS.md` existing read as
  "module installed" (3 warnings every run here), and `notify-waiting.sh`
  reported as an orphan from a stale `OPT_IN_HOOKS` list — now derived from
  `settings.strict.json`. Also cleared the last 4 skill-validator warnings.
  doctor is 0 warnings on this repo and on a fresh install.
- [x] **TAN-6215** / PR #199 — every project outside the six auto-detected stacks
  (and every empty directory) received this repo's own filled-in
  `CODEBASE_MAP.md`, the first file Session Boot tells the agent to read.
  `scaffold/CODEBASE_MAP.md` is now the generic fallback.

---

## Not Now

Parked scope — deferred work, revisit when prioritized. (CLAUDE.md → Scope Discipline routes out-of-scope items here.)

- **Multi-language test-runner detection** beyond Python/Node/Go/Rust (Ruby, Java, etc.) — the quality gate detects a fixed runner set today. _(deferred from #33 hook-shift)_
- **HTTP/MCP-style hook handlers** — advanced handler types beyond the file-command hook model; flagged as out of scope. _(deferred from #33)_
- **Cross-tool hook adapter** — port the deterministic hook layer to Cursor/Codex/Devin formats. Tracked separately because hooks don't port cleanly (see the `convert.sh codex` note: discipline survives as AGENTS.md rules, enforcement stays Claude-Code-only). _(deferred from #33)_
- **Retro-clean existing installs** that already carry the foreign `tasks/` content from before #198. Deliberately not done: that content is user data now, and an upgrade that deleted files under `tasks/` would be the more dangerous behavior.
