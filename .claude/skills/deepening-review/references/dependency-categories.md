# Dependency Categories

When a deepening candidate has external dependencies, the *category* of those dependencies determines how the deepened module gets tested across its seam, and whether a port-and-adapter pattern is justified.

Vocabulary: **Module / Interface / Seam / Adapter**. See [`agent_docs/architecture-language.md`](../../../../agent_docs/architecture-language.md).

---

## Category 1 — In-Process

**Definition**: Pure computation, in-memory state, no I/O, no clock, no randomness.

**Examples**: parsing, validation, formatting, pure business rules, immutable data transformations.

**Deepenable?** Always. Merge the modules, test through the new interface directly. No adapter needed.

**Test strategy**: Direct calls at the deepened module's interface. No mocks, no fakes, no setup. If you find yourself wanting a mock here, the module probably has a hidden Category 2/3/4 dependency you missed.

**Seam**: None at the module's external interface beyond the call signature itself.

---

## Category 2 — Local-Substitutable

**Definition**: Dependencies that have realistic local stand-ins which can run inside the test process.

**Examples**:
- Postgres → PGLite or `pg-mem` (in-process Postgres)
- Filesystem → `memfs` (in-memory FS)
- Redis → `ioredis-mock` or in-memory map
- Time → injectable clock with a fast-forward fake
- HTTP server → supertest with the real handler

**Deepenable?** Yes, **if the stand-in is good enough**. "Good enough" means: the stand-in fails for the same reasons the real thing fails. PGLite is good. A naive in-memory mock that doesn't enforce constraints is not.

**Test strategy**: Spin up the stand-in in the test suite. Call the deepened module's interface. The stand-in is part of the test fixture, not part of the module's interface. The module doesn't know it's not talking to the real thing.

**Seam**: **Internal** to the module. The module imports the substitutable resource directly. The seam is at the resource boundary — `pg.connect()` vs `pglite.connect()` — not at the module's external interface.

**When *not* to deepen**: if the stand-in is so different from production that bugs only surface in production. At that point treat it like Category 4.

---

## Category 3 — Remote but Owned (Ports & Adapters)

**Definition**: Your own services across a network boundary. You control both sides.

**Examples**: another microservice you own, an internal HTTP API, a queue you publish to and consume from, a gRPC service in your monorepo.

**Deepenable?** Yes, **with a port at the seam**. The deepened module owns the *logic*; the *transport* is an injected adapter.

**Test strategy**:
- Define a port (interface) at the seam
- Production adapter: HTTP/gRPC/queue client
- Test adapter: in-memory implementation that satisfies the same port
- Tests use the in-memory adapter; integration tests verify the HTTP adapter against the real remote

**Seam**: **External** — at the module's interface to the outside world.

**Justification check**: at least two adapters (production HTTP + test in-memory) is the minimum. If you only have one, you have a hypothetical seam — just indirection. Don't introduce the port until two adapters are real.

**Recommendation phrasing**: *"Define a port at the seam. Implement an HTTP adapter for production and an in-memory adapter for testing. The logic sits in one deep module even though it's deployed across a network."*

---

## Category 4 — True External (Mock)

**Definition**: Third-party services you don't control. You can't run them locally with full fidelity, and you don't want to during unit tests.

**Examples**: Stripe, Twilio, OpenAI, Auth0, S3 (sometimes), external partners' APIs.

**Deepenable?** Yes, but with discipline. The deepened module takes the external dependency as an injected port; tests provide a mock adapter.

**Test strategy**:
- Define a port for the external capability you actually use (not the entire third-party API)
- Production adapter: SDK or HTTP client wrapping the real service
- Test adapter: hand-written mock with the behaviours your module relies on
- **Contract test the production adapter** against the real service in a separate, slower test tier — this catches when the third party changes behaviour

**Seam**: **External** — at the module's interface, ideally narrower than the third-party API. Your port should expose only the slice of behaviour you depend on.

**Common mistake**: porting the entire third-party SDK shape. The port should reflect *your domain*, not theirs. "Charge a customer" is a port. `StripeChargeCreateParams` is not.

---

## Mixed Dependencies

A real module often has a mix. Apply the category-by-category rule:

- **Pure logic + Category 1 deps** → merge directly, test through interface
- **Pure logic + Category 2 deps** → use the stand-in, test through interface
- **Pure logic + Category 3 deps** → port at the seam, two adapters minimum
- **Pure logic + Category 4 deps** → port for the *capability you use*, mock + contract test
- **Multi-category** → categorize each dep, apply each rule. Don't unify everything behind one port "for consistency" — that hides the categorization that matters.

---

## Anti-Patterns

| Anti-pattern | Why it's bad |
|---|---|
| **One adapter is enough** | A single adapter behind a port is just indirection. The port costs design effort + a level of redirection in every call. Pay it only when two adapters justify it. |
| **Mock everything** | Category 1/2 deps don't need mocks. Mocking them produces tests that pass for the wrong reasons. |
| **Mock nothing** | Category 4 deps in unit tests = slow, flaky, expensive tests. Use the port. |
| **Port mirrors the third party** | The port should reflect *your* needs, not Stripe's API. A 50-method port is a sign the abstraction is at the wrong level. |
| **Port at the wrong seam** | If the port sits inside your module's logic instead of at its edge, you've created an internal seam masquerading as an external one. The interface is the test surface — port at the interface, not three layers deep. |

---

## Quick Decision Table

| Dependency | Category | Adapter? | Test strategy |
|---|---|---|---|
| Pure compute | 1 | No | Direct |
| Postgres (with PGLite) | 2 | No (internal seam only) | Stand-in in test fixture |
| Redis (with mock) | 2 | No | Stand-in |
| Internal microservice | 3 | Yes — port + 2 adapters | In-memory adapter for unit, HTTP for integration |
| Stripe / Twilio / OpenAI | 4 | Yes — capability port + mock | Mock for unit, contract test for production adapter |
| Filesystem | 2 (with `memfs`) | No | Stand-in |
| Time / clock | 1 or 2 (inject) | No | Fake clock |
| Random | 1 (inject seed) | No | Deterministic seed |
