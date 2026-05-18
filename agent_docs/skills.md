# Skills Guide

## What Are Skills?

Skills are `.claude/skills/<name>/SKILL.md` files that Claude Code loads automatically via semantic matching. When a task matches a skill's description, Claude gets the skill's knowledge injected into context — no manual loading needed.

## Skills vs Lessons

| | `tasks/lessons/` | `.claude/skills/` |
|---|---|---|
| **Trigger** | User corrects Claude | Claude discovers something non-obvious |
| **Content** | What went wrong + rule to follow | Problem + context + verified solution |
| **Format** | YAML frontmatter + Issue / Root Cause / Rule (one file per lesson) | YAML frontmatter + structured sections |
| **Loading** | `_index.md` → Top Rules at session boot; individual lesson files on-demand | Automatic via semantic matching |
| **Scope** | Mistakes to avoid | Knowledge to apply proactively |
| **Lifetime** | Grows per-project, refreshed via `/lesson-refresh` | Grows per-project, can be shared |

**Both systems complement each other.** Lessons prevent repeated mistakes. Skills proactively surface relevant knowledge.

## The Skill Extractor

The kit includes a built-in `skill-extractor` skill at `.claude/skills/skill-extractor/SKILL.md`. It:

- Can be invoked manually with `/skill-extractor`
- Activates automatically via semantic matching when discovery-worthy knowledge appears
- Uses a structured template for consistent skill formatting
- Has quality gates to prevent low-value extractions

## Enabling the Reminder Hook

An optional `UserPromptSubmit` hook reminds Claude to consider skill extraction at each prompt. It's **not enabled by default** (same as `auto-lint` and `auto-format`).

To enable, add to `.claude/settings.json` under the `hooks` key:

```json
"UserPromptSubmit": [
  {
    "hooks": [
      {
        "type": "command",
        "command": ".claude/hooks/skill-extract-reminder.sh"
      }
    ]
  }
]
```

## Writing Good Skills

### The 7 Principles

Every skill — whether hand-written or generated — should follow these principles:

1. **Explain the WHY** — Every rule needs a rationale. "Don't use `any`" is weak. "Don't use `any` because it disables type checking and hides bugs that only surface in production" is strong.

2. **Be concrete** — Real code examples over abstract descriptions. A developer should be able to copy-paste a pattern and have it work.

3. **Be project-specific** — Reference actual file paths, dependency versions, and config from the project. Generic advice belongs in docs, not skills.

4. **Be opinionated** — One best approach, enforced. Don't present a menu of options — pick the right one and explain why.

5. **Be testable** — Every rule should be verifiable via lint, test, or code review. If you can't check it, it's not a rule — it's a suggestion.

6. **Show both sides** — For critical rules, show both correct AND incorrect code. Developers learn faster from contrast.

7. **Keep it focused** — Each skill covers one concern. If it's over 500 lines, split it into multiple skills.

### Do Extract

- Framework quirks that caused hard-to-debug issues
- Config combinations that are required but undocumented
- Workarounds for known dependency bugs
- Project patterns that deviate from convention
- API behaviors that differ from documentation

### Don't Extract

- Anything easily found in official docs
- One-time fixes unlikely to recur
- User preferences (put in `CLAUDE.md`)
- User corrections (put in `tasks/lessons/<YYYY-MM-DD>-<slug>.md` using `tasks/lessons/_TEMPLATE.md`)
- Unverified guesses

### Quality Checklist

- [ ] Problem is clear to someone unfamiliar with the context
- [ ] Solution has been verified in this session
- [ ] Doesn't duplicate `CLAUDE.md` rules or existing lessons
- [ ] YAML `description` is specific enough for semantic matching
- [ ] Includes verification steps
- [ ] Every rule has a rationale (WHY, not just WHAT)
- [ ] Code examples use the project's actual stack and versions

## Skill Conventions (v1.11.0+)

Three conventions all skills should follow. The `scripts/validate-skills.sh` validator warns when these are missing.

### 1. Core Rule (required for every skill)

Every `SKILL.md` opens with a `## Core Rule` section — one sentence (max ~25 words) that anchors the skill's ethical scope.

```markdown
## Core Rule

Form a single hypothesis at a time. Validate with a falsifiable test before fixing. Never patch a symptom you haven't reproduced.
```

Goes immediately after the title (and the optional intro paragraph), before any other `##` section. The rule states what must be preserved or what's forbidden — the deal-breaker that distinguishes this skill from a free-form prompt. Inspired by [codex-complexity-optimizer](https://github.com/Kappaemme-git/codex-complexity-optimizer).

### 2. Default Behavior (required for audit-class skills)

Audit-class skills (skills with `## Output Format` that produce a structured report) include a `## Default Behavior` section telling the agent what to do **autonomously** when invoked. This removes friction from "audit / scan / review / give me a report" requests.

```markdown
## Default Behavior

When the user asks to audit, scan, review, or "give me a report" for <DOMAIN>, produce the full <skill-name> report automatically using the Process and Output Format sections below. Do not require the user to specify fields.

Only modify files when the user explicitly requests implement / fix / apply / refactor. By default, this skill is **report-only**.
```

The 10 audit-class skills today: `code-quality-audit`, `performance-audit`, `architecture-review`, `accessibility-audit`, `testing-audit`, `dependency-audit`, `documentation-audit`, `design-review`, `project-health-report`, `dead-code-audit`.

### 3. Phase 1 Inventory naming (audit-class skills)

Audit-class skills use uniform Phase 1 naming and an explicit "candidates, not findings" framing — discouraging the agent from reporting raw scanner output as final findings.

```markdown
### Phase 1: Inventory (first-pass leads)

This pass produces **candidates**, not findings. Treat counts as leads for deeper inspection in later phases. Do not report Phase 1 raw output as the final result.

<phase-specific content>
```

### Reusable Shared Blocks

When writing a new skill, copy patterns from the shared blocks:

- `.claude/skills/_shared/blocks/core-rule.md` — Core Rule template + examples
- `.claude/skills/_shared/blocks/default-behavior.md` — Default Behavior pattern with `<DOMAIN>` / `<skill-name>` placeholders
- `.claude/skills/_shared/blocks/inventory-framing.md` — Phase 1 framing

For templated skills (`.tmpl` files in `_templates/`), inline the actual text — bespoke per skill, not block-substituted.

---

## Skill Structure

### Simple (default)

```text
.claude/skills/<skill-name>/
  SKILL.md
```

Most skills are a single SKILL.md file. Use this for focused, specific discoveries.

### Extended (for complex skills)

```text
.claude/skills/<skill-name>/
  SKILL.md                  # Main instructions (< 500 lines, lean orchestration)
  references/               # Loaded on-demand at specific phases
    patterns.md             # Approved patterns with code examples
    anti-patterns.md        # Forbidden patterns with severity ratings
    checklist.md            # Pre-commit/merge verification checklist
    error-patterns.md       # Lookup tables, schema specs, language quirks
  assets/                   # Verbatim content copied/embedded by the skill
    output-template.md      # Templates the skill writes out (with placeholders)
```

Use the extended structure when:

- The skill has 5+ rules with code examples
- You need both correct AND incorrect examples side by side
- A pre-commit checklist would prevent recurring mistakes
- A lookup table is large but only needed at one phase (extract it to `references/`)
- The skill writes a file from a template (put the template in `assets/`)

Templates for all files are in `.claude/skills/skill-extractor/resources/`.

#### When to split content into `references/`

`references/` holds **on-demand reading material** — the agent loads it only when a specific phase asks for it. This keeps the SKILL.md focused on orchestration logic instead of catalog content.

A section is a good candidate to move when **all three** are true:

1. **Long** — 30+ lines of mostly tabular or list content (lookup-style, not narrative)
2. **Phase-specific** — only used at one or two points in the Process section, not throughout
3. **Catalog-like** — could grow over time (language-specific patterns, anti-patterns by category, framework quirks)

Counter-examples — keep these inline in SKILL.md:

- **Output format** — load-bearing structural anchor; readers scan SKILL.md to know what the output looks like
- **Process phases** — the orchestration sequence is the skill
- **Run Mode tables** — small, decision-critical, must be visible to anyone reading the skill

When you do split, replace the inline content with a short pointer at the phase that needs it:

```markdown
### Phase 2: Hypothesize
...
4. **Check the language pattern lookup** — if the error matches a category in
   `references/error-patterns.md`, use it to seed hypotheses
```

See `.claude/skills/debug/SKILL.md` (line ~140) and `.claude/skills/debug/references/error-patterns.md` for a worked example.

#### Bloat audit recipe

Run periodically to spot SKILL.md files that have grown beyond useful density:

```bash
cd .claude/skills
for f in */SKILL.md; do
  lines=$(wc -l < "$f" | tr -d ' ')
  examples=$(grep -c '^```' "$f")
  if [ "$lines" -ge 200 ] || [ "$examples" -ge 6 ]; then
    echo "  $f — $lines lines, $examples code blocks"
  fi
done
```

For each flagged skill:

1. Open the SKILL.md and look for any section matching the three split criteria above
2. If found → extract to `references/<topic>.md` and replace with a one-line pointer
3. If not found → the skill is genuinely dense, leave it alone
4. If the SKILL.md exceeds 500 lines → consider splitting into multiple skills entirely (see "Keep it focused" in the 7 Principles)

---

## Template-Based Skill Generation

For skills that share common kit rules (preamble, scope discipline, verification order), the kit provides a template system that prevents doc drift across skills.

### How It Works

1. **Shared blocks** in `.claude/skills/_shared/blocks/` contain reusable content (e.g., `preamble.md`, `scope-rules.md`)
2. **Templates** in `.claude/skills/_templates/*.tmpl` reference blocks via `{{PLACEHOLDER}}` tags
3. **Build script** (`./scripts/build-skills.sh`) assembles templates into final SKILL.md files

### Available Blocks

| Placeholder | File | Content |
|---|---|---|
| `{{PREAMBLE}}` | `preamble.md` | Session boot context check |
| `{{SCOPE_RULES}}` | `scope-rules.md` | Read-only analysis, scope discipline |
| `{{VERIFICATION_ORDER}}` | `verification-order.md` | Typecheck > lint > test > smoke |
| `{{PLAN_FIRST}}` | `plan-first.md` | Plan-first methodology for multi-file changes |
| `{{CONTEXT_GATHERING}}` | `context-gathering.md` | Project config and structure analysis |
| `{{REPORT_FOOTER}}` | `report-footer.md` | Report formatting guidelines |
| `{{MODE_DETECTION}}` | `mode-detection.md` | Interactive vs `mode:headless` run mode contract |

### Usage

```bash
# List available blocks and templates
./scripts/build-skills.sh --list

# Build all templated skills
./scripts/build-skills.sh

# Preview without writing
./scripts/build-skills.sh --dry-run
```

When a shared block changes (e.g., verification order gets a new step), run `build-skills.sh` once and all templated skills update automatically.

---

## Headless Mode Contract

Interactive skills can opt into a `mode:headless` run mode for automation, scheduled runs, and skill-to-skill orchestration. The canonical contract lives in `.claude/skills/_shared/blocks/mode-detection.md` and is summarized below.

### Detection

A skill is in headless mode when its argument bag contains the literal token `mode:headless`. The token is a flag, not content — strip it before treating the remainder as user input.

```text
/<skill>                        # interactive
/<skill> mode:headless          # headless
/<skill> mode:headless context  # headless, with context hint
```

### Contract

In headless mode, a skill must:

- Skip every "ask the user" step. Substitute the default documented in its own `## Run Mode` section.
- Never prompt for confirmation. Decisions are pre-committed by the defaults.
- Replace the interactive end ("What's next?") with a structured terminal report listing what was done.
- Exit non-zero with a clear error rather than blocking on user input if a default cannot be satisfied.

Headless mode applies for the entire run once detected — do not switch back to interactive mid-skill.

### Adding headless mode to a skill

1. Identify the skill's interactive decision points (anywhere it asks the user a question or waits for approval).
2. For each, document a **deterministic default** that a human would consider reasonable for unattended runs.
3. Add a `## Run Mode` section to the skill's SKILL.md with a table of `Decision point | Interactive default | Headless default`.
4. Reference the shared contract: `see .claude/skills/_shared/blocks/mode-detection.md`.

Some skills should remain interactive-only — those whose value *is* the dialogue (e.g., `office-hours`, `deepening-review`). Do not force headless mode where it would defeat the skill's purpose.

### Skills with headless support

| Skill | Useful headless trigger |
|---|---|
| `skill-extractor` | Hook reminder firing after a session with verified discoveries |
| `retro` | Weekly cron (`/loop weekly`) producing a strictly-from-artifacts report |
| `ship` | CI pipeline after pre-validation outside the skill |
| `review-pipeline` | Scheduled PR sweeps, CI pre-merge gates, skill-to-skill orchestration |

---

## Extending the Kit (Resolution Order)

The kit ships ~25 core skills. Projects regularly need to (a) add new skills the kit doesn't ship, (b) tweak existing skills for a project's stack, or (c) override a skill entirely for a single project. The kit handles all three through a fixed resolution order — at runtime, Claude Code reads the first match it finds.

### The four layers

```text
Priority  Layer                              Location                                Owner
⬆ 1       Project-local overrides            .claude/skills/<name>/SKILL.md          Project
2         Community extensions               .claude/extensions/<name>/SKILL.md      Third-party
3         Project-overlay slot               .claude/skills/<name>/project/          Project (additive)
⬇ 4       Kit core                           .claude/skills/<name>/SKILL.md          Kit
```

When two layers define the same `<name>`, the higher-priority layer wins entirely — there is no field-level merging. The lower-priority version is shadowed, not deleted; removing the override restores the lower layer automatically on the next read.

### Each layer in detail

**Layer 1 — Project-local overrides.** A file at `.claude/skills/<name>/SKILL.md` in the project repo that shadows the kit's version of the same name. Use this when one project needs a fundamentally different version of a skill the kit ships. The override is one file; the rest of the kit's `<name>/templates/` directory still applies unless the override also redefines those. *Mark project-managed:* commit it normally; `install.sh` only writes to skill directories that don't exist, so existing project overrides survive upgrades.

**Layer 2 — Community extensions.** A folder under `.claude/extensions/<name>/SKILL.md` containing a skill the kit does not ship. Source: a teammate's PR, a community plugin, or a Claude Code plugin marketplace entry mirrored locally. Same shape as a core skill, just sitting in a different directory. The kit's installer never touches `.claude/extensions/` — its lifecycle is owned by whoever published it.

**Layer 3 — Project-overlay slot.** A folder at `.claude/skills/<name>/project/` next to a core skill. Used for additive content the skill explicitly looks for at runtime (e.g. `.claude/skills/quality-audit/project/golden-principles.local.yaml`). Unlike Layer 1, this *doesn't shadow* the SKILL.md — it adds project-specific content the kit-managed skill knows how to pick up. Hooks already use this pattern at `.claude/hooks/project/` and `install.sh` is wired to preserve it.

**Layer 4 — Kit core.** Default. Everything ships at this layer.

### When to use which

| You want to | Use |
|---|---|
| Add a new skill the kit doesn't have | Layer 2 (extension) — keeps it separate from kit upgrades |
| Tweak a kit skill's behaviour for one project | Layer 3 (overlay) if the skill supports it, else Layer 1 (override) |
| Replace a kit skill entirely | Layer 1 (override) |
| Contribute a new skill back to the kit | Open a PR; it becomes Layer 4 |

### Conflict resolution

The kit's `scripts/validate-skills.sh` warns when two layers define the same `<name>`. The warning is informational — the priority order is deterministic — but it's a signal that a kit upgrade may be hiding a project-local intent. Resolve by either renaming the override or by upstreaming the customization (open a PR to move it to Layer 4 or a community extension).

### Comparison to other ecosystems

[Spec Kit](https://github.com/github/spec-kit) ships the same conceptual model with a different vocabulary: their `.specify/templates/overrides/` is our Layer 1; their `.specify/presets/templates/` is our customization-via-templates surface (`.claude/skills/_templates/` + `_shared/blocks/`); their `.specify/extensions/templates/` is our Layer 2; their `.specify/templates/` is our Layer 4. The kit does not ship a `specify`-style CLI for managing layers — extensions are added by `cp -r` from a source repo or by installing a Claude Code plugin from the marketplace.

See ADR-015 for the decision history behind this model.

---

## Skill Lifecycle

1. **Discovery** — Claude encounters something non-obvious during a session
2. **Verification** — The discovery is confirmed to be correct
3. **Extraction** — Written as a SKILL.md using the template
4. **Loading** — Automatically picked up by Claude Code's semantic matching
5. **Maintenance** — Update or remove skills as the project evolves

### Maintenance Tips

- Review `.claude/skills/` periodically — delete stale skills
- If a skill's solution becomes the documented approach, remove it
- If a skill applies to multiple projects, consider extracting it to `~/.claude/skills/` (user-level)

---

## Periodic Cleanup ("Spa Day")

As rules, skills, and lessons accumulate, agent performance degrades. This is context bloat — the agent reads too much conflicting or irrelevant information before doing actual work.

### When to Clean Up

- Agent starts ignoring rules it used to follow
- Agent behavior becomes inconsistent across sessions
- Session boot requires reading 10+ files
- Skills or lessons contradict each other
- You notice the agent "forgetting" things mid-session more often

### Cleanup Checklist

Run this periodically (every 2-4 weeks or when symptoms appear):

#### 1. Audit CLAUDE.md
- [ ] Is every instruction still relevant?
- [ ] Are there rules that no longer apply to the project?
- [ ] Are there contradictions between rules?
- [ ] Is the agent_docs directory listing still accurate?

#### 2. Consolidate Lessons
- [ ] Read all entries in `tasks/lessons/` (or use `/lesson-refresh`)
- [ ] Merge duplicate or similar lessons
- [ ] Remove lessons that have been encoded as rules in CLAUDE.md
- [ ] Remove lessons for bugs that were structurally fixed (no longer possible)

#### 3. Prune Skills
- [ ] List all skills: `ls .claude/skills/`
- [ ] For each skill: is the problem still relevant?
- [ ] For each skill: has the solution become standard (in docs or framework)?
- [ ] For each skill: does the YAML description still match what it does?
- [ ] Remove stale or redundant skills

#### 4. Check for Contradictions
- [ ] Do any skills contradict CLAUDE.md rules?
- [ ] Do any lessons contradict skills?
- [ ] Do any agent_docs files give conflicting advice?
- [ ] Resolve every contradiction — pick one source of truth

#### 5. Measure Context Load
Count how many files the agent reads at session boot + task start:
- **Healthy**: 3-5 files
- **Concerning**: 6-10 files
- **Critical**: 10+ files — consolidate immediately

### How to Run a Cleanup Session

Tell the agent:

```text
Read all files in agent_docs/, tasks/lessons/, all skills in .claude/skills/,
and CLAUDE.md. Identify contradictions, stale content, and redundancies.
Present a consolidation plan. Do not make changes until I confirm.
```

This leverages the agent's ability to cross-reference content while keeping you in control of what gets removed.
