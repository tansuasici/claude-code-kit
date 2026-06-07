---
name: capabilities
description: Summarize what the kit makes available in this project — user-invocable skills, review agents, active hooks, and enabled modules — as a one-shot onboarding briefing read live from disk. Use when you start in a kit-enabled project or ask "what's available here / what can I do". Do NOT use for install health (that's scripts/doctor.sh) or terminal skill listing (npx @tansuasici/claude-code-kit skills).
user-invocable: true
---

# Capabilities

## Core Rule

When asked what the kit offers, enumerate the *actually installed* capabilities from the filesystem — never recite a memorized list, it drifts as the kit evolves. Read what is present under `.claude/` and the project root, group it, and present one scannable briefing.

## When to Use

When you (or the user) need a fast map of what this kit-enabled project can do:

- Starting a session in a project that has the kit installed — "what do I have here?"
- The user asks "what can this kit do / which skills / agents / hooks are available / what's enabled".
- Onboarding a teammate, or a fresh session, to the project's setup.

Do NOT use for:

- Installation health, orphan hooks, or unfilled placeholders → run `scripts/doctor.sh`.
- Listing skills from a terminal, outside a session → `npx @tansuasici/claude-code-kit skills`.
- A portable capability file for other agents/tools → `npx @tansuasici/claude-code-kit generate agents-md`.

## Process

Harvest live, then summarize. Don't dump full file bodies — names + one-liners only.

1. **Skills.** Enumerate `.claude/skills/*/SKILL.md` (skip `_`-prefixed infra dirs like `_shared`, `_templates`). For each, read `name`, the first sentence of `description`, and whether it is `user-invocable: true`. Include the wiki module (`wiki-module/.claude/skills/*`) when `WIKI.md` is present.

   ```bash
   for f in .claude/skills/*/SKILL.md; do
     name=$(awk '/^name:/{sub(/^name:[[:space:]]*/,""); print; exit}' "$f")
     desc=$(awk '/^description:/{sub(/^description:[[:space:]]*/,""); print; exit}' "$f" | sed 's/\. .*/./')
     inv=$(grep -q '^user-invocable:[[:space:]]*true' "$f" && echo "/" || echo "·")
     printf '%s %s — %s\n' "$inv" "$name" "$desc"
   done
   ```

2. **Agents.** List `.claude/agents/*.md`; read each `name` and its one-line role.
3. **Active hooks.** Read `.claude/settings.json` → `hooks`; report the wired events and the scripts under each (what runs automatically). Flag any hook file in `.claude/hooks/` that is present but *not* wired — those are opt-in (see `agent_docs/hooks.md` → Hook Profiles).
4. **Modules & overlay.** Detect by marker file and report active vs available:

   ```bash
   for m in "WIKI.md:Knowledge wiki" "ARTIFACTS.md:HTML artifacts" \
            "docs/ARCHITECTURE.md:Harness docs" "DESIGN.md:Design system" \
            "CLAUDE.project.md:Project overlay"; do
     f="${m%%:*}"; label="${m#*:}"
     [ -e "$f" ] && echo "✓ $label" || echo "· $label (not enabled)"
   done
   ```

5. **Version.** Read `VERSION` (or `.claude-plugin/plugin.json`) for the installed kit version.
6. Present the briefing (see Output Format).

## Output Format

A single scannable briefing:

- **Kit** — version + which optional modules are on.
- **Skills** — grouped by purpose (audit · review · workflow · docs · meta · wiki), each as `/name — one-liner`. Mark agent-facing (non-invocable) ones distinctly.
- **Agents** — `name — role`.
- **Hooks** — by event (what runs automatically), plus any opt-in hooks available but not wired.
- **Modules & overlay** — active vs available.
- **Next steps** — 1–2 concrete suggestions for this project (e.g. fill `CODEBASE_MAP.md`, then `/office-hours` to scope or `/feature-cycle` to build from a spec).

## Notes

- Read from disk every time → never stale; new skills/agents/hooks show up automatically.
- Hooks run deterministically in the background. This lists them for *awareness*; it does not enable/disable them — edit `.claude/settings.json` (see `agent_docs/hooks.md`).
- Complements, not replaces, the Claude Code `/` slash menu and `npx @tansuasici/claude-code-kit skills`.
- Pairs with `scripts/doctor.sh`: capabilities = "what you have", doctor = "is it set up correctly".
