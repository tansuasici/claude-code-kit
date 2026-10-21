# Task Board

Track current and upcoming tasks here. The agent updates this file as work progresses.

The task under **In Progress** carries an `h3` heading — `session-start.sh` reads
the first one and injects it as the session's active task.

---

## In Progress

### Ship the test-first batch: the public docs, then one release

**Goal**: the three test-first PRs become something a reader finds without
reading the repo — the README's story reads as one pass rather than three
appended ones, the site has a test-first page — and then a single version cut
carries all of them.

**Context**: #219 made the Test List checkable by path, #221 ran the related test
per edit and kept its red/green history, #222 gated the commit and named the red
bar in the handoff. Each PR updated the in-repo docs it touched and each
deliberately skipped its own release, so the batch cuts once. What none of them
touched is the public surface: the site's pages (private web repo) and the
GitHub-facing material a visitor reads before installing.

### Tasks

- [ ] #222 merged.
- [ ] GitHub-facing docs re-read end to end — the hook table, the profile matrix
  and the `commands.json` section each grew a row per PR; they have to read as
  one feature, not three appended passes.
- [ ] `claudecodekit.tansuasici.com` — a test-first page: the Test List, the
  per-edit test run, clean check-in, the red-bar handoff, and the one switch
  (`CCK_TEST_FIRST=strict`) that turns all three gates into blocks. Build locally,
  no deploy without an explicit go-ahead.
- [ ] One release for the whole batch: the version cut here, then `npm publish`
  by hand with a fresh OTP (the CI publish leg always fails 2FA).

## Up Next

- Nothing queued. Parked scope lives under **Not Now**.

---

## Done

Shipped releases are recorded in `CHANGELOG.md` — release-please generates it
from Conventional Commits, so this section only carries work that has landed on
`main` since the last cut.

### Since v1.21.1

- [x] Pre-release fix round for the verification-core batch. Three adversarial
  reviews of the merged batch found bugs the batch had introduced — a `--diff`
  that destroyed user files and a stop gate that could be walked past — and they
  were fixed before 1.22.0 was cut. Only fail-open and data-loss problems the
  unreleased batch introduced counted as blockers; everything else went to
  **Not Now**.
  - #207 — installs ship only the 10 user-facing scripts, and `sync-manifest.sh`
    exits 2 instead of reporting success without its library (TAN-6271).
  - #215 — doctor fails when the gates aren't wired in `settings.json`; the .NET
    advice no longer points `typecheck` at a single project; s58 and s61 assert
    what they claim; `check-counts.sh` guards the README's scenario numbers (TAN-6280).
  - #216 — the quality gate fails closed: results are scoped by session, an
    unwritable `.hook-state` blocks, a per-file log replaces the last-run summary
    when python3 is unusable, worktrees the session edited are checked, and the
    check's process group is killed only on timeout (TAN-6278, ADR-022).
    Sixteen new scenarios, s81–s96.
  - #217 — `--diff` never writes outside its scratch copy (it followed symlinks
    into shared directories), and an upgrade never replaces a file the kit didn't
    install without naming the backup (TAN-6279, ADR-023).
- [x] Verification-core batch: verification results and upgrades you can trust.
  One PR per item, each tracked in Linear.
  - PR 0: `--upgrade` updates kit-managed files against a per-file baseline (TAN-6269, ADR-017), #205.
  - PR 1a: worktree-aware roots and gate state, a process-group timeout, and multi-step bench scenarios (TAN-6270, ADR-018), #208.
  - PR 1b: per-file scoped gate results with passed / failed / timeout / error / skipped statuses (TAN-6272, ADR-019), #209.
  - PR 2: C#/.NET checks for `.cs`, `.csproj` and `.sln`, plus a dotnet template (TAN-6273), #210.
  - PR 3: `commands.json` schema validation, where an absent key auto-detects and `""` turns a check off; fast per-edit checks are separate from full checks (TAN-6274, ADR-020), #211.
  - PR 4: a doctor behavioral self-test. A broken edit blocks, compaction keeps the verdict, a fix unblocks, and worktrees stay isolated (TAN-6275), #212.
  - PR 5: `--diff` runs the real upgrade on a scratch copy, so the preview matches what `--upgrade` does. It also flags stale kit files and hook registrations that are missing or point at no script (TAN-6277, ADR-021), #213.
- [x] PR #203 — the README's collapsed "Manual install" recipe still copied
  `CODEBASE_MAP.md` and `tasks/` from the repo root, handing out the state that
  PRs 198 and 199 stopped `install.sh` from shipping — on GitHub, on the site's
  Introduction page, and in the LLM docs dump. Now copies from `scaffold/`.
- [x] The Test List, checkable by path. `test-first.sh` records a source file
  edited with no test behind it and says so once per file; `test-first-gate.sh`
  blocks the stop, but only under `CCK_TEST_FIRST=strict`; `lib/test-paths.sh`
  holds the convention, and the plan template grew a `### Tests` block. Twelve
  scenarios s97–s108 (TAN-7038, ADR-024), #219.
- [x] Per-edit test runs, with the red bar as evidence. `test-run.sh` runs the one
  test covering the edited file through `commands.json → test-file` — a `{file}`
  placeholder is mandatory, because a guessed command is either the whole suite or
  the wrong test — and appends to `.hook-state/test-run-log.tsv`, which is
  append-only: the latest line for a test is its verdict, the earlier ones are the
  proof it ever went red. Its own log and not the gate's state, which keys one
  check scope per path and would have let a passing test erase a failing
  typecheck. Nineteen scenarios s109–s127 (TAN-7039, ADR-025), #221.
- [x] Clean check-in, and a red bar to come back to. `commit-gate.sh` meets a
  `git commit` with the verdict the gates already reached — a failed check from
  `quality-gate-state.json`, a red test from `test-run-log.tsv` — so a commit is
  no longer the one door out of the loop that nothing checks. It reads and never
  re-verifies: a stale record is named and never blocks, because a commit door
  that re-runs typechecks is a commit door people route around, and Stop owns
  that budget. `next-red-test.sh` is the mirror — a session that ends on red
  writes that test and its re-run command into the handoff, so the next session
  starts at the red bar instead of re-deriving where this one stopped. Warn by
  default, block under `CCK_TEST_FIRST=strict`, same two bypasses. Sixteen
  scenarios s128–s143 (TAN-7040, ADR-026), #222.

---

## Not Now

Parked scope — deferred work, revisit when prioritized. (CLAUDE.md → Scope Discipline routes out-of-scope items here.)

- **Multi-language test-runner detection** beyond Python/Node/Go/Rust (Ruby, Java, etc.) — the quality gate detects a fixed runner set today. _(deferred from #33 hook-shift)_
- **HTTP/MCP-style hook handlers** — advanced handler types beyond the file-command hook model; flagged as out of scope. _(deferred from #33)_
- **Cross-tool hook adapter** — port the deterministic hook layer to Cursor/Codex/Devin formats. Tracked separately because hooks don't port cleanly (see the `convert.sh codex` note: discipline survives as AGENTS.md rules, enforcement stays Claude-Code-only). _(deferred from #33)_
- **Retro-clean existing installs** that already carry the foreign `tasks/` content from before #198. Deliberately not done: that content is user data now, and an upgrade that deleted files under `tasks/` would be the more dangerous behavior.

Deferred by the pre-1.22.0 stopping rule: only fail-open or data-loss problems the
unreleased batch introduced blocked the release. Each of these either behaves the
same way in the released 1.21.x or is a known limit of the new design.

- **The GNU `timeout` fallback doesn't end a signalled check** — used on Linux when python3 isn't usable. The hook still returns on time, because check output goes to a file rather than a pipe. _(hooks review)_
- **`test-first-pending.tsv` is rewritten without a lock** — `drop_satisfied` in
  `test-first.sh` writes a temp file and `mv`s it over the list, so two concurrent
  PostToolUse hooks can lose a line. The cost is a missed nudge or a stale line
  the Stop gate re-checks against the disk anyway, never a wrong verdict. _(test-first review)_
- **`quality-gate-history.json` and `verification-ledger.json` are written without a lock** — concurrent runs can lose a ledger entry. The gate's own state is locked, so stop decisions are unaffected. _(hooks review)_
- **The out-of-project unrecorded marker under `$TMPDIR` is append-only** — filtered when read, cleaned only by the OS. _(hooks review)_
- **With neither `cksum` nor `date -r`, a fallback stamp stays stale and blocks** — fail-closed by design; `SKIP_QUALITY_GATE=1` is the escape. _(hooks review)_
- **Hook runs with no `session_id`** (doctor, manual invocations) **see every record** — fail-closed by design. _(hooks review)_
- **A real `--upgrade` writes through a dangling symlink** at a kit path, which can create a file outside the project (BSD `cp`). The same in 1.21.x; `--diff` warns about it. _(install review)_
- **Baseline entries are never pruned**, so a user's own file at a retired kit path can appear under "the kit no longer ships these". _(install review)_
- **A re-run without `--upgrade` overwrites an edited `.example` file with no backup** — the same in 1.21.x. _(install review)_
- **No `--template generic`**, so an unidentifiable `CLAUDE.md` can't be forced onto the generic template; the message says to merge by hand. _(install fix)_
- **An explicit `--template` after an "unidentified" upgrade** offers `.kit-new` instead of replacing, because the file has no baseline entry. Safe, but it differs from the pre-baseline path. _(install fix)_
- **The hedged "may be your own" list appears only in `--diff`**, because the first upgrade rewrites `.kit-manifest` before printing its summary. _(install review)_
- **One line of the symlink report** claims `--upgrade` writes through a `.kit-new` symlink; `write_kit_new` skips those. _(install review)_
