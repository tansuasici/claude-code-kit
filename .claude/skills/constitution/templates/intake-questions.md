# Intake Questions

These are the 5 questions `/constitution` asks when bootstrapping a brand-new `golden-principles.yaml`. Each answer shapes which library categories get proposed (and at what severity) in Phase 3.

Ask one at a time. Wait for the user to answer before continuing. Push back on vague answers with one specific follow-up; do not accept "we'll figure it out later" for any of these.

---

## 1. Type safety vs. velocity

> How strict do you want type safety? Pick one:
>
> - **Strict** — `any` is a build error; every boundary (HTTP, DB, env, FS) is schema-validated; the audit will surface every `JSON.parse` without a schema wrapper.
> - **Pragmatic** — `any` is allowed in internal helpers; boundaries are validated but in-flight types may be inferred; the audit flags `any` only in public exports.
> - **Lenient** — type safety is a target, not a gate; the audit flags only the most dangerous patterns (raw `JSON.parse` of network payloads).

**Maps to:** type-safety category. *Strict* → all type-safety principles proposed at `critical`. *Pragmatic* → `no-yolo-json-parse` at `critical`, others at `major`. *Lenient* → only `no-yolo-json-parse` at `critical`, drop the rest.

---

## 2. Architecture boundaries

> Does your codebase enforce a layer model (e.g. routes → services → repositories → DB) where direct cross-layer access is forbidden? Pick one:
>
> - **Yes, strictly** — handlers must never import DB clients; cross-feature imports must go through a public surface; a violation should fail review.
> - **Yes, loosely** — the layers exist but are convention-only; occasional shortcuts happen and that's fine.
> - **No / not yet** — the codebase is small enough that the question doesn't matter yet.

**Maps to:** architecture category. *Strictly* → all architecture principles at `critical`. *Loosely* → architecture principles at `major`. *No / not yet* → skip the architecture category entirely (don't propose anything; revisit later).

---

## 3. Testing discipline

> What's the testing posture? Pick one:
>
> - **Test-first** — every change ships with a regression test; coverage gaps are fixed, not waived.
> - **Tests-as-spec** — tests describe expected behaviour; coverage is checked but waivers exist for hard-to-test code paths.
> - **Smoke-test-only** — only the happy paths are tested; new features may ship without tests if the risk is low.

**Maps to:** testing category. *Test-first* → propose `no-skip-in-suites`, `no-fdescribe`, `assertion-density-floor` at `critical`. *Tests-as-spec* → same set at `major`. *Smoke-test-only* → skip this category (don't propose anything).

---

## 4. Shared utilities vs. local helpers

> Where do small utilities live? Pick one:
>
> - **Shared package** — debounce / throttle / clamp / deepClone are imported from a workspace `utils` package; hand-rolling them is a smell.
> - **Per-feature** — each feature owns its own helpers; duplication is preferred over coupling.
> - **Mixed / no policy** — both happen; we haven't decided.

**Maps to:** shared-utils category. *Shared package* → propose `prefer-shared-utils` at `major`. *Per-feature* → skip the category. *Mixed* → propose `prefer-shared-utils` at `minor` so the audit flags drift as awareness rather than failure.

---

## 5. Error handling shape

> How does error handling work today? Pick one:
>
> - **Typed errors at the boundary** — every external call returns a typed `Result` / `Either` / discriminated union; raw `throw` is reserved for programmer errors.
> - **Exceptions with global handler** — exceptions bubble up to a single boundary handler; everything in between can throw freely.
> - **Mixed / informal** — both happen depending on the file.

**Maps to:** error-handling category. *Typed errors* → propose `no-swallowed-catch`, `no-throw-non-error`, `result-or-throw-not-both` at `critical`. *Exceptions with global handler* → propose `no-swallowed-catch` at `critical`, others at `major`. *Mixed / informal* → propose `no-swallowed-catch` only, at `major`.

---

## After the answers

The skill prints a one-paragraph summary mapping the answers to the proposed category set, then continues to Phase 3 (Propose & Confirm). The user can still accept / edit / skip each individual principle in Phase 3 — the intake just shapes which ones surface in what order, with what severity.
