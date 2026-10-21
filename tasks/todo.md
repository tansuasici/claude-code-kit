# Task Board

Track current and upcoming tasks here. The agent updates this file as work progresses.

The task under **In Progress** carries an `h3` heading — `session-start.sh` reads
the first one and injects it as the session's active task.

---

## In Progress

### Test-first discipline: a Test List that the gates can check

**Goal**: "Done" stops being "the agent stopped typing" and becomes "every test
on the list is green" — the list written before the code.

**Context**: Three sources say the same thing from different directions. Uncle
Bob's three laws of TDD (no production code before a failing test; a failing
test defines what to build next). Kent Beck's _Test List_ pattern — enumerate
the tests before the session starts, and the session is over when the list is
empty. Boris Cherny's "the most important tip is verification", now shipped in
Claude Code as `/goal` ("work until the tests in test/auth pass") and
"acceptance criteria in the first turn".

The kit today verifies only _after_ the fact: `quality-gate.sh` runs
typecheck/lint per edit, `test` is declared as "FULL, never per edit", and
test-first appears only as advice for bug fixes (`agent_docs/testing.md`,
`glob-guidance.sh`). Nothing enumerates the tests up front, nothing notices a
source file edited with no test behind it, and nothing stops a commit while the
gate is red.

### Tests

Named before the code, each one proven red on the pre-change tree
(`bench/scenarios/`, `./scripts/run-bench.sh --filter test-first`):

- `s97-test-first-nudges-source-without-test` — source written, no test anywhere
  → recorded in `.hook-state/test-first-pending.tsv` and nudged once.
- `s98-test-first-nudges-once-per-file` — the same file edited again → silent.
- `s99-test-first-clears-when-test-written` — the test file is written → the
  pending line goes.
- `s100-test-first-quiet-when-test-exists` — a sibling test already on disk →
  nothing recorded, nothing said.
- `s101-test-first-gate-quiet-by-default` — pending, no `CCK_TEST_FIRST` → Stop
  exits 0 and says nothing.
- `s102-test-first-gate-blocks-in-strict` — `CCK_TEST_FIRST=strict` → Stop exits 2
  naming the file and the escape.
- `s103-test-first-gate-skip-env` — strict + `SKIP_TEST_FIRST=1` → exit 0.
- `s104-test-first-gate-other-session-pending` — strict, a pending line from
  another session → exit 0.
- `s105-test-first-ignores-non-source` — a `.md` and a `.sh` edit → nothing recorded.
- `s106-test-first-gate-clears-when-test-appears` — strict, the test file appears
  without an Edit (Bash, codegen) → exit 0.
- `s107-test-first-gate-unreadable-state-blocks` — strict, the pending list exists
  but can't be read → exit 2 (an unreadable list is not an empty one).
- `s108-test-first-gate-unreadable-state-quiet-by-default` — the same broken state
  with no `CCK_TEST_FIRST` → exit 0, silent.

### Approach

**Package A+B — the Test List and the missing-test nudge** (one PR, implemented — PR open, TAN-7038)
1. `agent_docs/testing.md` gains a Test-First section: the three laws paraphrased,
   Beck's gears (Fake It → Triangulate → Obvious Implementation), and the
   agent-specific trap — a constant returned with no red test on screen is not
   Fake It, it is a stub shipped as done.
2. The plan template in `agent_docs/workflow.md` gains a **Tests** block: the
   named tests to write, before the Approach steps. `contracts.md` points its
   "Tests (must ALL pass)" section at that list instead of free text.
3. New `.claude/hooks/lib/test-paths.sh` — is this a test file, and does a test
   exist for this source file (per-language patterns).
4. New `.claude/hooks/test-first.sh` (PostToolUse Edit|Write|NotebookEdit) —
   a source file edited with no test touched this session and no test file on
   disk is recorded in `.hook-state/test-first-pending.tsv` and nudged once via
   `additionalContext`. Cleared when a matching test file is written.
5. New `.claude/hooks/test-first-gate.sh` (Stop) — blocks only under
   `CCK_TEST_FIRST=strict`, which the strict profile sets. `SKIP_TEST_FIRST=1`
   is the escape, matching `SKIP_QUALITY_GATE=1`.

**Package C+D — the red/green loop per edit** (second PR, own ADR)
6. New `commands.json` key `test-file` with a `{file}` placeholder, so the gate
   can run the _related_ test inside the 30s budget instead of the whole suite.
   Absent → off. No related test found → `skipped` with a reason, never `passed`.
7. Red evidence: a test file whose first run is already green is reported as
   "never went red".

**Package E — Clean Check-in and Broken Test** (third PR)
8. A commit gate: `git commit` refused while the gate state holds a failed or
   stale file. Beck's Clean Check-in.
9. `tasks/handoff.md` gains a "next failing test" line — Beck's Broken Test, the
   deliberate red bar left as a bookmark for the next session.

### Files to Touch
- `agent_docs/testing.md`, `agent_docs/workflow.md`, `agent_docs/contracts.md`,
  `agent_docs/hooks.md`, `CLAUDE.md` — the prompt side
- `.claude/hooks/lib/test-paths.sh`, `.claude/hooks/test-first.sh`,
  `.claude/hooks/test-first-gate.sh` — new
- `.claude/settings.json` + regenerated `settings.strict.json`, `install.sh`
  manifest, `scripts/doctor.sh` wiring checks
- `bench/scenarios/` — new scenarios per hook behaviour, each proven red on the
  pre-change tree; `scripts/check-counts.sh` + README counts follow
- `tasks/decisions.md` — one ADR per package

### Risks
- **False positives.** Refactors, config edits and exploratory work legitimately
  touch source with no new test. Mitigation: nudge by default, block only under
  strict, and keep the escape documented next to `SKIP_QUALITY_GATE`.
- **`test-file` is a new `commands.json` key**, and an unknown key is a config
  error that blocks. A project that adopts the key then downgrades the kit will
  see every edit blocked. Must be called out in the release notes.
- **Per-edit test runs cost time.** The 30s budget is shared with typecheck/lint;
  a project whose `test-file` command is slow records timeouts instead of passes.

### Not Now
- A `professionalism.md` for Clean Coder's "saying no" material — two or three
  lines inside `auto-mode.md` escalation instead.
- Anything for the tweet's "microservices philosophy"; the kit's answer is
  already worktree and subagent isolation.

---

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
