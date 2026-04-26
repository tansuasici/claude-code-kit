---
name: interface-design
description: Design It Twice — spawn 3-4 parallel sub-agents producing radically different interfaces for a module, then compare on depth, locality, and seam placement. Use before committing to a new interface.
user-invocable: true
---

# Interface Design

## Kit Context

Before starting:

1. Read `CODEBASE_MAP.md` for project understanding
2. Read `CLAUDE.project.md` if it exists for project-specific rules
3. Read `agent_docs/architecture-language.md` — **required**. This skill speaks its vocabulary.
4. Read `tasks/decisions.md` — don't re-litigate ADR-resolved interface decisions.

If `agent_docs/architecture-language.md` hasn't been read in this session, read it now.

## When to Use

Invoke with `/interface-design <module>` when:

- After `/deepening-review` settles on a deepening candidate and the user wants to see alternative interface shapes before committing
- A new module is about to be created and the first interface idea feels under-explored
- An existing interface is being rewritten and "design it once" feels insufficient
- You catch yourself converging on the first plausible interface — that's exactly when this skill earns its keep

Based on Ousterhout's *"Design It Twice"*: **your first interface idea is unlikely to be the best.** Spawning parallel agents with different constraints produces designs you wouldn't have reached by iterating sequentially on one.

## When NOT to Use

- Trivial modules (a 3-line utility doesn't warrant 3 competing designs)
- When the interface is dictated by an external contract (HTTP spec, protobuf, third-party SDK shape) — there's nothing to design
- When the user has already committed to a shape and just wants implementation help

## Hard Rules

- Use `architecture-language.md` vocabulary when *classifying* the module being designed. Don't substitute "service / boundary / component" for **module / seam / interface** in your reasoning or in sub-agent briefs. (Descriptive uses — referring to Stripe as a "third-party service" — are fine.)
- Spawn at least **3** sub-agents in parallel. Two designs collapse into a binary; three produce real contrast.
- Each sub-agent must produce a **radically different** design. If two come back similar, re-spawn one with a sharper constraint.
- The user reads while sub-agents work — don't block.
- End with an **opinionated** recommendation. Not a menu.

## Process

### Phase 1: Frame the Problem Space

Before spawning sub-agents, write a user-facing brief covering:

- **The module being designed** — name, purpose in domain language
- **Constraints** — invariants, ordering, error modes any interface must respect
- **Dependencies** — categorized per [`deepening-review/references/dependency-categories.md`](../deepening-review/references/dependency-categories.md)
- **Code sketch** — a rough illustrative shape (not a proposal — just enough to ground the constraints)
- **What the deepened module hides** — the complexity behind the seam

Show this to the user. Don't wait for them to read it — proceed to Phase 2 immediately. The user reads while sub-agents work in parallel.

### Phase 2: Spawn Sub-Agents in Parallel

Use the `Agent` tool. **One message, multiple tool calls** — they must run concurrently.

Each sub-agent gets:
1. The shared technical brief (file paths, dependency categories, what's behind the seam, vocabulary requirements)
2. A **different design constraint** that forces radical divergence

Standard four constraints (use 3 if the fourth doesn't apply):

| Agent | Constraint |
|---|---|
| **Minimal** | Aim for 1-3 entry points maximum. Maximize leverage per entry point. Anything that can be expressed as a parameter rather than a method, must be. |
| **Flexible** | Maximize flexibility and extension points. Optimise for use cases not yet imagined. Hooks, middleware, callbacks welcome. |
| **Common-Case** | Optimise for the *most common* caller. The default case must be trivially callable; advanced cases can require more setup. |
| **Ports & Adapters** | Design assuming Category 3/4 dependencies. Define ports at the seam. Production adapter and test adapter both real. |

Drop "Ports & Adapters" if dependencies are all Category 1/2. Replace with **State-Machine** (model the module as explicit states + transitions) or **Functional-Core** (push as much as possible into pure functions; thin imperative shell) if either is a better fit for the problem.

Each sub-agent must output:

```markdown
## Interface
[Types, methods, parameters — plus invariants, ordering, error modes, configuration]

## Usage Example
[Realistic code showing how a caller uses it]

## What's Behind the Seam
[What the implementation hides — including internal seams not exposed by the interface]

## Dependency Strategy
[Per-dependency: category + adapter strategy if applicable]

## Trade-offs
[Where leverage is high. Where it's thin. What's deliberately hard.]
```

### Phase 3: Present and Compare

Don't dump three designs at once. **Present them sequentially** so the user can absorb each one:

```markdown
## Design 1 — [Constraint name]
[Sub-agent's output, lightly cleaned for formatting]

## Design 2 — [Constraint name]
[...]

## Design 3 — [Constraint name]
[...]
```

Then compare in prose along three axes:

- **Depth** — leverage at the interface. Which design lets callers do the most per unit of interface they have to learn?
- **Locality** — where change concentrates. Which design means a typical change touches the fewest files?
- **Seam placement** — where the interface lives. Which design puts the seam where it actually needs to vary?

The comparison is structured but the verdict is editorial. Don't hide behind "it depends."

### Phase 4: Recommend

Give your own pick. Be opinionated.

```markdown
## Recommendation

**Pick: Design N**

Reasoning:
- [Why this design wins on the axis that matters most for *this* module]
- [What you accept losing by not picking the others]
- [What hybrid elements (if any) are worth borrowing from rejected designs]

If the user disagrees with the choice of axis, the verdict can flip — call that out:
*"If [different priority] is actually the most important constraint, Design M wins instead."*
```

If two designs combine well, **propose a hybrid explicitly** — don't just say "could be combined." Sketch the merge.

### Phase 5: Hand-off

Once the user picks (your recommendation or otherwise):

- Write the chosen interface to `tasks/todo.md` as the planned shape
- If this came from `/deepening-review` — update the deepening task with the chosen interface
- If the rejected designs surface load-bearing reasons not to take them — offer ADRs in `tasks/decisions.md`

Implementation goes through the kit's normal Plan First → confirmation → execution flow. This skill ends at "we know the interface."

## Output Format

```markdown
# Interface Design — [Module Name]

## Problem Space
[Frame: constraints, dependencies, sketch, what's behind the seam]

[Sub-agents working in parallel...]

## Design 1 — Minimal
[Output]

## Design 2 — Flexible
[Output]

## Design 3 — Common-Case
[Output]

## Comparison
[Prose comparison: depth / locality / seam placement]

## Recommendation
[Opinionated pick + reasoning + optional hybrid]
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I already know what the interface should be" | Then `Design It Twice` is exactly when you should run this skill. The cost of three sub-agents is small; the cost of an interface that locks in a worse design is large. |
| "All three designs converged on the same thing" | Then either the constraints were too narrow or the sub-agent briefs weren't divergent enough. Re-spawn with sharper constraints. |
| "Let the user pick — they know best" | The user wants a *strong read*, not a menu. They can override your pick, but they need an opinion to push against. |
| "The interface doesn't matter — implementation does" | The interface is what callers see, what tests exercise, what survives implementation rewrites. It matters more than the implementation. |
| "I'll just iterate after shipping v1" | Interfaces calcify the moment a second caller depends on them. The cost of changing an interface scales with caller count. Get it right before shipping. |

## Notes

- This skill leans heavily on parallel sub-agent execution. Verify all three are spawned in **one message** with multiple `Agent` tool calls — sequential spawning loses the parallelism that makes this useful.
- Inspired by John Ousterhout's *A Philosophy of Software Design* (Design It Twice principle) and the [improve-codebase-architecture](https://github.com/mattpocock/skills/tree/main/improve-codebase-architecture) skill by Matt Pocock.
- Pairs with `/deepening-review` (which finds the candidate) and `/refactoring-guide` (which sequences the implementation).
