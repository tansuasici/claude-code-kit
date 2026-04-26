---
name: deepening-review
description: Surface shallow modules as deepening candidates, then grill the chosen one interactively — depth/seam paradigm. Use for testability and AI-navigability when modules feel pass-through or fragmented.
user-invocable: true
---

# Deepening Review

## Kit Context

Before starting this skill, ensure session boot is complete:

1. Read `CODEBASE_MAP.md` for project understanding
2. Read `CLAUDE.project.md` if it exists for project-specific rules
3. Read `agent_docs/architecture-language.md` — **required**. This skill uses its vocabulary exactly.
4. Read `tasks/decisions.md` if it exists — don't re-litigate ADR-resolved decisions.

If `agent_docs/architecture-language.md` hasn't been read in this session, read it now before proceeding.

## When to Use

Invoke with `/deepening-review` when:

- The user wants to improve architecture for testability or AI-navigability
- A module cluster feels tightly coupled and hard to reason about
- Tests exist but bugs keep escaping — suggesting tests sit past the wrong seam
- Onboarding to a codebase and noticing pass-through modules that hide nothing
- After `/architecture-review` flagged structural issues without suggesting concrete refactors

## When NOT to Use

- For SOLID violations / module health metrics → use `/architecture-review`
- For specific code smells (long function, feature envy, etc.) → use `/code-quality-audit` then `/refactoring-guide`
- For unused code → use `/dead-code-audit`
- For projects under ~5 source files — depth analysis needs surface area

## Paradigm vs `/architecture-review`

| Lens | This skill (`deepening-review`) | `architecture-review` |
|---|---|---|
| Vocabulary | Module / Interface / Depth / Seam / Adapter / Leverage / Locality | SOLID, layers, coupling, cohesion |
| Output mode | Interactive — candidates, grilling loop | Report — structured assessment |
| Question | *"Where can a shallow module become deep?"* | *"Where are SOLID principles violated?"* |
| Test angle | The interface is the test surface — replace tests, don't layer | Inject dependencies, abstract behind interfaces |

Run them together for breadth + surgical depth. They don't overlap — they speak different languages on purpose.

## Hard Rules

- Use `architecture-language.md` vocabulary when *classifying* architecture. Don't reach for "service," "component," "API," or "boundary" as substitutes for **module**, **interface**, or **seam** in your reasoning. (Descriptive uses — "Stripe is a third-party service," "across a network boundary" — are fine; what matters is not classifying *your own* parts that way.)
- Don't propose interfaces in step 2 (Present Candidates). Only candidates. Interfaces come in step 3 (Grilling) or `/interface-design`.
- Don't flag ADR-resolved decisions as candidates unless the friction is severe enough to warrant reopening the ADR. Mark such candidates explicitly.
- Apply the **deletion test** to every shallow-looking module before listing it.
- One adapter = hypothetical seam. Don't propose ports without two real adapters.

## Process

### Phase 1: Explore

Read existing context first:

- `CODEBASE_MAP.md` — module map and conventions
- `tasks/decisions.md` — past architectural ADRs (don't re-litigate)
- Any project-specific domain glossary (e.g. `agent_docs/project/domain.md` if it exists)

If domain context files don't exist, proceed silently — don't flag their absence or insist on creating them.

Then walk the codebase. Use the `Agent` tool with `subagent_type=Explore` for organic exploration — don't follow rigid heuristics. Note where you experience friction:

- Where does understanding one concept require bouncing between many small modules?
- Where are modules **shallow** — interface nearly as complex as the implementation?
- Where have pure functions been extracted just for testability, while the real bugs hide in how they're called (no **locality**)?
- Where do tightly-coupled modules leak across their seams?
- Which parts of the codebase are untested, or hard to test through their current interface?

Apply the **deletion test** to anything you suspect is shallow. A "yes, deletion concentrates complexity meaningfully" is the signal.

### Phase 2: Present Candidates

Present a numbered list of deepening opportunities. For each candidate:

```markdown
### Candidate N: [Short name using domain language]

**Files**: `path/to/a.ts`, `path/to/b.ts`, `path/to/c.ts`

**Problem**: [Where the shallowness shows. What complexity leaks across the seams now.]

**Solution**: [Plain English: what would be merged, where the new seam goes, what sits behind it.]

**Benefits (locality)**: [What concentrates if we deepen — bug fixes, change surface, knowledge.]

**Benefits (leverage)**: [What callers stop having to know.]

**Test impact**: [What tests survive, what gets deleted, what gets written at the new interface.]

**Dependency category**: [in-process / local-substitutable / remote-but-owned / true-external — see references/dependency-categories.md]
```

If a candidate contradicts an existing ADR, mark it: *"Contradicts ADR-NNN — but worth reopening because [load-bearing reason]."* Skip theoretical contradictions.

End the list with: **"Which candidate would you like to explore? (or 'all' / 'none')"**

Do **not** propose interfaces in this phase. Naming a deepened module is fine; specifying its method signatures is not.

### Phase 3: Grilling Loop

Once the user picks a candidate, drop into an interactive grilling conversation. Walk the design tree with them.

Detail in [references/grilling-protocol.md](references/grilling-protocol.md). Key points:

- Surface constraints first (what must hold true)
- Map dependencies to a category (see [references/dependency-categories.md](references/dependency-categories.md))
- Explore what sits behind the seam
- Identify which existing tests survive, which get deleted, which get written
- Side effects happen inline — update domain glossary if a new term emerges; offer ADR if user rejects with a load-bearing reason; invoke `/interface-design` if the user wants to explore alternative interfaces.

### Phase 4: Hand-off

When the grilling settles on a direction:

- Summarize the agreed-upon shape (deepened module, seam location, adapter strategy, test strategy)
- Write a refactoring task to `tasks/todo.md` using the kit's standard plan template (see `agent_docs/workflow.md`)
- If the agreed shape requires interface design → suggest `/interface-design` next
- If the user rejected the candidate with a reason future explorations should respect → write an ADR entry to `tasks/decisions.md`

Do **not** start implementing. Deepening is a multi-file refactor; it goes through Plan First → confirmation → execution per the kit's workflow.

## Output Format

```markdown
# Deepening Review

## Summary
[1-2 sentences: how many candidates, what kind of friction dominates.]

## Candidates

### Candidate 1: [name]
[Files / Problem / Solution / Benefits (locality) / Benefits (leverage) / Test impact / Dependency category]

### Candidate 2: [name]
[...]

## Out of scope (logged for later)
- [Issues noticed but not pursued — to tasks/todo.md → ## Not Now]

---

**Which candidate would you like to explore? (or 'all' / 'none')**
```

After user picks → switch to grilling format (free-form Q&A, see references/grilling-protocol.md).

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "It's clean — every module does one thing" | Shallow modules each doing one thing produce **diffusion of complexity**. The user has to bounce between N tiny files to understand one operation. Locality lost. |
| "We extracted these for testability" | The pure-function extraction is fine, but if the bugs hide in *how the pure functions are composed* — your test suite tests past the wrong seam. The interface is the test surface. |
| "It's a port-and-adapters architecture" | Check: how many adapters? One adapter means a hypothetical seam — just indirection. Two means a real seam. |
| "We can't deepen, the modules are owned by different teams" | Then the seam is correctly placed at a team boundary. Don't deepen across teams; do deepen within. |
| "Refactoring is too risky" | Deepening that *removes* a shallow layer is one of the safest refactors — fewer abstractions to maintain. The risky one is **deepening the wrong module** by guessing where leverage lives. The grilling loop exists to prevent that. |
| "The architecture is already documented" | Documentation describes; the deletion test asks if the documentation is *load-bearing*. A module no one would miss isn't deep just because it's named. |

## Notes

- This skill speaks a deliberately narrow vocabulary. If you find yourself reaching for "service," "boundary," or "component" — re-read `agent_docs/architecture-language.md`.
- Inspired by John Ousterhout (deep modules), Michael Feathers (seams), and the [improve-codebase-architecture](https://github.com/mattpocock/skills/tree/main/improve-codebase-architecture) skill by Matt Pocock.
- Pairs well with `/interface-design` for the chosen candidate's interface, and `/refactoring-guide` for the tactical execution sequence.
