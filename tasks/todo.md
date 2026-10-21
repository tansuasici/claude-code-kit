# Task Board

Track current and upcoming tasks here. The agent updates this file as work progresses.

The task under **In Progress** carries an `h3` heading — `session-start.sh` reads
the first one and injects it as the session's active task.

---

## In Progress

### Per-edit test runs: the related test, and proof it went red

**Goal**: the gate stops asking only "does it compile" and asks "does its test
pass" — for the one test that covers the edited file, inside a per-edit budget.
And a test that was green the first time it ever ran is reported as such: it
never went red, so it is not yet evidence of anything.

**Context**: #219 (TAN-7038) made the Test List checkable by _path_ — a source
file with no test behind it is nudged, and blocked under strict. It never runs
anything. The gate meanwhile runs typecheck or lint per edit and declares
`test` as "FULL, never per edit", so the loop Beck's gears describe — write the
test, watch it fail, make it pass — has no machine-checkable step in the kit.
Running the whole suite per edit is the thing the gate deliberately refuses;
running the _one related test_ is affordable and is what makes green mean
something.

### Tests

Named before the code (`bench/scenarios/`, `./scripts/run-bench.sh --filter test-run`):

- `s109-commands-json-test-file-key-accepted` — `test-file` with a `{file}`
  placeholder in `commands.json` is valid config, not an unknown-key error.
  Proven red on the pre-change tree: today the key is a config error and the
  gate records `error`.
- `s110-commands-json-test-file-needs-placeholder` — `test-file` without
  `{file}` is a config error: without the placeholder the command would run the
  whole suite on every edit, the cost this package exists to avoid.
- `s111-test-run-runs-related-test` — edit `src/calc.ts` with `calc.test.ts`
  beside it → the declared command runs with `{file}` substituted, logged
  `passed` against the _test_ file's path.
- `s112-test-run-records-failure` — the related test exits non-zero → logged
  `failed`, and the edit-time message names the test and the command.
- `s113-test-run-no-related-test-logs-nothing` — no test on disk → no line at
  all: there is nothing to run, and `test-first.sh` already owns that case.
- `s114-test-run-absent-key-is-off` — no `test-file` in `commands.json` → the
  hook does nothing. The feature is opt-in.
- `s115-test-run-key-off-logs-nothing` — `test-file` set to `""` → off, no line.
- `s116-test-run-on-test-file-edit` — edit `calc.test.ts` while `calc.ts` can't
  satisfy it → logged `failed`. This is the red half of the loop: a test's first
  run belongs to the edit that wrote the test, not to the edit that fixes it.
- `s117-test-run-does-not-touch-quality-gate-state` — edit `calc.test.ts`, then
  `calc.ts`: the quality gate's own record for `calc.test.ts` still stands in
  `quality-gate-state.json` _and_ the test run has its own line. Two states, no
  clobber.
- `s118-test-run-path-with-spaces` — a test path containing a space and a single
  quote is substituted into the command safely.
- `s119-test-run-timeout-logged-as-timeout` — a test command that outruns the
  budget is logged `timeout`, never `failed`.
- `s120-red-evidence-first-run-green-warns` — a test file whose first run this
  session is green → `additionalContext` says it never went red. Exit 0.
- `s121-red-evidence-red-then-green-is-quiet` — the same test logged `failed`
  first and `passed` after → silent. That is the loop working.
- `s122-test-first-gate-failed-test-blocks-in-strict` — strict profile, a latest
  line of `failed` → Stop blocks, naming the test.
- `s123-test-first-gate-failed-test-quiet-by-default` — the same log without
  `CCK_TEST_FIRST=strict` → exit 0, nothing on stdout. The edit-time message was
  the signal.
- `s124-test-first-gate-unreadable-run-log-blocks` — strict, the log exists but
  can't be read → block, the same fail-closed rule s107 pins for the pending list.
- `s125-test-first-gate-latest-run-wins` — strict, a test logged `failed` then
  `passed` → exit 0. The latest line is the verdict; the earlier ones are history.
- `s126-test-first-gate-other-session-red-run` — strict, the red line belongs to
  another session in the same checkout → exit 0. Added after the mutation pass:
  dropping the session filter on the run log broke nothing.
- `s127-test-run-placeholder-less-key-is-off` — `test-file` with no `{file}` →
  nothing runs, nothing logged. Also from the mutation pass: the hook's own
  placeholder guard was asserted nowhere (s110 covers the config error only).

**Status** — implemented and green: `127/127` bench, `doctor.sh` 80 passed,
counts and generated artifacts in sync, every new scenario mutation-checked.
ADR-025 records the own-log decision. The PR waits on
[#219](https://github.com/tansuasici/claude-code-kit/pull/219) so the two
packages land in order.

### Approach

1. `lib/project-commands.sh` — `test-file` joins the `ALLOWED` tuple. The value
   must carry a `{file}` placeholder; absent → off, `""` → off.
2. `lib/test-paths.sh` — `test_path_for <source>` prints the related test path.
   The existence check `test_exists_for` becomes a thin wrapper over it, so
   there stays one matching rule.
3. New `.claude/hooks/test-run.sh` (PostToolUse) — resolves the related test,
   substitutes it into the declared command, runs it under the gate's timeout
   helper, and appends the result to its **own** log,
   `.hook-state/test-run-log.tsv` (`session`, `test`, `source`, `status`,
   `epoch`, `detail`). Not the quality gate's state: `files[<path>]` there holds
   one scope per path, and `quality-gate.sh` gates test files too (`calc.test.ts`
   is a `.ts` file), so a tsc record for the test file would _replace_ a red test
   record and the stop would read clean. `stop-gate.sh` also re-verifies a stale
   record by re-running `quality-gate.sh`, never this hook. Neither file is
   touched.
4. Red evidence falls out of the same log. It is append-only and never deduped,
   so the first status logged for a test this session answers "did it ever go
   red". A first run that is green gets one advisory `additionalContext` line.
   The hook fires on an edit to the _test_ file as well — that is where the red
   normally happens, and a hook that only watched source edits would see every
   test green on its first run.
5. The verdict at Stop joins `test-first-gate.sh`: advisory by default (the
   edit-time message is the whole signal), blocking only under
   `CCK_TEST_FIRST=strict`, with the same `SKIP_TEST_FIRST` escape. One Stop
   hook for the test-first family, asking one question: is the loop closed.
6. One ADR, and a release-note callout: `test-file` is a new `commands.json`
   key, so a project that adopts it and then downgrades the kit sees an
   unknown-key config error on every edit.

### Files to Touch

- `.claude/hooks/lib/project-commands.sh`, `.claude/hooks/lib/test-paths.sh`
- `.claude/hooks/test-run.sh` — new; `.claude/hooks/test-first-gate.sh` — the Stop verdict
- `.claude/hooks/session-start.sh` — prune the new log with the others
- `.claude/settings.json` + regenerated `settings.strict.json`, `.kit-manifest`,
  `scripts/doctor.sh` wiring checks
- `bench/scenarios/` s109–s127, `scripts/check-counts.sh`, README + bench README counts
- `agent_docs/testing.md`, `agent_docs/hooks.md`, `tasks/decisions.md`

### Risks

- **A per-edit test run costs time.** It gets its own timeout
  (`CCK_TEST_RUN_TIMEOUT`, then the declared `timeout`) rather than sharing the
  quality gate's, and whether the two overlap is Claude Code's scheduling, not
  something the kit controls. A slow `test-file` command logs `timeout` instead
  of `passed` — recorded, never guessed.
- **`test-file` is a new `commands.json` key** and an unknown key is a config
  error that blocks. Adopt-then-downgrade breaks every edit. Release notes.
- **A path substituted into a shell command.** `{file}` is single-quote-escaped;
  s118 is the proof.

### Not Now

- Running more than one related test (a source file covered by several test
  files). The first match runs; the rest are the full suite's job.
- Coverage as evidence. A test that imports a file and asserts nothing passes
  this check — path convention and exit codes are what the kit can check
  deterministically.
- **Re-verifying a stale run at Stop.** The latest line is the verdict, so a fix
  made through Bash — no `Edit`, no hook — leaves a `failed` line standing. The
  escape is to edit the file again or set `SKIP_TEST_FIRST=1`; re-running the
  command from the Stop hook, the way `stop-gate.sh` re-verifies, is a later
  package.

### Test-first discipline: the Test List and the missing-test nudge

**In review** — [#219](https://github.com/tansuasici/claude-code-kit/pull/219),
TAN-7038, ADR-024. Two hooks (`test-first.sh` records and nudges,
`test-first-gate.sh` blocks only under `CCK_TEST_FIRST=strict`), `lib/test-paths.sh`,
the Test-First section in `agent_docs/testing.md`, the plan template's `### Tests`
block, and twelve scenarios s97–s108. Package C+D above builds on it.

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
