---
name: code-quality-audit
description: Audits codebase for code smells, error handling gaps, and maintainability issues with actionable fix recommendations
user-invocable: true
---

# Code Quality Audit

## Kit Context

Before starting this skill, ensure you have completed session boot:
1. Read `CODEBASE_MAP.md` for project understanding
2. Read `CLAUDE.project.md` if it exists for project-specific rules
3. Read `tasks/lessons/_index.md` for accumulated corrections (Top Rules + index)

If any of these haven't been read in this session, read them now before proceeding.


## When to Use

Invoke with `/code-quality-audit` when:

- Reviewing a codebase for code smells before a refactoring sprint
- Onboarding to a new project and assessing code health
- Preparing for a code review or due diligence assessment
- After rapid development to identify accumulated technical debt

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

### Phase 1: Scope

Determine audit scope:

1. If the user specifies files/directories, audit those
2. Otherwise, identify key source directories by reading project structure
3. Skip generated code, vendor directories, lock files, and build output

### Phase 2: Code Smells Analysis

Scan for these categories of code smells:

**Complexity Smells**
- Functions/methods exceeding 50 lines
- Deeply nested conditionals (3+ levels)
- Cyclomatic complexity > 10 per function
- God classes/modules with too many responsibilities
- Long parameter lists (5+ parameters)

**Duplication Smells**
- Repeated code blocks (3+ occurrences of similar logic)
- Copy-paste patterns with minor variations
- Parallel inheritance hierarchies
- Identical conditional structures across files

**Coupling Smells**
- Feature envy (method uses another class's data more than its own)
- Inappropriate intimacy (classes accessing each other's internals)
- Message chains (a.b.c.d.method())
- Circular dependencies between modules

**Naming Smells**
- Inconsistent naming conventions within the same codebase
- Overly abbreviated or cryptic names
- Boolean parameters without named arguments
- Generic names (data, info, manager, handler) without context

### Phase 3: Error Handling Analysis

Check for error handling issues:

- **Swallowed errors**: empty catch blocks, catch-and-log-only without re-throw
- **Over-catching**: catching base Exception/Error when specific types are appropriate
- **Missing error handling**: async operations without try/catch, unchecked return values
- **Inconsistent patterns**: mix of exceptions, error codes, Result types without clear convention
- **Error information loss**: re-throwing without preserving original stack trace
- **Missing cleanup**: no finally/defer/cleanup for resources in error paths
- **User-facing errors**: raw stack traces or internal errors exposed to users

### Phase 4: Maintainability Assessment

Evaluate:

- **Readability**: Can a new developer understand the code without external context?
- **Testability**: Can units be tested in isolation? Are dependencies injectable?
- **Changeability**: How many files need to change for a typical feature addition?
- **Consistency**: Are patterns applied uniformly across the codebase?

## Output Format

```markdown
# Code Quality Audit Report

## Executive Summary
[1-2 paragraphs: overall quality assessment, critical findings count]

## Critical Issues (Must Fix)
| # | Category | Location | Issue | Suggested Fix |
|---|----------|----------|-------|---------------|
| 1 | smell    | file:line | ...   | ...           |

## Major Issues (Should Fix)
| # | Category | Location | Issue | Suggested Fix |
|---|----------|----------|-------|---------------|

## Minor Issues (Consider)
| # | Category | Location | Issue | Suggested Fix |
|---|----------|----------|-------|---------------|

## Metrics
- Files analyzed: N
- Code smells found: N (critical/major/minor)
- Error handling gaps: N
- Estimated tech debt: low/medium/high

## Positive Patterns
[List well-implemented patterns worth preserving]
```

## Report Guidelines

- Use tables for structured findings — they're scannable and diffable
- Include file paths with line numbers (`file.ts:42`) for every finding
- Separate findings by severity: Critical > Major > Minor
- End with actionable recommendations, not just observations
- If no issues found in a category, state it explicitly — don't omit the section


## Notes

- This audit focuses on code-level quality, not architecture (see `/architecture-review`)
- Security issues should be flagged but detailed security review is separate (use security-reviewer agent)
- Adapt smell thresholds to the project's language conventions (e.g., functional languages may have longer functions)
