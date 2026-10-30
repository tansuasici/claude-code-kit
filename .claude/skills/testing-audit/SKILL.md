---
name: testing-audit
description: Audit the test suite for coverage gaps, test quality, flaky tests, and strategy alignment. Use when assessing test health before a release, or when tests feel weak, slow, or flaky.
user-invocable: true
---

# Testing Audit

## Core Rule

Distinguish test gaps from test churn. Report missing critical-path coverage and flaky tests separately; never recommend tests beyond reproducibility need.

## Kit Context

Before starting this skill, ensure you have completed session boot:
1. Read `CODEBASE_MAP.md` for project understanding
2. Read `CLAUDE.project.md` if it exists for project-specific rules
3. Read `tasks/lessons/_index.md` for accumulated corrections (Top Rules + index)

If any of these haven't been read in this session, read them now before proceeding.

## When to Use

Invoke with `/testing-audit` when:

- Test suite is unreliable or has frequent flaky tests
- Coverage numbers look good but bugs still slip through
- Planning a testing strategy improvement
- Reviewing test quality after rapid feature development
- Assessing confidence level before a major release

## Default Behavior

When the user asks to audit, scan, review, or "give me a report" for test coverage and quality, produce the full testing-audit report automatically using the Process and Output Format sections below. Do not require the user to specify fields.

Only modify files when the user explicitly requests implement / fix / apply / refactor. By default, this skill is **report-only**.

## Scope Rules

- Analyze ONLY the files and directories relevant to this skill's purpose
- Do not refactor, fix, or modify code — this is a read-only analysis unless explicitly stated otherwise
- Log unrelated issues found during analysis under `tasks/todo.md > ## Not Now`
- State every assumption explicitly before acting on it
- If the user specified a scope (files, directories, modules), respect it strictly

## Context Gathering

Before analysis, map the project:
1. Read project config (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, etc.)
2. Identify the tech stack, frameworks, and key dependencies
3. Map source directories — skip `node_modules`, `vendor`, `build`, `.next`, `dist`, `__pycache__`
4. Check for existing configurations relevant to this analysis (linters, formatters, CI configs)
5. If the user specified a scope, narrow to those files/directories only

## Process

### Phase 1: Inventory (first-pass leads)

This pass produces **candidates**, not findings. Treat counts as leads for deeper inspection in later phases. Do not report Phase 1 raw output as the final result.

Map the current test landscape:

1. **Find test files** — scan for test directories, `*.test.*`, `*.spec.*`, `*_test.*`, `test_*.*`
2. **Identify test framework** — Jest, Vitest, pytest, Go testing, JUnit, etc.
3. **Categorize tests** — unit, integration, e2e, snapshot, contract
4. **Check test config** — coverage thresholds, timeout settings, parallel execution

### Phase 2: Coverage Analysis

Assess what is and isn't tested:

**Structural Coverage**
- Which modules/directories have no tests at all?
- Which critical paths (auth, payment, data mutation) lack tests?
- Are edge cases covered? (empty input, boundary values, error paths)
- Are error/failure paths tested, not just happy paths?

**Meaningful Coverage**
- Do tests assert the right things? (behavior, not implementation)
- Are there tests that always pass? (no real assertions, tautological checks) — answer this with the falsification check below, not by impression
- Are there tests that test the framework instead of the application?
- Do integration tests actually test integration? (or are they unit tests with extra setup)

**Falsification check** — apply this to every test guarding a critical path. It needs no tooling:

For each test, name the single line of production code you would change to make that test fail. Then judge what you named:

1. **Cannot name one** — the test asserts nothing about behavior. Report it under Quality Issues → Must Fix.
2. **The line is a log call, or a field the test itself wrote and reads back** — the test is pinned to implementation, not behavior.
3. **The test would still pass if the function under test did nothing at all** — the test is decorative. Count these; the count goes in the report.

Reason about this from the source. Do not edit production code to try it, and do not run the suite against a stubbed function — this skill is report-only.

### Phase 3: Test Quality

Evaluate test code quality:

**Readability**
- Are test names descriptive? (describe what, when, and expected outcome)
- Is the Arrange-Act-Assert / Given-When-Then pattern followed?
- Are test utilities and helpers well-organized?

**Reliability**
- **Flaky tests**: tests dependent on timing, external services, or execution order
- **Test interdependence**: tests that fail when run individually but pass in suite (or vice versa)
- **Non-deterministic**: tests using random data, current time, or system state
- **Shared mutable state**: global variables modified across tests without reset

**Maintainability**
- **Over-mocking**: mocking so much that the test doesn't test real behavior
- **Under-mocking**: integration tests that hit real external services without sandboxing
- **Brittle assertions**: asserting exact strings, snapshots of entire objects, or implementation details
- **Test duplication**: same scenario tested multiple times in different files
- **Setup overhead**: tests requiring 50+ lines of setup for simple assertions

### Phase 4: Testing Strategy

Assess the overall testing strategy:

- **Test pyramid balance**: ratio of unit : integration : e2e tests
  - Too many e2e tests = slow, brittle feedback loop
  - Too few integration tests = false confidence from unit tests
- **Missing test types**: no contract tests for APIs, no smoke tests for deployment
- **CI integration**: are tests run on every PR? Is the feedback loop fast enough?
- **Test data management**: how is test data created and cleaned up?

### Phase 5: Mutation Score (optional — only if a mutation tool is already installed)

Phase 2's falsification check is read by eye. A mutation tool answers the same question with an exit code: it alters the production code in small ways and reports which alterations the suite failed to notice.

Run this phase **only if a mutation tool is already on PATH**. Do not install one, do not add it to the project's dependencies, and do not clone it. When it is absent the signal is **not measured** — which is not the same as healthy, and must not be reported as a pass.

This phase is also the one exception to the report-only default, so it is **opt-in**: it re-executes the test suite once per mutant and writes the tool's own scratch and metrics directories. Run it when the user asks for a mutation score. The default report states `not measured: not requested` and stops there.

When one is present:

1. **Require a clean tree.** `git status --porcelain` must be empty before the run. A run that is interrupted can leave a mutated copy of a source file behind, and on an already-dirty tree you cannot tell that copy from the user's own edits.
2. **Scope it to the modules Phase 2 flagged**, never the whole repo. Every mutant re-runs the suite, so a full pass costs minutes to hours — this is why mutation testing belongs in an on-demand audit and not in an edit-time hook.
3. **Check the tree again afterwards.** Anything beyond the tool's own scratch and metrics directories means the run left the tree dirty: restore it with `git checkout --` and report that as a finding.
4. **Report each survivor by `file:line`.** A surviving mutant names one missing assertion, which is actionable; a bare percentage is not. Score as `killed / (killed + survived)`.

Read the exit code rather than parsing stdout, and keep "nothing ran" distinct from "nothing survived":

| Outcome | What to report |
|---------|----------------|
| Every executed mutant killed | The suite notices the breaks it was given — but if nothing was executed, this is **not measured** |
| Baseline suite already failing | **Not measured.** A red suite cannot judge mutants; report the red suite as the finding |
| At least one mutant survived | Each survivor, by location, as a missing assertion |

`unclebob/mutator` (0BSD) is the tool this phase was written against. It covers Clojure, Java, Go, TypeScript, Rust and Python; it needs `crapper` installed or checked out beside it; it writes its snapshot under `.metrics/` and its workers under `target/`. It has **no C#/.NET support**, so on a .NET codebase this phase is always `not measured`.

## Output Format

```markdown
# Testing Audit Report

## Test Inventory
| Category | Count | Framework | Status |
|----------|-------|-----------|--------|
| Unit     | N     | Jest      | ...    |
| Integration | N  | ...       | ...    |
| E2E      | N     | ...       | ...    |

## Measured Signals
- Tests that would pass against a do-nothing implementation: N (Phase 2 falsification check)
- Mutation score: N% (killed/(killed+survived)) — or `not measured: [reason]`

## Coverage Gaps
### Untested Critical Paths
1. [module/feature] — [risk if untested]

### Weak Test Areas
1. [file:line] — [what's missing]

## Quality Issues
### Must Fix
- [issue + location + recommendation]

### Should Fix
- [issue + location + recommendation]

## Testing Strategy Assessment
- Pyramid balance: [top-heavy / balanced / bottom-heavy]
- Confidence level: [low / medium / high]
- Key risk: [single biggest testing risk]

## Recommendations
1. [Highest impact improvement]
2. ...
```

## Report Guidelines

- Use tables for structured findings — they're scannable and diffable
- Include file paths with line numbers (`file.ts:42`) for every finding
- Separate findings by severity: Critical > Major > Minor
- End with actionable recommendations, not just observations
- If no issues found in a category, state it explicitly — don't omit the section

## Notes

- If no tests exist, the output should focus on a recommended testing strategy rather than auditing
- Don't recommend 100% coverage — focus on critical path coverage
- Consider the project's risk tolerance and deployment frequency when making recommendations
- A signal you did not measure is reported as `not measured` with the reason. Never write `OK`, `passed` or `0 issues` for a check that did not run — the same rule the quality gate follows for `skipped`
- The falsification check and the mutation phase are the kit's reading of the heuristic in [unclebob/ub-mode](https://github.com/unclebob/ub-mode); the wording here is the kit's own
- Mutation testing belongs in this on-demand audit, not in `quality-gate.sh` — that hook runs on every edit under a short time limit, and a mutation run re-executes the suite once per mutant
