# Grilling Protocol

Once the user picks a candidate from the deepening review, drop into an interactive grilling conversation. The goal: walk the design tree together, surface every load-bearing constraint, and arrive at a shape both of you can defend.

This is **not** a question-form-fill exercise. It's a real conversation. Some questions matter for one candidate and not another. Read the situation.

Vocabulary: see [`agent_docs/architecture-language.md`](../../../../agent_docs/architecture-language.md). Keep the discipline.

---

## Stance

- **You are not the architect** — the user is. You're a sparring partner who applies the deletion test and the depth/leverage lens, then yields to their domain knowledge when it's load-bearing.
- **Press, don't push** — if the user's reason for a constraint is shallow ("we've always done it this way"), keep pressing. If it's deep ("this satisfies SOC 2 control X"), accept and move on.
- **Stay in scope** — you're grilling *one* candidate. Other candidates' issues are not under discussion here.
- **No code yet** — this phase ends with a design shape, not an implementation.

---

## The Tree

Walk these branches in roughly this order. Skip branches that don't apply.

### Branch 1: Constraints

Surface what *must* hold true regardless of design choice.

- What invariants must the deepened module preserve?
- What ordering / consistency / atomicity requirements exist?
- What latency or throughput floor is non-negotiable?
- What error modes must be observable to callers? (Not "what errors might happen" — "what must callers be able to react to.")
- Are there compliance / audit / multi-tenancy constraints that bind the seam location?

If a constraint sounds load-bearing but the user can't articulate *why* — that's a signal to press. "Why this constraint?" → "What breaks if we relax it?" → "Is the breakage real or imagined?"

### Branch 2: Dependencies

Map every dependency to a category from [dependency-categories.md](dependency-categories.md):

- In-process → no adapter needed
- Local-substitutable → pick the stand-in
- Remote-but-owned → confirm two adapters (production + test) are justified
- True external → identify the *capability* you use, not the third-party API

Common surprise: dependencies the user didn't think about. Things like clocks (`Date.now()`), randomness, environment variables, process exit codes, log sinks. These are dependencies even when they look like "just code."

### Branch 3: Behind the Seam

What sits inside the deepened module — and what stays outside?

- Which currently-shallow modules merge into the deep one?
- What new internal structure (private functions, internal seams) does the deepened module need?
- What does the module *not* own? (Equally important — depth is not omnipresence.)
- Is there state? Where does it live? When is it created and destroyed?

The deletion test goes here too: "If we deepen this and call it X, would deleting X concentrate complexity meaningfully? Or is X still a pass-through under a new name?"

### Branch 4: The Interface

What is the smallest **interface** that gives callers maximum **leverage**?

- What entry points does the module expose?
- What does each entry point owe its callers in terms of invariants, errors, ordering?
- What configuration does the module need at construction vs. per-call?
- What does the interface *deliberately* not expose? (Internal seams, implementation choices, dependency identity.)

If the interface starts looking large (5+ methods, complex parameter shapes), that's a signal to either:
- Split — maybe two deep modules instead of one
- Or invoke `/interface-design` to compare alternatives

Don't try to converge on a single interface here. A *shape* is enough at this stage.

### Branch 5: Tests

Which tests survive, which get deleted, which get written?

- What tests currently exist at the shallow modules' interfaces? Most will become waste.
- What new tests get written at the deepened interface? List them in plain English.
- What scenarios that were previously hard to test become easy at the new interface?
- What scenarios become *harder* to test? (Honest answer — there's usually at least one.)

The interface is the test surface. If you find a scenario only testable by reaching past the interface, the seam is in the wrong place.

### Branch 6: Trade-offs

Be explicit about what's lost.

- What flexibility is given up? (Some shallow modules exist because they were extension points — losing them might be fine, might not.)
- What knowledge concentrates in fewer hands? (Locality is good for maintenance, less good for bus factor.)
- What dependencies between teams or modules does this rearrange?
- What does this *not* solve? (Adjacent friction the user might mistakenly expect to vanish.)

A direction without a clear trade-off statement is incomplete.

---

## Side Effects

These happen **inline** as the conversation unfolds — don't batch them for the end.

### Domain glossary update

If you find yourself naming the deepened module after a concept that doesn't appear in `CODEBASE_MAP.md`, the project domain glossary, or `agent_docs/project/domain.md`:

> *"This name — `OrderIntake` — isn't in the project's domain vocabulary yet. Should I add it to `[wherever the project keeps domain terms]` so future explorations find it?"*

Add it there before continuing the grilling.

### Term sharpening

If a term comes up that the user uses one way and the codebase uses another way (e.g. "Order" means different things in two places):

> *"You're using `Order` to mean the customer-facing record; the codebase has it pointing at the internal fulfilment row. Do we want to disambiguate before going further?"*

Sharpen now or you'll bake the ambiguity into the deepened module.

### ADR offer

If the user **rejects** the candidate (or a load-bearing branch of it) with a reason that future explorers should respect:

> *"You're rejecting this because [reason]. Want me to record this as an ADR in `tasks/decisions.md` so future architecture reviews don't re-suggest the same thing?"*

Offer the ADR only when the reason is:
- **Load-bearing** — actually constrains future decisions
- **Non-obvious** — not something a fresh reader would re-derive
- **Stable** — the constraint will outlast this sprint

Skip the offer for "not worth it right now" (ephemeral) or "obviously bad idea" (self-evident).

### Interface design hand-off

If the user wants to compare alternative interfaces:

> *"This feels like a `/interface-design` moment — let me spawn parallel sub-agents with different design constraints (minimize / maximize flexibility / common-case / ports & adapters) and bring back competing interfaces. Want me to?"*

If yes → end the grilling, invoke `/interface-design` for the candidate.

---

## Closing the Grilling

The grilling is done when:

- The user can describe the deepened module's shape in 2-3 sentences
- Dependencies are categorized
- A test strategy is outlined
- Trade-offs are explicit

When you sense closure, summarize:

> *"Let me restate the shape we've landed on: [deepened module name] absorbs [list]. Seam at [location], adapter strategy: [strategy]. Tests at [interface]. Trade-off accepted: [trade-off]. Did I get that right?"*

Once the user confirms — write a refactoring task to `tasks/todo.md` using the kit's standard plan template (see `agent_docs/workflow.md`). Do not start implementing — that goes through the kit's normal Plan First → confirmation → execution flow.

---

## What to do when the conversation stalls

- **User keeps deferring** ("let me think about it") → close out with: *"Let's park this. I'll write what we have to `tasks/todo.md` as a parked candidate. You can resume by saying `/deepening-review continue [name]`."*
- **User pivots to a different candidate** → fine. End this grilling. Restart with the new pick.
- **User wants to scrap the original candidate** → ask: *"Do you want to scrap entirely, or did we surface a different shape worth pursuing?"* Often grilling produces a *better* candidate than the one we started with.
- **You realize the candidate was wrong** → say so. *"Pressing on this, I think the deepening is actually [different shape]. Want to pivot?"* Don't pretend the original was right.
