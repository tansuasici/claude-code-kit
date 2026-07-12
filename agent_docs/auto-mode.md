# Auto Mode (Safe Autonomy)

Claude Code's **auto mode** is a permission middle-ground: instead of prompting on every action (default) or skipping all checks (`--dangerously-skip-permissions`), a classifier auto-approves safe actions and stops only on the risky, irreversible, or out-of-scope ones. It's the right setting for running with fewer interruptions — *if* you have a hard floor under it.

The kit is that floor. This guide explains why the kit's existing hooks and permission lists make auto mode safe to turn on, and the posture to run it in.

> **The kit does not — and cannot — enable auto mode for you.** `permissions.defaultMode: "auto"` is ignored in a project's `.claude/settings.json` / `.claude/settings.local.json` (Claude Code v2.1.142+), so a checked-in repo cannot grant itself elevated autonomy. Auto mode is something *you* opt into in your **user** settings; the kit's job is to make that opt-in safe.

---

## Enable it (user-level)

```bash
# Per session:
claude --permission-mode auto

# Or cycle to it mid-session with Shift+Tab (first time shows an opt-in prompt).
```

Persistent default — **only** honored in `~/.claude/settings.json` (user) or managed settings, never a project file:

```json
{
  "permissions": { "defaultMode": "auto" }
}
```

On Bedrock / Vertex / Foundry, auto mode is gated behind an env var (`CLAUDE_CODE_ENABLE_AUTO_MODE=1`); on the Anthropic API it's available by default. Requires Claude Code v2.1.83+.

---

## Why the kit makes auto mode safe

Auto mode runs the full permission pipeline and then adds a classifier *after* it. That ordering is what the kit exploits — its guardrails sit **before** the classifier and can't be talked out of by it:

| Layer (in precedence order) | Provided by | Holds under auto mode? |
|---|---|---|
| `PreToolUse` deny hook (`exit 2` / `permissionDecision: deny`) | kit hooks: `protect-files`, `protect-changes`, `branch-protect`, `block-dangerous-commands` | **Yes — hard block.** PreToolUse fires before the permission system *and* the classifier; the classifier can only further restrict, never un-block. |
| `permissions.deny` | kit `settings.json` deny list (`curl`, `wget`, `npm publish`, `cat .env*`, …) | **Yes — unoverridable floor.** Resolves before the classifier; intent and `autoMode` config cannot override it. |
| `autoMode.hard_deny` → `soft_deny` → classifier defaults | Claude Code classifier (server-side) | Yes — but `soft_deny` is clearable by explicit, specific user intent. |
| `permissions.allow` / working-dir auto-approve | kit allow list (`npm test`, `git status`, …) | Pre-approves narrow commands. **Broad** allow rules (`Bash(*)`, wildcard interpreters) are auto-dropped on entering auto mode — the kit's allow list is already narrow, so it survives intact. |

In short: the two things the kit ships — a curated `deny` list and a set of `PreToolUse` blocking hooks — are exactly the two layers that sit *above* the auto-mode classifier and cannot be overridden. That's the safety net.

---

## Recommended strict posture

1. **Keep the `deny` floor.** The kit's `permissions.deny` list blocks before the classifier and can't be overridden. Treat it as the non-negotiable boundary; extend it for project-specific "never" commands.
2. **Lean on the `PreToolUse` hooks.** `protect-files`, `protect-changes`, `branch-protect`, and `block-dangerous-commands` `exit 2` to hard-block — they fire ahead of the classifier under auto mode. This is the programmable half of the net (all four ship in the **standard** profile; only `minimal` omits `protect-changes`).
3. **Close the bypass gap.** The docs do *not* guarantee hooks run under `bypassPermissions` (which skips the permission layer entirely). If you administer the machine, disable it in **managed** settings so the gap can't be reached:
   ```json
   { "permissions": { "disableBypassPermissionsMode": "disable" } }
   ```
4. **Don't rely on conversational boundaries.** Saying "don't push" is re-read from the transcript each check and is **lost on compaction**. Encode hard guarantees as `permissions.deny` or `autoMode.hard_deny`, not as a chat instruction.
5. **Tune the classifier in user/managed settings, not the repo.** The `autoMode` block (`environment` / `allow` / `soft_deny` / `hard_deny` — prose arrays, with `"$defaults"` splicing in the built-ins) is read only from user / local / managed settings. Keep `"$defaults"` in every array (omitting it *replaces* the built-in safety list). Inspect with `claude auto-mode config` and `claude auto-mode critique`.

---

## When to stop and ask (escalation points)

Auto mode and `/loop` remove the *prompts*, not your *judgment*. The deterministic hooks already stop the **mechanical** cases: `protect-changes` gates dependency / auth / migration edits, `block-dangerous-commands` blocks destructive shells, `branch-protect` blocks pushes to `main`, `loop-detect` halts thrash on one file, and `stop-gate` blocks completion on a red gate. What no hook can catch is a **judgment** call. At these points, **escalate to the human — don't stall, and don't silently guess:**

- **Irreversible or destructive actions outside the guardrails.** The hooks cover the common cases; a genuinely destructive action they *don't* — dropping a bucket, force-deleting a remote resource, a one-way data migration, rewriting published history — is a stop-and-ask, because there's no undo if the guess is wrong.
- **Ambiguous requirements.** Two defensible readings with materially different outcomes → ask which one. A wrong interpretation is more expensive to unwind than the interruption is to make.
- **Scope expansion.** The task grew past what was asked — a refactor the fix "needs", a second subsystem, a dependency bump → surface it and get a yes before spending the budget (CLAUDE.md → Scope Discipline: log it under `## Not Now`, don't fold it in silently).
- **Repeated failed attempts.** N honest tries with no real progress, or you're circling → halt and surface the blocker rather than thrash or force an exit. For the loop-specific form of this — a red gate the loop is tempted to *game* into passing — see **Don't let the loop game the gate** below; this bullet is the general case.

Escalation is not failure. A stalled loop that asks one sharp question beats a green-looking result built on a silent wrong guess — the kit's worst outcome (CLAUDE.md → Verification step 5). When you escalate, don't just stop: state the decision, the options, and your recommendation in one message so the human can unblock you in a single reply.

---

## Scheduled autonomy: `/loop` and `loop.md`

Auto mode removes the per-action prompts; `/loop` removes the per-iteration *you*. It's the bundled skill that re-runs a prompt on a schedule **inside the open session** — `/loop 15m <prompt>` for a fixed interval, `/loop <prompt>` to let Claude pace itself, or a bare `/loop` for the built-in maintenance prompt (continue unfinished work, tend the current PR, run cleanup). Requires Claude Code **v2.1.72+**; not available on Bedrock / Vertex / Foundry.

The same floor that makes auto mode safe is what makes an unattended `/loop` safe — and the fit is tighter than it looks:

- **`session-start` re-fires every iteration.** Each loop turn is a fresh check, so the hook re-injects Tier-1 pointers, top rules, the active task, and branch + dirty-tree status — the loop can't drift away from the plan across hours of iterations.
- **The `PreToolUse` deny hooks and the `deny` floor still hold** on every action the loop takes (see the precedence table above). An autonomous loop is exactly when you want `protect-changes`, `branch-protect`, and `block-dangerous-commands` standing guard.
- **`stop-gate` still gates completion** each iteration — a loop turn that left the quality gate red can't quietly call itself done.

### The kit deliberately ships no `loop.md`

A `loop.md` file (`.claude/loop.md`, falling back to `~/.claude/loop.md`; first found wins, 25 KB cap) **replaces the built-in maintenance prompt for a bare `/loop`** — and only that. It is plain Markdown written as if you were typing the `/loop` prompt directly, it defines **one** default prompt (not a task list), and it is **ignored the moment you pass a prompt** on the command line.

That makes it inherently **project-specific**, so the kit does not ship one:

- The built-in maintenance prompt already covers the generic case (finish work, tend the PR, clean up). A generic kit `loop.md` would just duplicate it — and duplicate it *worse*, since it can't know your repo.
- `loop.md` earns its place only when a project has a **specific recurring watch** — "keep `release/next` green", "babysit the nightly", "drain the migration backlog". That's yours to write, not the kit's to guess.

If you do write one, keep it goal-checked: state the done-condition in one line ("if everything is green and quiet, say so and stop") so the loop converges instead of churning, and lean on the Verification gate rather than re-describing it.

### Don't let the loop game the gate

An unattended loop runs under standing pressure to reach its exit condition, and the failure mode isn't laziness — it's a model that "succeeds" by lowering the bar. The gates are deterministic, but what you *tell* the loop to do around them isn't, so make the boundary explicit in the prompt (or `loop.md`):

- **The `SKIP_QUALITY_GATE` escape hatch is for broken infra, not a red gate you caused.** `stop-gate` clears on `SKIP_QUALITY_GATE=1`; that bypass exists for failures *unrelated* to the change — a flaky harness, a pre-existing break. Using it to walk past a failure your own edit introduced defeats the gate. If you set it, record why in `tasks/decisions.md`; an unexplained bypass reads as gaming.
- **Never edit the thing you're graded on to make it pass.** Don't weaken, skip, `xfail`, or delete the failing test; don't relax the check declared in `.claude/commands.json`; don't narrow the lint config to silence the error. Fix the code, or stop. `loop-detect` blocks the 6th repeat-edit of one file, but it can't catch a check quietly rewritten to be trivial — that guardrail has to be in the prompt.
- **A red gate after N honest tries is a stop, not a shortcut.** If the done-condition isn't genuinely met after a few real attempts — or you're circling — halt and surface the blocker. Forcing an exit (declaring done, committing over the failure) is worse than an unfinished loop: it hides the failure behind a green-looking result, the kit's worst outcome (CLAUDE.md → Verification step 5).

When you write a `loop.md` done-condition, phrase it so it can only be satisfied honestly — "if the suite is green **and** the feature actually runs, say so and stop," not "stop when the errors go away," which a deleted test also satisfies.

---

## Gotchas

- **Auto mode is a research preview.** Per the docs it "reduces prompts but does not guarantee safety." The kit raises the floor; it doesn't make autonomy risk-free. Review diffs.
- **`CLAUDE_CODE_AUTO_COMPACT_WINDOW` is unrelated.** Despite the name, it governs the context **auto-compaction** token window, not the permission auto mode. Don't conflate them in config.
- **The classifier costs tokens.** It's a separate server-side model call per non-trivial action.
- **Subagents are checked too** — at spawn, per-action, and on return; a subagent's `permissionMode` frontmatter is ignored under auto mode.

---

## See also

- `agent_docs/hooks.md` — the `PreToolUse` blocking hooks that form the programmable safety net, and the hook profiles.
- `.claude/settings.json` — the `permissions.deny` floor and the narrow `allow` list.
- README → **Auto Mode** — the short version of this recipe.
- Claude Code docs → **Scheduled tasks** — the full `/loop` and `loop.md` reference.
