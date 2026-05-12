---
name: dead-code-audit
description: Detects unused code including unreferenced functions, dead imports, orphan files, and unreachable branches
user-invocable: true
---

# Dead Code Audit

## Kit Context

Before starting this skill, ensure you have completed session boot:
1. Read `CODEBASE_MAP.md` for project understanding
2. Read `CLAUDE.project.md` if it exists for project-specific rules
3. Read `tasks/lessons/_index.md` for accumulated corrections (Top Rules + index)

If any of these haven't been read in this session, read them now before proceeding.


## When to Use

Invoke with `/dead-code-audit` when:

- Codebase has grown organically and likely contains unused code
- After a major feature removal or refactoring
- Before a codebase migration to minimize what gets carried over
- During tech debt reduction sprints
- Preparing for a code quality review or due diligence

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

### Phase 1: Scope & Inventory

1. Identify the project's source directories (skip node_modules, vendor, build output)
2. Build a list of all exported symbols: functions, classes, types, constants, components
3. Note the project's module system: ES modules, CommonJS, Python imports, Go packages, etc.

### Phase 2: Reference Analysis

For each exported symbol, search for references across the entire project:

**Unreferenced Exports**
- Functions/methods defined but never called
- Classes/types defined but never instantiated or referenced
- Constants defined but never used
- Components defined but never rendered

**Dead Imports**
- Imported symbols that are never used in the importing file
- Entire modules imported but no symbols used
- Type-only imports in runtime code (where applicable)

**Orphan Files**
- Files not imported by any other file
- Test files for code that no longer exists
- Config files for removed features
- Migration files for rolled-back changes

**Unreachable Code**
- Code after unconditional return/throw/break
- Branches that can never be true (constant conditions)
- Feature-flagged code where the flag is permanently off
- Catch blocks for exceptions that are never thrown

### Phase 3: False Positive Filtering

Before reporting, verify each finding is truly dead:

- **Entry points**: main files, CLI handlers, server routes, event handlers — these won't be imported
- **Dynamic references**: string-based imports, reflection, registry patterns, dependency injection
- **Framework conventions**: lifecycle hooks, decorators, magic methods that are called by the framework
- **Re-exports**: barrel files (index.ts/js, `__init__.py`) that re-export for public API
- **Config-wired**: symbols registered in config files, plugin systems, or service containers
- **Test utilities**: helpers only used in test files (search test directories too)
- **Type-only usage**: types/interfaces used only in type annotations

### Phase 4: Impact Assessment

For confirmed dead code, assess:

- Lines of dead code (absolute and percentage of codebase)
- Maintenance burden (dead code with dependencies that block upgrades)
- Confusion risk (dead code that looks similar to active code)

## Output Format

```markdown
# Dead Code Audit Report

## Summary
- Total dead code: ~N lines across M files
- Orphan files: N
- Unused exports: N
- Dead imports: N

## Orphan Files (no importers)
| File | Lines | Last Modified | Confidence |
|------|-------|---------------|------------|
| path/to/file.ts | 150 | 2024-01-15 | High |

## Unused Exports
| Symbol | Defined In | Type | Confidence |
|--------|-----------|------|------------|
| processOrder | services/order.ts:45 | function | High |

## Dead Imports
| File | Unused Import | Line |
|------|--------------|------|
| handlers/user.ts | formatDate | 3 |

## Unreachable Code
| File | Lines | Reason |
|------|-------|--------|
| utils/parser.ts | 120-135 | After unconditional return on line 119 |

## Safe to Remove (High Confidence)
[List of items safe to remove immediately]

## Needs Verification (Medium Confidence)
[List of items that might have dynamic references]

## Removal Impact
- Estimated lines removable: N
- Files deletable: N
- Dependencies unlockable: [packages only used by dead code]
```

## Report Guidelines

- Use tables for structured findings — they're scannable and diffable
- Include file paths with line numbers (`file.ts:42`) for every finding
- Separate findings by severity: Critical > Major > Minor
- End with actionable recommendations, not just observations
- If no issues found in a category, state it explicitly — don't omit the section


## Notes

- Confidence levels: **High** = no references found anywhere; **Medium** = might have dynamic/config references
- For removal, use the `dead-code-remover` agent which handles safe deletion with verification
- This audit is read-only — it identifies dead code but does not remove it
- "Exported != Used" — a symbol exported from a file is only alive if something imports and uses it
