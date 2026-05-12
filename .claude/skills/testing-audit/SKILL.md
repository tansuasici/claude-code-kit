---
name: testing-audit
description: Audits test suite for coverage gaps, test quality, flaky tests, and testing strategy alignment
user-invocable: true
---

# Testing Audit

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

### Phase 1: Test Inventory

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
- Are there tests that always pass? (no real assertions, tautological checks)
- Are there tests that test the framework instead of the application?
- Do integration tests actually test integration? (or are they unit tests with extra setup)

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

## Output Format

```markdown
# Testing Audit Report

## Test Inventory
| Category | Count | Framework | Status |
|----------|-------|-----------|--------|
| Unit     | N     | Jest      | ...    |
| Integration | N  | ...       | ...    |
| E2E      | N     | ...       | ...    |

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
