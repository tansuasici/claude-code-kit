# Workflow & Planning

## Task Lifecycle

```text
Receive Task → Understand → Research → Plan → Confirm → Implement → Verify → Done
```

Every task follows this flow. Never skip steps.

---

## Goal-Driven Task Reframing

Imperative tasks ("fix the bug", "add validation", "refactor X") are ambiguous in two directions: it's unclear what counts as *done*, and it's unclear what to do *first*. Before researching or planning, restate the request as a **verifiable goal** — something whose completion can be checked deterministically.

This complements `## Verification (Mandatory Order)` in `CLAUDE.md`: verification answers *"is the change correct after we built it?"*; goal-driven reframing answers *"what would a correct change even look like?"* before any code is written. Together they bracket the lifecycle.

Inspired by [karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) — *transform tasks into verifiable goals*.

### The transformation table

When the user gives you an imperative, restate it as a verifiable goal before doing anything else:

| User says | Restate as |
|---|---|
| "Add validation to the signup form" | "Write failing tests for the invalid-input cases (empty email, short password, malformed phone, duplicate username). Make the form behavior cause them to pass." |
| "Fix the bug where users can't reset their password" | "Write a regression test that reproduces the failure on `main`. Make the fix turn it green. Keep the test in the suite." |
| "Refactor the `OrderService` to be cleaner" | "Confirm the current test suite passes. Apply the refactor. Confirm the same suite still passes — same inputs, same outputs, no new assertions added." |
| "Make the dashboard faster" | "Write a measurement: page render to interactive on the slowest dashboard route, on the same hardware, same dataset. Beat that number by X% in the same script." |
| "Improve the error messages" | "Pick the top N error sites by frequency (from logs / sentry). For each, write a test asserting the new message shape. Make them pass." |
| "Document the API" | "List every public endpoint. Generate an OpenAPI doc / Markdown page that covers them. Verify by curl'ing each documented example and matching the response shape." |
| "Clean up the codebase" | **Push back.** This is not a goal; it's a sentiment. Ask the user to point at the specific smell, file, or pattern they want addressed, and then restate that. |

### How to apply

1. After reading the request and **before** loading additional context, write the restated goal in your reply — one short paragraph.
2. If a verifiable form genuinely does not exist (pure exploration, design review, advisory), say so explicitly and continue without inventing one.
3. If the restated goal is ambiguous or seems wrong, ask **one** clarifying question before proceeding. Don't ladder up clarifications — pick the highest-impact one.
4. The restated goal becomes the **acceptance line** in `tasks/todo.md` if you go on to write a plan (see "Plan Template" below).

### Why this matters

- It surfaces the test/measurement up front, so the rest of the work has a target.
- It deflects sentiment-shaped requests ("make it cleaner") before they balloon into scope drift.
- It makes the *end* of the task agree with the *start* of the task — `stop-gate.sh` checks verification; this section checks intent.

This is a prompt-side rule (no hook enforces it). The reminder is in `CLAUDE.md → Plan First`; for a deterministic regression scenario covering the reframing behavior, see `bench/scenarios/` (KitBench).

---

## Separate Research from Implementation

**This is one of the most impactful practices.** When research and implementation happen in the same context, the agent accumulates irrelevant details from alternatives it explored but didn't choose.

### The Problem

```text
Bad:  "Build an auth system"
      → Agent researches JWT vs sessions vs OAuth vs passkeys
      → Context is now full of implementation details for ALL options
      → By the time it implements JWT, it's confused by OAuth details
```

### The Solution

Split into two clean phases:

**Research Phase** (separate context)
- Explore options, read docs, analyze tradeoffs
- Output: a concise summary of the chosen approach with specific details
- Use a subagent (Explore or Plan) so research doesn't pollute main context

**Implementation Phase** (clean context)
- Start with the research summary as input, not the full research
- Agent has only the information it needs to build the chosen solution
- No leftover context from rejected alternatives

### In Practice

```text
Good: 1. Subagent researches auth options → returns "Use JWT with bcrypt-12,
         refresh token rotation, 7-day expiry, httpOnly cookies"
      2. Main agent implements ONLY that specification
```

### When You Already Know the Approach

If you know what you want, be maximally specific upfront:

```text
Best: "Implement JWT authentication with bcrypt-12 password hashing,
       refresh token rotation with 7-day expiry, stored in httpOnly cookies,
       using jose library for token operations"
```

The more specific the instruction, the less the agent needs to research, and the better the implementation will be.

---

## When to Write a Plan

Write a plan to `tasks/todo.md` when:
- Task touches 3+ files
- Architectural decision is needed
- New dependency or tool is introduced
- Workflow or build system changes
- You're unsure about the approach

For small, isolated changes (typo fix, single-function edit): just do it.

---

## Plan Template

Copy this into `tasks/todo.md`:

```markdown
## Task: [Short title]

**Goal**: [1 sentence — what does "done" look like?]

**Context**: [Why is this needed? Link to issue/discussion if relevant]

### Approach
1. [Step 1]
2. [Step 2]
3. [Step 3]

### Files to Touch
- `path/to/file.ts` — [what changes]
- `path/to/file.ts` — [what changes]

### Open Questions
- [Anything unclear that needs confirmation?]

### Risks
- [What could go wrong?]

### Not Now
- [Things noticed but out of scope]
```

---

## Feature Spec Folders (Optional)

For multi-file tasks or features that require significant planning, create a timestamped spec folder instead of (or alongside) `tasks/todo.md`:

```text
tasks/specs/
  2026-04-05-user-auth/
    plan.md          # Implementation plan (what we build)
    shape.md         # Decisions and context from planning
    references.md    # Pointers to similar code, docs, examples
```

### When to use spec folders

- Multi-session features that need persistent context
- Tasks where planning decisions should be preserved for future reference
- Features with significant research or tradeoff analysis

### When NOT to use spec folders

- Simple tasks that fit in `tasks/todo.md`
- Bug fixes or single-file changes
- Tasks that will be completed in one session

Spec folders survive sessions and serve as handoff context. A new session can read the spec folder to understand what was planned and why.

---

## Mid-Task Recovery

If something goes sideways:

1. **STOP** — don't push through
2. Re-read the original goal
3. Check if scope has drifted
4. Update the plan in `tasks/todo.md`
5. Get confirmation before continuing

The most common failure mode is scope creep disguised as "while I'm here."

---

## Session Strategy

### One Session Per Contract (recommended)

Long-running sessions (24+ hours, many tasks) degrade over time because unrelated context from earlier tasks pollutes later ones. The agent starts making assumptions based on code it saw 3 tasks ago.

**Instead:** Start a new session for each task contract.

```text
Session 1: CONTRACT_auth.md     → implements auth     → ends
Session 2: CONTRACT_uploads.md  → implements uploads  → ends
Session 3: CONTRACT_search.md   → implements search   → ends
```

Each session reads only:
1. `CODEBASE_MAP.md` + `CLAUDE.project.md` (project awareness — Tier 1)
2. `tasks/lessons/_index.md` → `## Top Rules` section only (Tier 3, on-demand). Individual lesson files in `tasks/lessons/` loaded only when relevant
3. Its own contract file (task scope)
4. The specific source files it needs to edit

**Result:** Clean context, no cross-contamination, deterministic scope.

### When Long Sessions Are OK

- Exploratory work where you're interactively guiding the agent
- Debugging a single complex issue with many layers
- Sessions where YOU are the orchestrator (you manage the context)

### Orchestration Layer

For automated multi-contract workflows:

```text
Orchestrator (you or a script)
  ├── Generates CONTRACT_1.md
  ├── Starts Session 1 → completes → checks contract
  ├── Generates CONTRACT_2.md (may depend on 1's output)
  ├── Starts Session 2 → completes → checks contract
  └── ... continues until all contracts fulfilled
```

This can be as simple as a shell script that:
1. Creates a contract file
2. Runs `claude --print "Complete the contract in tasks/CONTRACT_X.md"`
3. Verifies the contract criteria
4. Repeats for the next contract

---

## PR / Commit Workflow

### Commit Messages

```text
<type>: <short description>

<optional body — why, not what>
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`, `ci`, `build`, `style`

Good:
```text
feat: add rate limiting to /api/upload

Prevents abuse from unauthenticated clients.
Limit: 10 req/min per IP.
```

Bad:
```text
update stuff
fix things
WIP
```

### PR Checklist

Before marking a task done:
- [ ] All changes match the original plan
- [ ] No unrelated changes snuck in
- [ ] Typecheck passes
- [ ] Lint passes
- [ ] Tests pass
- [ ] Smoke tested (manually verified real behavior)
- [ ] `tasks/todo.md` updated (task marked done or removed)

---

## Scope Control

### What "scope discipline" means in practice

| Situation | Do | Don't |
|-----------|------|-------|
| See a typo in an unrelated file | Log it in Not Now | Fix it now |
| Function could be cleaner | Log it in Not Now | Refactor it |
| Test is flaky but unrelated | Log it in Not Now | Debug it |
| Dependency could be updated | Log it in Not Now | Update it |
| Better pattern exists for old code | Log it in Not Now | Rewrite it |

### The "Not Now" List

In `tasks/todo.md`, keep a `## Not Now` section:

```markdown
## Not Now
- [ ] `src/utils/format.ts` has a potential timezone bug
- [ ] `package.json` — lodash could be replaced with native methods
- [ ] Auth middleware doesn't handle token refresh edge case
```

These get addressed in dedicated cleanup sessions, not mid-feature.
