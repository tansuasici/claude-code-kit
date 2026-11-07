---
name: review-pipeline
description: Run multiple audits in parallel over a PR-scope diff, dedupe across auditors, and produce a confidence-gated report. Use to review a change or PR before merge. Distinct from /project-health-report (whole-project, breadth-first).
user-invocable: true
---

# Review Pipeline

## Core Rule

Parallelize independent auditors over a PR-scope diff. Dedupe across reports. Never widen scope beyond the diff.

## Kit Context

Before starting this skill, ensure you have completed session boot:
1. Read `CODEBASE_MAP.md` for project understanding
2. Read `CLAUDE.project.md` if it exists for project-specific rules
3. Read `tasks/lessons/_index.md` for accumulated corrections (Top Rules + index)

If any of these haven't been read in this session, read them now before proceeding.

## When to Use

Invoke with `/review-pipeline` when:

- A PR is ready and you want a multi-lens check before requesting human review
- A multi-session feature has landed on a branch and you want to catch regressions
- You're investigating a flaky area and want several auditors to weigh in
- You suspect issues but don't know which audit applies — let the pipeline pick

Not for:

- Trivial single-file edits — invoke the relevant audit directly
- Project-wide periodic health checks — use `/project-health-report` instead
- Full architectural assessments — use `/architecture-review` or `/deepening-review`

## Scope Rules

- Read-only — produces a report, never modifies code
- Operates within the detected scope (recent changes by default)
- Logs unrelated issues found during analysis under `tasks/todo.md > ## Not Now`
- Does not duplicate findings already in CLAUDE.md or `tasks/lessons/`

## Process

### Phase 1: Resolve Scope

Pick the smallest scope that captures the change:

1. **If the user passed paths or globs** — use those literally
2. **Else if the working tree has uncommitted changes** — use `git diff --name-only HEAD`
3. **Else if on a feature branch** — use `git diff --name-only $(git merge-base HEAD origin/main)...HEAD` (fall back to `main` if `origin/main` is absent)
4. **Else** — ask the user which path or commit range to review; do not silently default to the whole repo

Filter the file list:

- Drop generated paths (`node_modules/`, `dist/`, `build/`, `.next/`, `__pycache__/`, `vendor/`)
- Drop lockfiles unless `dependency-audit` is selected
- If the resulting list is empty, stop and report "no in-scope changes detected"

Save the resolved scope as a bulleted list — every parallel auditor gets the same list.

### Phase 2: Select Audits

Always select these core audits:

- `code-quality-audit` — smells, error handling, maintainability
- `testing-audit` — coverage gaps, test quality

Conditionally add based on file patterns in the resolved scope:

| Pattern in scope | Add audit |
|---|---|
| `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.html` | `accessibility-audit` |
| Service / handler / query / loop heavy code (≥1 file) | `performance-audit` |
| `package.json`, `pyproject.toml`, `requirements*.txt`, `Cargo.toml`, `go.mod` | `dependency-audit` |
| Module-level or full-folder change (≥5 files in one dir) | `dead-code-audit` |
| `README*`, `docs/`, public API surface changes | `documentation-audit` |
| Auth, session, token, crypto, request validation paths | `security-reviewer` (agent, not skill) |
| Multi-module structural change | `architecture-review` |

Cap at **5 parallel audits by default** to keep token spend bounded. If more are eligible, pick the 5 with the strongest fit to the scope and list the skipped ones in the report's "Skipped audits" section with a one-line rationale.

If the user passed an explicit list (e.g., `/review-pipeline testing,security`), honor it literally and skip selection logic.

### Phase 3: Run Audits in Parallel

For each selected audit, dispatch one Task in a **single message containing all tool calls** so they run concurrently. Pattern per Task:

```text
Task(
  description: "<audit-name> on <short scope label>",
  subagent_type: "general-purpose",
  prompt: """
    You are running the <audit-name> audit on a scoped set of files.

    Step 1 — Read the skill file at `.claude/skills/<audit-name>/SKILL.md` and follow
    its Process section. Do not invoke other audits; do not analyze files outside
    the scope below.

    Step 1b — Comparative pass: sample how the codebase already handles this concern
    (neighbouring files, shared helpers, established conventions). Flag *deviations*
    from the existing pattern — not the mere absence of a pattern you would prefer.
    A change that matches the surrounding code is not a finding.

    Step 2 — Scope (files to analyze):
    <one bulleted file path per line>

    Step 3 — Return findings as a JSON array with this exact shape, nothing else:
    [
      {
        "file": "src/x.ts",
        "line": 42,
        "category": "smell|error-handling|test-gap|...",
        "severity": "critical|major|minor",
        "confidence": "high|medium|low",
        "message": "one-line summary",
        "suggested_fix": "one-line fix or null"
      },
      ...
    ]

    Do not include prose around the JSON. If you find nothing, return [].
  """
)
```

**Security auditor exception.** `security-reviewer` is an agent, not a skill — there is no `.claude/skills/security-reviewer/SKILL.md`. Dispatch it like the others, but in Step 1 point it at `.claude/agents/security-reviewer.md`, and have it additionally apply the false-positive filter in `.claude/skills/_shared/blocks/security-fp-precedents.md` before emitting findings. It still returns the same JSON array (use `category` values like `injection`/`auth`/`exposure`/`config`); the agent's own markdown output format does not apply inside the pipeline. Where the agent would report **NEEDS VALIDATION** (the exploit turns on a fact outside the repo), it emits that entry with `"severity": null` plus `"status": "needs_validation"`, `"missing_fact"` and `"owner_check"` (one line each) instead of guessing a severity. `message` carries the exploit scenario assuming the missing fact goes the attacker's way; `confidence` (about the code path) and `suggested_fix` are still required.

**Optional adversarial lens.** Pass `adversarial` (or `adversarial:true`) in the arguments to add the `devils-advocate` agent (`.claude/agents/devils-advocate.md`) as an extra lens that tries to *falsify* the change rather than confirm it (unstated assumptions, breaking inputs, quiet reinterpretations). Off by default — every other lens checks for goodness; this one pushes back. It returns a ranked objection list; fold its `would-ship-broken`/`risky` items into the report as `correctness`/`major` findings. Distinct from `verify` (which knocks down *existing* findings); `adversarial` *generates* new ones.

Wait for all Tasks to complete before continuing. If any single Task errors out, record the failure under "Skipped audits" and continue with the rest — never abort the whole pipeline because one auditor failed.

### Phase 4: Dedupe + Confidence Gating

Merge findings using this algorithm:

1. **Parse each auditor's JSON** into a flat array, tagging each finding with `audit: <auditor-name>`.
   Accept only a bare JSON array (a single code fence around it, ```` ``` ```` or ```` ```json ````, is
   fine) whose every entry has all seven Step 3 keys. `suggested_fix` may be null; a security
   needs-validation entry has `severity: null` plus `status`, `missing_fact` and `owner_check`, and
   step 4 handles a null in those — don't reject the array for it. Anything else — prose around the array, a truncated array, findings
   described in prose, an entry missing a field — is discarded **without repair**: don't extract
   findings from the prose or fill in a field. Re-dispatch that auditor once in a fresh Task with the
   same prompt; if the retry is malformed too, list it under Skipped audits as `malformed output
   (retried once)`. Dispatch all retries in one parallel message. Repairing it would mean the
   orchestrator writing findings the auditor never made. The `adversarial` lens is exempt — its
   objection list is folded as described in Phase 3, not parsed here.

2. **Group findings** by the tuple `(normalized_file, line_bucket, category)` where:
   - `normalized_file` = repo-relative path with leading `./` stripped
   - `line_bucket` = `floor(line / 5) * 5` — collapses findings within 5 lines of each other
   - `category` = the auditor's category string, lowercased

3. **Within each group:**
   - Merge messages: keep the longest, most specific one as primary; append distinct shorter ones as bullets under "Also noted"
   - Compute `provenance` = sorted unique list of `audit` tags in the group
   - **Bump confidence:** if `|provenance| ≥ 2`, set group confidence to `high` regardless of individual confidences
   - **Max severity wins:** group severity = highest of (critical > major > minor), ignoring `null`; a group of only needs-validation entries has severity `null`

4. **Route needs-validation entries.** Drop any needs-validation entry with `confidence: low` or a null `missing_fact`/`owner_check` — it hasn't shown a real path or named what to check. A group whose remaining entries are all needs-validation goes to the report's Needs Validation section instead of through the gate below; it never gets a severity. A group that also holds a severity-bearing finding goes through the gate as an ordinary finding with the missing fact under "Also noted" — and if the gate drops it, its needs-validation entries still go to the Needs Validation section on their own.

5. **Confidence gate** (drop low-signal noise):
   - Keep group if `|provenance| ≥ 2` — multiple auditors agreed
   - Else keep group if `confidence = high` and `severity ∈ {critical, major}`
   - Else keep group if `confidence = high` and the message names a concrete file:line (not a category-only observation)
   - Else **drop** — single low/medium-confidence finding is noise

6. **Sort** by (severity desc, |provenance| desc, file asc). Sort the Needs Validation section by (|provenance| desc, file asc).

### Phase 4.5: Adversarial Verification (opt-in)

By default the pipeline trusts each auditor's self-reported confidence (Phase 4 gates structurally). Pass `verify` (or `verify:true`) in the arguments to add an independent second pass that tries to *knock down* each surviving finding before it reaches the report. This is the highest-precision mode and the most token-expensive — it spends one extra subagent per verified finding, so it is off by default.

When `verify` is set, after Phase 4:

1. **Select what to verify.** Take surviving findings of severity `critical` or `major` (skip `minor` — low stakes, not worth the spend), then the Needs Validation entries — a verifier can still find that the "missing" fact is in the repo after all (auth middleware the auditor didn't read). For those, `drop` means the repo shows the path isn't exploitable, `needs_validation` means the fact really is outside the repo, and `keep` means the repo settles it in the attacker's favour — the entry then stays in Needs Validation marked **repo confirms path — assign severity**, since the verifier doesn't rate severity. Cap at the **top 15** by severity, needs-validation entries last; if more survive, verify those 15 and carry the rest through with their Phase 4 status, marked `unverified` in the report.

2. **Verify each one independently.** Dispatch one Task per finding in a single message (parallel), capped at **8 concurrent** — drain and refill until done. Each verifier gets *only* the finding's `{file, line, category, severity, one-line claim}` (plus `missing_fact` for a needs-validation entry — the auditor's claim, not its reasoning) plus the code it reads itself — **never the other findings, and never the originating auditor's reasoning**. That isolation is the point: a verifier that can't see the auditor's argument (or its peers' verdicts) can't be talked into agreeing, so it has to reproduce the judgement from the code or drop it. (The auditors only ever emit a one-line `message`, so there is no chain-of-thought to leak — keep it that way; don't pass the auditor's working into the verifier prompt.)

   ```text
   Task(
     description: "verify <category> finding at <file>:<line>",
     subagent_type: "general-purpose",
     prompt: """
       Independently assess ONE candidate finding. Reproduce the judgement from the
       code itself — do not trust the claim.

       Finding: <file>:<line> · <category> · <severity>
       Claim: <message>
       <only for a needs-validation entry (severity null):>
       Claimed missing fact: <missing_fact>
       Look for it in the repo. keep = the repo shows it and the path is
       exploitable; drop = the repo shows it and the path is not;
       needs_validation = it really isn't in the repo.

       Standard to judge against:
       - For security categories (injection|auth|exposure|config), read and apply
         `.claude/skills/_shared/blocks/security-fp-precedents.md`.
       - Otherwise, read `.claude/skills/<originating-audit>/SKILL.md` and judge
         against its criteria.

       Read the cited file and enough surrounding code to trace the real path. Is
       this a concrete, exploitable/actionable issue — not theoretical, not a style
       preference, not excluded by the standard above?

       For security categories only: if the code shows a real path but the answer
       turns on a fact outside the repo (what sits in front of the route, a deployed
       config value, an upstream service's behaviour), return "needs_validation":
       name that fact and how the owner can observe it. Not having read far enough
       is not a missing fact. Other categories return only keep or drop.

       `confidence` is your confidence in the verdict you return (for
       needs_validation: that the code path is real).

       Return this JSON and nothing else:
       { "confidence": 1-10, "verdict": "keep" | "drop" | "needs_validation",
         "reason": "one line",
         "missing_fact": "one line, or null unless needs_validation",
         "owner_check": "one line, or null unless needs_validation" }
     """
   )
   ```

3. **Gate on the verifier.** Keep a finding only if the verdict is `keep` with confidence **≥8**. A `needs_validation` verdict with confidence ≥8 on a security category moves it to the Needs Validation section with the verifier's missing fact and owner check — it loses its severity but isn't dropped. Anything else is dropped (including a `needs_validation` verdict on a non-security category). A needs-validation entry stays in that section on `keep` ≥8 (marked **repo confirms path — assign severity**) or `needs_validation` ≥8, and is dropped otherwise. Attach the surviving verifier confidence + reason to each kept finding.

   **Critical findings get a 3-vote majority.** A single verifier is enough signal for `major` findings — bounded stakes, bounded spend — but a `critical` gates the merge, so verify each `critical` with **3 independent verifiers** (same isolated-context rules; dispatch the three in the same parallel batch) and keep it only if **≥2 of 3 return `keep` with confidence ≥8**. A 2-of-3 keeps it but records the split in the report. If it isn't kept but those keep votes plus `needs_validation` votes with confidence ≥8 reach 2, it moves to Needs Validation, listing every distinct missing fact the votes named; otherwise it's dropped. An errored vote counts for nothing: decide on the remaining votes only if they already reach 2 for an outcome; otherwise keep the critical `unverified`. This spends 3× on the handful of findings that most warrant it and stays single-pass everywhere else — the majority vote is what a lone verifier's own miscalls can't give you.

4. Verification is read-only and never modifies code. A verifier reply that isn't that JSON object (a single code fence around it is fine) — prose around it, a missing field, a verdict or confidence outside the allowed values — is discarded without repair and re-run once with a fresh verifier; a second malformed reply counts as an error. If a verification Task errors, keep the finding with its Phase 4 confidence and mark it `unverified` — never drop a finding because its verifier crashed.

### Phase 5: Assemble the Report

Produce one markdown report and offer to save it. Do not fix issues; only report.

Optional save target: `tasks/reviews/<YYYY-MM-DD>-<scope-slug>.md`. Ask the user before writing if any review file already exists for the same scope today; otherwise just create it and tell them the path.

## Output Format

```markdown
# Review Pipeline Report

**Scope:** <N files | git range | path glob>
**Audits run:** <comma-separated names> · <X> in parallel
**Audits skipped:** <comma-separated, or "none">
**Findings:** <C critical, M major, N minor> after dedupe (<R> raw) · <K> need validation
**Verification:** <V verified · D dropped by verifier · Kv moved to needs validation (from scored findings) · U unverified> — include only when `verify` ran

---

## Cross-Audit Findings (≥2 auditors agreed)

> Highest signal — these are flagged by multiple lenses, treat as high confidence.

| # | Severity | File:Line | Category | Auditors | Issue |
|---|----------|-----------|----------|----------|-------|
| 1 | critical | src/auth.ts:42 | error-handling | quality, testing | ... |

## Single-Audit Findings — Critical

| # | File:Line | Audit | Issue | Suggested Fix |
|---|-----------|-------|-------|---------------|

## Single-Audit Findings — Major

| # | File:Line | Audit | Issue | Suggested Fix |
|---|-----------|-------|-------|---------------|

## Single-Audit Findings — Minor

> Folded by default. Expand only if reviewing thoroughly.

<details>
<summary>N minor findings</summary>

| # | File:Line | Audit | Issue |
|---|-----------|-------|-------|

</details>

## Needs Validation

> Real paths whose exploitability turns on a fact outside the code. No severity until the owner check runs.

| # | File:Line | Audit | If exploitable | Missing fact | Owner check |
|---|-----------|-------|----------------|--------------|-------------|

## Dropped in Verification

> Every finding or Needs Validation entry the verifier pass dropped (not Phase 4 gate drops); D matches the header. Omit when D is 0. Kept so a later run or reviewer can see why a claim didn't survive.

<details>
<summary>D findings dropped</summary>

| # | File:Line | Audit | Claim | Verifier reason (for a critical: vote split + distinct drop reasons) |
|---|-----------|-------|-------|------------------------------------------------------------------|

</details>

## Skipped Audits

| Audit | Reason |
|-------|--------|
| dependency-audit | no dep file in scope |
| performance-audit | parallel cap reached; lower fit than selected 5 |

## Suggested Next Action

1. Address all Cross-Audit Findings first — they have the strongest signal
2. Triage Critical single-audit findings
3. Consider whether any Major findings warrant a follow-up task in `tasks/todo.md`
4. Run the owner checks under Needs Validation — a confirmed one becomes a finding at the severity its scenario earns
5. If the same claim keeps showing up under Dropped in Verification across saved reports, record it as a precedent — `tasks/lessons/` (project-owned, survives kit upgrades), or `security-fp-precedents.md` for security — so auditors stop raising it; other recurring patterns go to `tasks/lessons/` or a hook
```

## Report Guidelines

- File paths with line numbers (`file.ts:42`) for every finding — never bare filenames
- "Also noted" bullets under a primary finding when auditors phrased the same issue differently
- The Cross-Audit table is the **headline** — readers scan it first
- Skipped audits get one row each — never silently omit
- Minor findings collapsed into a `<details>` block to keep the report scannable
- Needs Validation rows carry no severity and don't count toward C/M/N — omit the section when it's empty. For a row the verifier moved there, the Audit column shows it (`security-reviewer → verifier`)
- When `verify` ran, append the verifier score to each verified finding (e.g., `✓ 9/10`) and list every finding it dropped under Dropped in Verification with the verifier's one-line reason — surfacing what was filtered is part of the signal, and the saved report is where that rejection evidence lives

## Run Mode

This skill supports interactive (default) and headless modes — see the canonical contract in `.claude/skills/_shared/blocks/mode-detection.md`.

Headless detection: presence of `mode:headless` in arguments. Other tokens after the flag are treated as explicit audit list (e.g., `mode:headless audits:testing,security`).

`verify` / `verify:true` is a reserved flag token (enables Phase 4.5) — not an audit name. Strip it before parsing the audit list, the same way `mode:` tokens are stripped.

| Decision point | Interactive default | Headless default |
|---|---|---|
| **Empty scope** (no changes detected and no path given) | Ask the user which path or range | **Fail** with "no in-scope changes detected; pass a path explicitly". Never silently scan the whole repo. |
| **Adversarial verification** (Phase 4.5) | Off unless `verify` passed | Off unless `verify` passed — honor it if present |
| **Scope >100 files** | Ask the user to narrow | Auto-narrow to the top-50 files by churn (`git log --name-only` count in the diff range). Note the truncation in the report. |
| **Audit selection** | Apply Phase 2 heuristics and inform user of selection | Apply the same heuristics; honor explicit `audits:<list>` arg if present |
| **Save report path collision** (a review for same scope/date already exists) | Ask before overwriting | Append `-2`, `-3`, etc. — never overwrite |
| **Needs Validation rows** | Listed in the report; they never block | Listed in the saved report, and a non-zero K is printed with the path; they never fail a gate |
| **Save vs print only** | Offer to save | Always save to `tasks/reviews/<YYYY-MM-DD>-<scope-slug>.md` and print the path |

Headless review-pipeline is suitable for: scheduled PR sweeps (`/loop /review-pipeline mode:headless`), CI-side pre-merge gates, and skill-to-skill orchestration where the parent skill chose the scope.

## Notes

- **This skill orchestrates; it does not analyze.** Quality of the report depends on the underlying audit skills.
- **Default cap is 5 parallel audits** to bound token spend. Override with explicit selection if you need more.
- **Confidence bump is asymmetric**: agreement promotes to `high`, but disagreement does not demote. Two auditors disagreeing on severity → take the higher severity.
- **The line bucket of 5** is a heuristic for "same issue, different line counted". If you need stricter matching (exact line), say so when invoking; if you need looser (same function), increase the bucket.
- **Don't run on the whole repo by default.** If scope resolution returns >100 files, ask the user to narrow.
- **Save the report only when useful.** Quick checks during development don't need a saved file — interactive feedback is the point.
- **Adversarial verification (`verify`) is opt-in and costs one extra subagent per verified finding.** It's bounded (critical/major only, top 15, 8 concurrent) but still the most expensive mode — reach for it on high-stakes diffs (auth, releases) or when someone disputes the findings, not on every run.
- **Comparative pass (Step 1b) is always on** and free — it sharpens every auditor by anchoring findings to deviations from the codebase's own patterns rather than abstract ideals.
- **The verifier's "not-a-bug" standard is codified, not improvised.** Each verifier judges against a fixed rubric — the originating audit's own `SKILL.md` criteria, and for security categories the `.claude/skills/_shared/blocks/security-fp-precedents.md` precedent list — so false-positive exclusion is uniform across runs instead of per-verifier taste. Extend those files, not the verifier prompt, when a class of false positive keeps surviving.
- **This is a reviewer → dedupe → verify chain, deliberately not a fix loop.** The pipeline chains lenses adversarially (auditors → provenance-gated merge → independent verifiers) but stays **report-only** — it never proposes or applies fixes, so nothing it emits can be a fix it also graded. Turning a finding into a change (and re-reviewing that change) is a separate step: hand the report to `/ship`'s verification gate or a `/deepening-review` fix pass, where the edit gets its own review rather than being adjudicated by the same run that proposed it.
