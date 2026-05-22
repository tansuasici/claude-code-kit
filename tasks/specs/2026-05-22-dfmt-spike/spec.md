# DFMT Pattern Spike — Recommendation

**Status:** Recommendation `BUILD DIFFERENTLY` — see § 5.
**Linear:** [CLA-26](https://linear.app/claudecodekit/issue/CLA-26/spike-intent-aware-tool-wrappers-dfmt-pattern-evaluation)
**Date:** 2026-05-22
**Spike length:** ~1 focused session (target was ~2 h)

---

## 1. What DFMT is

[WrongStack](https://github.com/WrongStack/WrongStack/blob/main/CLAUDE.md) ships a `<!-- dfmt:v1 -->` "Context Discipline" block in its CLAUDE.md that wraps the standard tools with `dfmt_*` MCP equivalents:

| Native | DFMT replacement | `intent` required? |
|---|---|---|
| `Bash` | `dfmt_exec` | yes |
| `Read` | `dfmt_read` | yes |
| `WebFetch` | `dfmt_fetch` | yes |
| `Glob` | `dfmt_glob` | yes |
| `Grep` | `dfmt_grep` | yes |
| `Edit` | `dfmt_edit` | n/a |
| `Write` | `dfmt_write` | n/a |

Every read/grep/exec call must pass an `intent` string ("failing tests", "imports", "error message"). Without intent, raw bytes are returned and the token savings collapse. The MCP also exposes `dfmt_remember` for substantive findings, tagged `decision` / `finding` / `summary`, so the agent can journal across compactions.

Three claims to evaluate:

1. **Intent-aware output filtering** at the tool layer cuts context flooding before it happens
2. **Forced intent declarations** make the agent's reasoning explicit (you can't grep without naming what you're looking for)
3. **Mid-session journaling** (`dfmt_remember`) preserves findings across `/compact`

---

## 2. What kit already does in this space

A surprise during inventory — kit is _not_ starting from zero:

- **`.claude/hooks/bash-budget.sh`** (PostToolUse, Bash matcher) already measures cumulative Bash output per session, tracks the top-5 most expensive command heads, and emits a one-shot warning at `BASH_BUDGET_THRESHOLD` (default 50k tokens). It also suggests compact-output flags (`git status --short`, `pytest -q --tb=line`, `rg --count`).
- **`agent_docs/conventions.md → Compact Output Flags`** documents the same compact-flag conventions as passive guidance.
- **`agent_docs/workflow.md → Context Hygiene`** covers `/compact` and `/clear` lifecycle (just added in CLA-27 batch — proactive triggers + suggested budgets ~4k/task, ~30k/session).
- **CLAUDE.md → After Compaction** covers the reactive recovery path.
- **`tasks/decisions.md`** captures cross-session decisions; **`tasks/handoff-*.md`** captures across-session resumption state; **`tasks/lessons/`** captures user-correction history.

So kit already has: tool-output **measurement**, **passive guidance** on compact flags, and **cross-session memory** primitives. What it does _not_ have is the DFMT MCP-style trio: forced-intent declarations, active output filtering, and mid-session journaling.

---

## 3. Spike questions answered

### 3.1 Is intent-aware filtering worth building?

**No, not as a primary lift.** Three reasons:

1. **Claude already filters at call time.** `Read` supports `offset` + `limit`; `Grep` supports `output_mode: files_with_matches` / `count` / `content`, `head_limit`, `context lines`; `Bash` accepts compact flags directly. The agent's native tool surface gives it the same expressive power DFMT does, just per-call instead of per-wrapper. The discipline question is _whether the agent uses these flags_, not whether they exist.

2. **`bash-budget.sh` already covers Bash, the empirically dominant cost center.** It doesn't filter, but it _measures_ and nudges — that is the form of discipline kit already prefers (CLAUDE.md is a rules layer, hooks are a measurement / blocking layer, never a content-rewrite layer).

3. **Building active filtering risks reliability regressions.** Filtered tool output is silently lossy. If the filter is wrong, the agent acts on incomplete data and fails in subtle ways — exactly the "loud failure" anti-pattern CLA-27 just added a rule against. WrongStack accepts this tradeoff because output is rebuildable on demand; kit's verification gate doesn't have the same recoverability.

**Where intent-aware filtering _would_ help:** very long, semi-structured outputs the agent re-reads often inside one session — e.g. a 2000-line `pytest -v` log from which the agent only ever wants the FAIL block. That's a real but narrow use case.

### 3.2 MCP vs script wrapper vs hook?

**Hook, not MCP.** Kit doesn't ship a Model Context Protocol server and doesn't want the maintenance surface of one. The same effect can be approximated by:

- **PreToolUse hook**: append a `# intent: <hint>` comment to the command before execution — non-binding, just documents the agent's stated goal in the audit log.
- **PostToolUse hook**: heuristic post-processing for known noisy commands (the same kind of pattern bash-budget.sh already tracks).

The intent-as-document angle is the higher-leverage half. Filtering is the lower-leverage half. Order accordingly.

### 3.3 What's the right intent vocabulary?

If we build the _intent-as-document_ form, the vocabulary should be small and shared with `applies_to` topics in `tasks/lessons/`. Reusing existing canonical topics avoids inventing a parallel taxonomy. Candidate values: `failing-tests`, `compile-errors`, `imports`, `function-defs`, `config-keys`, `match-context`, `audit-scan`, `setup-check`. ~8 values, not WrongStack's open string.

Open intent (WrongStack-style) is unenforceable. Closed intent enables auditing ("which intents dominate this session?") and is the only form worth shipping.

### 3.4 Does `dfmt_remember` overlap with kit's lessons?

**Different time-scales, complementary not redundant:**

| Kit primitive | Time-scale | Trigger |
|---|---|---|
| `tasks/lessons/` | across-session | User correction or agent self-discovery, deliberate |
| `tasks/decisions.md` (ADR) | across-session | Architectural decision, deliberate |
| `tasks/handoff-*.md` | across-session | Session interruption / wrap-up, deliberate |
| `dfmt_remember` (in WrongStack) | mid-session, **across-compaction** | Any moment, lightweight |

The mid-session / across-compaction slot is empty in kit. Today, if the agent discovers something useful at turn 30 and compaction hits at turn 50, that discovery is gone unless it landed in a file. CLAUDE.md → After Compaction tells the agent how to recover known files, but doesn't preserve mid-session findings.

**This is the real gap DFMT highlights.**

---

## 4. What we'd build (if we build)

The recommendation in § 5 says BUILD DIFFERENTLY. Concretely:

### 4.1 `/note <tag> <text>` skill — **the real lift**

A tiny skill that appends a timestamped line to `.hook-state/session-journal.md` (transient, gitignored, but durable across compactions inside the same Claude Code session — same lifetime as the other `.hook-state/` files):

```text
2026-05-22T18:42:11Z [finding] qdrant client lib treats `null` filter as ANY, not none
2026-05-22T18:55:03Z [decision] going with Drizzle ORM not Prisma — see ADR-014 draft
2026-05-22T19:10:44Z [summary] auth flow: JWT in httpOnly cookie + refresh token rotation in /api/refresh
```

After `/compact`, the agent's `## After Compaction` rule grows one line: "Re-read `.hook-state/session-journal.md` if it exists." That's it.

When the session ends, `session-end.sh` either copies the journal into `tasks/handoff-<id>.md` (if findings are unfinished) or discards it (if everything reached a lesson / decision / commit).

**Cost to build:** ~50 lines of skill + 5 lines of CLAUDE.md edit + 10 lines of session-end.sh edit. No MCP, no new deps.

### 4.2 PostToolUse intent log (optional, lower priority)

If the agent voluntarily prefixes Bash / Grep commands with `# intent: <vocab>` (via a CLAUDE.md rule), a PostToolUse hook can extract those intents, attach them to the audit log already maintained alongside `bash-budget.json`, and emit "intent coverage" in `/scorecard`. This gives us auditable evidence of _whether_ discipline is actually being followed.

This is purely observational; it does not filter, rewrite, or block. **Cost to build:** ~30 lines added to bash-budget.sh + one column in the scorecard. Defer to a separate spike if the journal lands.

### 4.3 What we explicitly are NOT building

- A full `dfmt_*` MCP server. Kit stays orchestration-only; tool wrapping is out of scope.
- Active output filtering / rewriting. Reliability cost > token savings, given that `bash-budget.sh` + compact flags + Claude's native call-time params already cover the easy wins.
- Forked intent vocabulary. Reuse `applies_to` canonical topics if/when 4.2 happens.
- WrongStack adoption ([CLA-24](https://linear.app/claudecodekit/issue/CLA-24) is cancelled).

---

## 5. Recommendation

**BUILD DIFFERENTLY.**

| Build | Don't build |
|---|---|
| `/note` skill + `session-journal.md` (across-compaction memory) | A full DFMT MCP server |
| (optional) PostToolUse intent observability in scorecard | Active tool-output filtering / rewriting |
| Document the journal in CLAUDE.md → After Compaction | A new closed intent vocabulary parallel to `applies_to` |

The cancellation of intent-aware filtering isn't because the idea is bad — it's because kit already covers the same ground via `bash-budget.sh` (measurement) + `agent_docs/conventions.md → Compact Output Flags` (guidance) + Claude's native call-time params (filtering at source). Adding a fourth layer would be net negative.

The journal piece _is_ a real gap. Mid-session across-compaction memory is the empty slot in kit's primitive set. The `/note` skill is the smallest possible delta that fills it without introducing an MCP.

---

## 6. Suggested follow-up

If this recommendation is accepted, file a new Linear issue:

> **Title:** `/note <tag> <text>` — mid-session journal skill, across-compaction memory
> **Acceptance:**
> - `.claude/skills/note/SKILL.md` defining the tags (`finding`, `decision`, `summary`) and append behavior
> - CLAUDE.md → After Compaction adds one line: "Re-read `.hook-state/session-journal.md` if it exists"
> - `session-end.sh` either folds journal into handoff or discards based on contents
> - Smoke test: write three notes, simulate compaction, confirm recovery
> **Scope:** ~50 lines total. Closes the across-compaction memory gap.

Then close CLA-26 as "spec attached, decision documented, follow-up filed."

---

## Sources

- DFMT pattern: [WrongStack CLAUDE.md](https://github.com/WrongStack/WrongStack/blob/main/CLAUDE.md)
- WrongStack architecture: [ARCHITECTURE.md](https://github.com/WrongStack/WrongStack/blob/main/ARCHITECTURE.md)
- Kit measurement layer: `.claude/hooks/bash-budget.sh`
- Kit compact-output guidance: `agent_docs/conventions.md → Compact Output Flags`
- Mercury "memory as lifecycle" thesis (separate but adjacent): [CLA-25](https://linear.app/claudecodekit/issue/CLA-25)
