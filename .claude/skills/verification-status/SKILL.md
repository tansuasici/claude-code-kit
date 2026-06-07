---
name: verification-status
description: Render the per-task verification ledger (.hook-state/verification-ledger.json) — which gates ran and their outcomes — and record the manual checks CLAUDE.md mandates but a hook can't capture: the smoke-test result and silent-failure counts. Use before /ship or marking a task done, or when asked "did verification pass / what was verified". Do NOT use to run the gates (quality-gate.sh does that) or for install health (scripts/doctor.sh).
user-invocable: true
---

# Verification Status

## Core Rule

A task isn't verified until the *evidence* is complete. The automatic gates (typecheck / lint) are logged by `quality-gate.sh`; the **smoke test** and **silent-failure count** are manual judgments a hook can't make. This skill shows the auto-gate evidence and records the manual half, so "would a staff engineer approve this?" is answerable from the ledger — not vibes.

## When to Use

- Before `/ship` or marking a task complete — assemble and show the verification evidence.
- When the user asks "did verification pass / what was verified / show verification status".
- Right after you run a manual smoke test — to record the result.

Do NOT use for:

- Running the gates — `quality-gate.sh` does that automatically on every edit.
- Installation health / orphan hooks — that's `scripts/doctor.sh`.

## Process

1. **Read the ledger** `.hook-state/verification-ledger.json`. If it's absent, no qualifying edits ran this session — say so (nothing to verify yet).

   ```bash
   python3 - "${CLAUDE_PROJECT_DIR:-$PWD}/.hook-state/verification-ledger.json" <<'PY'
   import json, sys
   try:
       d = json.load(open(sys.argv[1]))
   except FileNotFoundError:
       print("No verification ledger — no qualifying edits this session."); raise SystemExit
   for e in d.get("entries", []):
       print(f"  {e['status']:7} {e['tool']:24} {e.get('file','')}  ({e.get('duration_s',0)}s)")
   print("  smoke_test:", d.get("smoke_test"))
   print("  silent_failures:", d.get("silent_failures"))
   print("  coverage:", d.get("coverage"))
   PY
   ```

2. **Run the mandatory order** if any step is missing (CLAUDE.md → Verification): typecheck → lint → tests → smoke test. The first three are auto-gated; you must run tests + the smoke test (open the page / call the endpoint / run the CLI).
3. **Record the manual checks** once you've done them — write into the ledger (atomic). Set the smoke result, the silent-failure tally `(processed/failed/skipped)`, and optional coverage:

   ```bash
   python3 - "${CLAUDE_PROJECT_DIR:-$PWD}/.hook-state/verification-ledger.json" \
     "passed — opened /users, search returns results" \
     "120/0/0" "" <<'PY'
   import json, os, sys
   f, smoke, silent, coverage = sys.argv[1:]
   try:
       d = json.load(open(f))
   except FileNotFoundError:
       d = {"schema_version": 1, "entries": [], "smoke_test": None,
            "silent_failures": None, "coverage": None}
   if smoke:    d["smoke_test"] = smoke
   if silent:   d["silent_failures"] = silent      # processed/failed/skipped
   if coverage: d["coverage"] = coverage
   tmp = f + ".tmp"
   json.dump(d, open(tmp, "w"), indent=2); os.replace(tmp, f)
   print("recorded")
   PY
   ```

4. **Verdict**: state whether every mandated step is present and green. If a subset of items was silently skipped (`failed`/`skipped` > 0), surface it — never report "complete" over a silent drop.

## Output Format

A short verification report:

- **Auto-gates** — table of `status · tool · file · duration` from the ledger.
- **Manual checks** — smoke-test result; silent-failure tally `(processed/failed/skipped)`; coverage (if recorded).
- **Verdict** — one line: mandatory order complete & green? "Would a staff engineer approve this?"

## Notes

- `quality-gate.sh` writes the auto-gate entries; this skill reads them and records the manual half. The ledger is per-session (reset at session start) — it is evidence for the *current* task.
- `stop-gate.sh` emits a non-blocking reminder if auto-gates passed but no smoke result is recorded.
- `/ship` cites this ledger as the verification evidence in its PR writeup.
