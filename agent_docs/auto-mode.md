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
