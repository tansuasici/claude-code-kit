# Task Board

Track current and upcoming tasks here. The agent updates this file as work progresses.

The task under **In Progress** carries an `h3` heading — `session-start.sh` reads
the first one and injects it as the session's active task.

---

## In Progress

### Clean check-in: a commit the gate agrees with, and a red bar to come back to

**Goal**: `git commit` stops being the one door out of the loop that nothing
checks. A commit made while this session's last check is red is named as such —
and refused under the strict profile. And a session that ends on a red test
leaves that test's name in its handoff, so the next one resumes at the red bar
instead of re-deriving where it was.

**Context**: #219 made the Test List checkable by path, #221 runs the one related
test per edit and keeps its red/green history. Both answer at **Stop** — the
moment the model declares itself done. `git commit` is the other way out, and it
reaches none of them: `conventional-commit.sh` checks the shape of the message
and nothing else, so a commit can carry a file whose typecheck failed two edits
ago or a test that is still red. Clean check-in is the rule that a check-in never
breaks the build; ending the day on a deliberate failing test is its mirror — the
fastest way back into the loop tomorrow is a test that is already red.

### Tests

Named before the code (`bench/scenarios/`, `./scripts/run-bench.sh --filter commit-gate`):

- `s128-commit-gate-passes-other-bash` — `git status`, `git log --oneline`: not a
  commit, no output, exit 0.
- `s129-commit-gate-silent-when-clean` — every record `passed`, no red test: exit 0
  and nothing on stdout. A gate that talks on a clean commit is a gate people turn off.
- `s130-commit-gate-warns-on-failed-check` — default profile, a `failed` record for
  a file this session edited: exit 0, `additionalContext` names the file and the
  check, the commit still runs.
- `s131-commit-gate-blocks-failed-check-strict` — the same state under
  `CCK_TEST_FIRST=strict`: exit 2, stderr names the file.
- `s132-commit-gate-warns-on-red-test` — the latest `test-run-log.tsv` line for a
  test is `failed`: default profile names it through `additionalContext`.
- `s133-commit-gate-blocks-red-test-strict` — the same, strict: exit 2.
- `s134-commit-gate-green-after-red-passes` — red then green for the same test:
  exit 0. A session that went red and came back is a finished loop, not a dirty commit.
- `s135-commit-gate-stale-record-never-blocks` — a file changed since its check,
  strict: exit 0, the file named as stale. Re-verification costs seconds and
  belongs to Stop, which has a budget for it.
- `s136-commit-gate-skip-env-bypasses` — `SKIP_QUALITY_GATE=1` with a `failed`
  record, strict: exit 0, silent.
- `s137-commit-gate-other-session-record-passes` — another session's `failed`
  record: exit 0. Same `ours` rule as `stop-gate.sh` and `test-first-gate.sh`.
- `s138-commit-gate-unreadable-state-blocks-strict` — a state file that exists and
  can't be read: strict exit 2 (fail closed), default one line.
- `s139-commit-gate-amend-is-gated` — `git commit --amend --no-edit` on red: strict
  exit 2. An amend is a check-in.
- `s140-next-red-test-writes-handoff` — SessionEnd with a red latest line: the
  session handoff names the test, its status and the command that re-runs it.
- `s141-next-red-test-silent-when-green` — all green: no section, and no handoff
  file created. A handoff that exists means an interrupted session (CLAUDE.md step 3).
- `s142-next-red-test-redacts-detail` — a secret in the log's detail field is
  masked in the handoff (the TAN-4733 rule `journal-fold.sh` already follows).

### Approach

1. **`lib/test-run-log.sh`** — the "latest line per test wins" reader, lifted out
   of `test-first-gate.sh`: `test_run_red <runlog> <root> <session>` prints
   `test<TAB>status<TAB>source<TAB>detail`, newest first, for tests that are red
   and still on disk. Three callers would otherwise carry the same reversed-read
   loop three times. `test-first-gate.sh` switches to it with no behaviour change —
   s109–s127 are the net.
2. **`.claude/hooks/commit-gate.sh`** — PreToolUse on `Bash`, registered after
   `conventional-commit.sh`, whose matcher it copies (`grep -qE 'git\s+commit'`).
   Read-only, two sources, one question — _is this check-in clean?_
   - the quality gate's own state through `gate_state_lines` (`lib/gate-state.sh`):
     `block`, `orphan`, `unrecorded` and `error` are red; `stale` is named but never
     blocks; `unverified` (nothing checks the file) is ignored, exactly as
     `stop-gate.sh` ignores it.
   - `test-run-log.tsv` through the new library.
   Default profile: exit 0 with `hookSpecificOutput.additionalContext` (confirmed
   supported for PreToolUse — it lands next to the tool result, which is the warn
   profile's ceiling). Strict (`CCK_TEST_FIRST=strict`): exit 2, the reason on
   stderr, with the same fail-closed `on_exit` trap `test-first-gate.sh` arms only
   in strict. Escapes: `SKIP_QUALITY_GATE=1` and `SKIP_TEST_FIRST=1` (and their
   `CLAUDE_` forms). It never re-runs a check and never writes state.
3. **`.claude/hooks/next-red-test.sh`** — SessionEnd, after `journal-fold.sh`.
   When a test's latest verdict this session is red, appends a `## Next: the red
   bar` section to `tasks/handoff-<session-id>.md`: the test, its status, the
   source file behind it, and the `test-file` command with `{file}` substituted.
   Detail goes through `redact_secrets`. Green or nothing logged → it writes
   nothing and creates no file. Its own hook rather than a branch inside
   `journal-fold.sh`, which exits early when there is nothing to fold and whose
   s18/s19/s44 contract stays untouched.
4. **Docs**: `agent_docs/hooks.md` (two rows, and the strict-delta note that
   `CCK_TEST_FIRST=strict` now also hardens the commit door), the Verification
   blockquote in `CLAUDE.md`, the hook count in `README.md` and `CODEBASE_MAP.md`,
   `bench/README.md` rows, and **ADR-026** in `tasks/decisions.md`: the commit gate
   reads and never re-verifies, stale never blocks a commit, the handoff is written
   only on red.
5. **Generated outputs**: `scripts/gen-strict-settings.sh` (regenerate
   `settings.strict.json`), `scripts/sync-manifest.sh` (`.kit-manifest`), and a
   doctor probe per new hook beside `tr=`.

### Files to Touch

- `.claude/hooks/commit-gate.sh` (new), `.claude/hooks/next-red-test.sh` (new)
- `.claude/hooks/lib/test-run-log.sh` (new), `.claude/hooks/test-first-gate.sh` (switch to it)
- `.claude/settings.json` + `.claude/settings.strict.json` (generated), `.kit-manifest` (generated)
- `scripts/doctor.sh`, `bench/scenarios/s128…s142`, `bench/README.md`
- `agent_docs/hooks.md`, `CLAUDE.md`, `README.md`, `CODEBASE_MAP.md`, `tasks/decisions.md`

### Risks

- **The matcher's blind spots are inherited on purpose.** `git\s+commit` also
  matches the string inside `echo "git commit"` and misses `git -C dir commit`.
  Diverging from `conventional-commit.sh` here would mean two different answers to
  "is this a commit" in the same hook array; consistency is worth more than the
  edge.
- **A warning arrives next to the tool result**, so in the default profile the
  model reads it after the commit landed. That is what "warn, don't block" means;
  the strict profile is where the door closes.
- **One env var, two doors.** `CCK_TEST_FIRST=strict` now hardens the commit gate
  as well as Stop. Documented in the strict delta rather than given a second knob
  nobody would set separately.
- **A commit from a script run through Bash is gated too** (a release script, a
  `git commit` inside a loop). `SKIP_QUALITY_GATE=1` for that session is the escape.

### Not Now

- **Files that owe a test** (`test-first-pending.tsv`) at commit time. Clean
  check-in is about code that fails or is unverified, not code whose test has not
  been written yet — Stop already asks that question, twice.
- **Re-verifying a stale record at commit time.** Stop owns the budget
  (`CCK_STOP_REVERIFY_BUDGET`); a PreToolUse hook that re-runs a typecheck makes
  every commit cost seconds.
- **A real `.git/hooks/pre-commit`**, which would also catch commits made outside
  Claude Code. The kit does not write into `.git/`, and that is a deliberate line.
- **Gating `git push`.** The check-in is the unit the rule is about; a push of
  already-checked commits adds nothing to check.

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
