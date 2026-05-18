# .claude/extensions/

Drop community-contributed skills here. Anything under this directory is **Layer 2** in the kit's [four-layer skill resolution order](../../agent_docs/skills.md#extending-the-kit-resolution-order):

```text
Priority  Layer                              Location                                Owner
⬆ 1       Project-local overrides            .claude/skills/<name>/SKILL.md          Project
2         Community extensions               .claude/extensions/<name>/SKILL.md      Third-party  ← this dir
3         Project-overlay slot               .claude/skills/<name>/project/          Project
⬇ 4       Kit core                           .claude/skills/<name>/SKILL.md          Kit
```

## How to add an extension

```bash
# From a git repo:
cp -r path/to/extension-repo/.claude/skills/my-extension .claude/extensions/

# From a Claude Code plugin (after installing):
# the plugin's skills will appear here automatically if it ships extensions
```

Each extension follows the same shape as a kit skill:

```text
.claude/extensions/<name>/
  SKILL.md           # frontmatter + sections (Core Rule, When to Use, Process, ...)
  templates/         # optional, skill-specific assets
  references/        # optional, on-demand reading material
```

The validator (`scripts/validate-skills.sh`) checks extensions against the same conventions as core skills (Core Rule, Output Format, frontmatter, etc.) and emits a warning if an extension name collides with a kit-core skill.

## What the kit will and won't do

| Action | Behaviour |
|---|---|
| Add the directory + this README on first install | Kit creates them |
| Refresh this README on upgrade | Kit overwrites README only — never your extensions |
| Touch `.claude/extensions/<name>/*` on upgrade | Kit **never** modifies extension content |
| Track extensions in `.kit-manifest` | Kit tracks only this README; extension contents are yours |

If you need to delete an extension, `rm -rf .claude/extensions/<name>/`. The kit's `uninstall.sh` leaves this directory alone.

## Naming collisions with kit-core skills

If an extension uses the same `<name>` as a kit-shipped skill, Claude Code will pick whichever it discovers first — behaviour is filesystem-dependent and not what you want. The validator warns about this so you can rename the extension or open a PR to upstream it (which removes the collision by moving it to Layer 4).

See [`agent_docs/skills.md → Extending the Kit (Resolution Order)`](../../agent_docs/skills.md#extending-the-kit-resolution-order) for the full precedence model and [ADR-015](../../tasks/decisions.md) for the decision history.
