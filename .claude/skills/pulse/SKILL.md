---
name: pulse
description: Time-windowed pulse report on what shipped, broke, was learned, and is open. Saves to tasks/pulses/ as a timeline. Distinct from /retro (process) and /project-health-report (whole-project).
user-invocable: true
---

# Pulse

## Kit Context

Before starting this skill, ensure you have completed session boot:
1. Read `CODEBASE_MAP.md` for project understanding
2. Read `CLAUDE.project.md` if it exists for project-specific rules
3. Read `tasks/lessons/_index.md` for accumulated corrections (Top Rules + index)

If any of these haven't been read in this session, read them now before proceeding.

## When to Use

Invoke with `/pulse` when:

- End of a week/sprint and you want a one-page outcome view
- Preparing a stakeholder update (Slack, email, demo prep)
- Reviewing the project after a period away
- Setting up a scheduled outcome timeline (`/loop weekly /pulse mode:headless`)

Not for:

- Reflective retrospective on *how* the work went — use `/retro`
- Whole-project health scoring — use `/project-health-report`
- Pre-merge multi-audit review — use `/review-pipeline`

## Scope Rules

- Operates over a time window (default: last 7 days)
- Read-only: produces a report and saves it to `tasks/pulses/`
- Pulls signals only from artifacts already in the repo (git history, `tasks/`, CHANGELOG, deps lockfile) — no external services required
- Never modifies code or existing lessons/decisions

## Process

### Phase 1: Resolve Window

Determine the time range:

1. **If `window:Nd` or `window:Nw` in arguments** — use it (e.g., `window:7d`, `window:30d`, `window:2w`)
2. **Else if `since:YYYY-MM-DD` in arguments** — from that date to today
3. **Else** — default to the last 7 days, ending today

The output filename mirrors the window:

| Window | Filename |
|---|---|
| 1–3 days | `tasks/pulses/YYYY-MM-DD.md` (daily) |
| 4–14 days | `tasks/pulses/YYYY-Www.md` (weekly, ISO week) |
| 15–60 days | `tasks/pulses/YYYY-MM.md` (monthly) |
| >60 days | `tasks/pulses/YYYY-MM-DD_to_YYYY-MM-DD.md` (custom range) |

If the target file exists, append `-2`, `-3` etc. — never overwrite.

### Phase 2: Gather Outcome Signals

Pull each signal silently — do not narrate progress to the user.

**Shipped (from git history on the default branch)**

- `git log --since=<window-start> --first-parent --format='%h %s' [main|master]`
- Filter to user-facing commit types: `feat:`, `fix:`, `perf:`, `revert:`, breaking changes (`!:` or `BREAKING CHANGE`)
- For each, extract the subject — drop scope prefixes if they're internal-only

**Broke and recovered (signals of incidents in the window)**

- `revert:` commits → something was rolled back
- `fix:` commits referencing the same area within 7 days of a `feat:` in that area → fast-follow fix (likely user-impacting)
- Commits matching `hotfix|incident|outage|p0|p1` (case-insensitive)
- New lessons in `tasks/lessons/` created within the window — these are correction signals

**Learned**

- New lesson files in window, grouped by `problem_type` and `tags`
- New ADRs in `tasks/decisions.md` within window
- Lessons promoted to Top Rules within window (check `top_rule: true` lessons whose `updated` is in window)

**Carry-over (still open)**

- Items in `tasks/todo.md > ## Not Now` (any age — these are deferred items)
- Items in `tasks/todo.md` not marked done at the time of the pulse
- Open `tasks/handoff-*.md` files (interrupted work)

**Dep / surface changes (user-relevant)**

- `git diff --name-only <window-start>..HEAD package.json pyproject.toml Cargo.toml go.mod 2>/dev/null` — any non-empty result means dependency changes
- `git diff --name-only <window-start>..HEAD '**/migrations/**' '**/schema*' 2>/dev/null` — schema changes

Skip signals that return nothing. Don't fabricate.

### Phase 3: Compose

Compose the report from the gathered signals. The report is **outcome-oriented**, not process-oriented:

- *Retro* asks "how did the work go?"; pulse asks "what did users get?"
- Every shipped item is phrased from the user's perspective when possible
- If a signal section is empty, omit it (do not write "Nothing to report" — silence is the signal)
- Carry-over is the only "process leak" allowed, because it's actionable for next window

Keep the report under one page when rendered. If the window produced too much for one page, summarize and link out (e.g., "12 shipped items — see commits abc1234..def5678").

### Phase 4: Save and Link

1. Create `tasks/pulses/` if missing
2. Write the report to the resolved filename
3. Update or create `tasks/pulses/_index.md` — an append-only chronological list of pulses for quick scanning
4. Print the path and a one-line summary to the user (and optionally the report itself, if interactive)

## Run Mode

This skill supports interactive (default) and headless modes — see the canonical contract in `.claude/skills/_shared/blocks/mode-detection.md`.

Headless detection: presence of `mode:headless` in arguments. Other tokens after the flag set the window (e.g., `mode:headless window:30d`).

| Decision point | Interactive default | Headless default |
|---|---|---|
| **Window** | Ask if ambiguous | Default to 7 days; honor explicit `window:` / `since:` args |
| **Empty window** (no signals at all) | Tell the user and ask whether to save a placeholder | Save a minimal "no signal" report so the timeline stays gap-free |
| **Overwrite collision** | Ask before overwriting | Append `-2`, `-3` — never overwrite |
| **Print report inline** | Print full report after saving | Print only path + one-line summary |

## Output Format

```markdown
# Pulse — <Window label, e.g., Week of 2026-05-05>

**Range:** YYYY-MM-DD → YYYY-MM-DD (N days)
**Commits on main:** N · **Shipped:** N · **Learned:** N · **Open:** N

---

## Shipped

- **<short user-facing description>** — `<commit hash>` (`<type>`)
- ...

## Broke and Recovered

- **<incident or fast-follow>** — context (`<commit hashes>`)
- ...

## Learned

- **<lesson title>** — tags: `[...]` (`tasks/lessons/<file>`)
- **ADR:** <decision title> (`tasks/decisions.md#<anchor>`)
- ...

## Surface Changes

- **Dependencies:** N added, M updated, K removed (see `package.json` diff)
- **Schema:** migrations <list>

## Carry-Over

- [ ] **<deferred item>** — from `tasks/todo.md > Not Now`
- [ ] Interrupted work in `tasks/handoff-<date>.md`

---

## Cross-Pulse Trends (optional, only if ≥3 prior pulses exist)

- Recurrent themes (top tags across recent lessons)
- Ship rate trend (commits/week over last N pulses)
- Carry-over creep (items that have been deferred ≥2 windows)
```

## Notes

- **Pulse vs retro**: pulse describes *outcomes*; retro describes *process*. Run both during a sprint review — they answer different questions.
- **Pulse vs project-health-report**: pulse is **windowed and time-stamped** (compounds into a timeline); health-report is **a snapshot** (replaces the previous one).
- **The timeline is the artifact.** A single pulse is useful; the trend across pulses is more useful. Resist deleting old pulses for tidiness — that erases the signal.
- **Signals only.** Pulse never speculates ("this might have caused churn"). If you don't have evidence, omit the claim.
- **One page** is the discipline. If you cannot fit a week into a page, the underlying work is probably too scattered — that itself is a signal worth surfacing.
