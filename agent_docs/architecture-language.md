# Architecture Language

Shared vocabulary for architectural discussions. Used by `deepening-review` and `interface-design`. The point is **terminology discipline** — substituting "service," "API," "boundary," or "component" produces vague suggestions and re-litigates the same ground.

## Scope

This vocabulary governs **module topology** discussions — depth, seams, adapters. It is **not** a replacement for paradigm-specific vocabularies:

- `architecture-review` uses **SOLID** vocabulary (responsibilities, dependencies, layers) — that's a different lens.
- `code-quality-audit` uses **smell** vocabulary (Fowler) — also different.
- `refactoring-guide` uses **Fowler's catalog** (Extract Function, Move Method, etc.) — also different.

When discussing *should this module be deeper, where should the seam go, what does the interface owe its callers* — use this vocabulary. When discussing *which SOLID principle is violated* or *which refactoring technique applies* — use the paradigm appropriate to the lens.

---

## Terms

### Module
Anything with an interface and an implementation. Deliberately scale-agnostic — applies equally to a function, class, package, or tier-spanning slice.

_Avoid_: "unit," "component," "service" (each carries paradigm-specific baggage that derails the conversation).

### Interface
Everything a caller must know to use the module correctly. Includes the type signature, but also invariants, ordering constraints, error modes, required configuration, and performance characteristics.

_Avoid_: "API," "signature" (too narrow — those refer only to the type-level surface).

### Implementation
The code inside a module — its body. Distinct from **Adapter**: a thing can be a small adapter with a large implementation (a Postgres repo) or a large adapter with a small implementation (an in-memory fake). Reach for "adapter" when the seam is the topic; "implementation" otherwise.

### Depth
Leverage at the interface — the amount of behaviour a caller (or test) can exercise per unit of interface they have to learn. A module is **deep** when a large amount of behaviour sits behind a small interface. A module is **shallow** when the interface is nearly as complex as the implementation.

### Seam *(from Michael Feathers)*
A place where you can alter behaviour without editing in that place. The *location* at which a module's interface lives. Choosing where to put the seam is its own design decision, distinct from what goes behind it.

_Avoid_: "boundary" (overloaded with DDD's bounded context).

### Adapter
A concrete thing that satisfies an interface at a seam. Describes *role* (what slot it fills), not substance (what's inside).

### Leverage
What callers get from depth. More capability per unit of interface they have to learn. One implementation pays back across N call sites and M tests.

### Locality
What maintainers get from depth. Change, bugs, knowledge, and verification concentrate at one place rather than spreading across callers. Fix once, fixed everywhere.

---

## Principles

### Depth is a property of the interface, not the implementation
A deep module can be internally composed of small, mockable, swappable parts — they just aren't part of the interface. A module can have **internal seams** (private to its implementation, used by its own tests) as well as the **external seam** at its interface.

### The deletion test
Imagine deleting the module. If complexity vanishes, the module wasn't hiding anything (it was a pass-through). If complexity reappears across N callers, the module was earning its keep. Apply this to anything that looks shallow.

### The interface is the test surface
Callers and tests cross the same seam. If you want to test *past* the interface, the module is probably the wrong shape. Tests at the interface survive internal refactors; tests past the interface break on every implementation change.

### One adapter means a hypothetical seam. Two adapters means a real one
Don't introduce a port unless something actually varies across it. A single-adapter seam is just indirection. The typical justification for a real seam: production adapter + test adapter.

### Replace, don't layer (testing)
When a shallow module is folded into a deep one, the old unit tests on the shallow piece become waste — delete them. Write new tests at the deepened interface. Don't keep both layers of tests "to be safe" — they pull in opposite directions on the next refactor.

---

## Relationships

- A **Module** has exactly one **Interface** (the surface it presents to callers and tests).
- **Depth** is a property of a **Module**, measured against its **Interface**.
- A **Seam** is where a **Module**'s **Interface** lives.
- An **Adapter** sits at a **Seam** and satisfies the **Interface**.
- **Depth** produces **Leverage** for callers and **Locality** for maintainers.

---

## Rejected framings

These come up often and weaken the conversation. Reject them when they appear:

| Framing | Why it's rejected |
|---|---|
| **Depth as ratio of impl-lines to interface-lines** (Ousterhout's original) | Rewards padding the implementation. We use depth-as-leverage instead. |
| **"Interface" = the TypeScript `interface` keyword** | Too narrow. Interface here includes every fact a caller must know — invariants, ordering, error modes, config. |
| **"Boundary"** | Overloaded with DDD's bounded context. Say **seam** or **interface**. |
| **"Service"** | Carries SOA / microservice connotations. Say **module**. |
| **"Component"** | Carries UI-framework connotations. Say **module**. |
| **Every interface needs a port and adapter** | One adapter = hypothetical seam. Don't add a port until two adapters are justified. |

---

## Quick reference card

When proposing an architectural change, every sentence should be expressible in these terms:

- "This **module** is **shallow** — its **interface** is nearly as complex as its **implementation**. Apply the **deletion test**: would deleting it concentrate complexity, or just push it onto the N callers?"
- "Put the **seam** at the **module**'s external **interface**. Two **adapters**: production (HTTP) and test (in-memory). The **deep module** owns the logic; transport is injected."
- "These tests sit *past* the **interface** — they assert on internal state. Replace them with tests at the **interface** so they survive refactors."

If a sentence is *classifying* parts of the system as "services," "components," or "boundaries" — rewrite it. (Mentioning a third party as "the Stripe service" or referring to "across the network boundary" descriptively is fine. The discipline is about classifying *your own* parts in this skill's vocabulary, not policing every word you use.)
