---
name: refactoring-guide
description: Provides Fowler-based refactoring recommendations with specific techniques, risk assessment, and step-by-step execution plans
user-invocable: true
---

# Refactoring Guide

## When to Use

Invoke with `/refactoring-guide` when:

- Code smells have been identified and need systematic fixes
- A module has grown unwieldy and needs restructuring
- Preparing for a feature that requires cleaner foundations
- After a `/code-quality-audit` to get actionable refactoring steps
- Technical debt needs to be paid down incrementally

## Process

### Phase 1: Assess Current State

1. Read the target code thoroughly — understand what it does before changing how it does it
2. Identify existing tests — refactoring without tests is dangerous
3. Map dependencies — what depends on this code? What does it depend on?
4. Check for active development — avoid refactoring code with open PRs or in-progress features

### Phase 2: Identify Refactoring Opportunities

Map code smells to Fowler's refactoring catalog:

**Extract Techniques** (breaking things apart)
| Smell | Refactoring | When |
|-------|-------------|------|
| Long function | Extract Function | Function >30 lines or does multiple things |
| Large class | Extract Class | Class has multiple distinct responsibilities |
| Feature envy | Move Function | Method uses another object's data more than its own |
| Data clumps | Introduce Parameter Object | Same group of parameters passed together |
| Primitive obsession | Replace Primitive with Object | Primitive carries domain meaning (email, money, ID) |

**Simplify Techniques** (reducing complexity)
| Smell | Refactoring | When |
|-------|-------------|------|
| Nested conditionals | Replace Nested Conditional with Guard Clauses | Deep nesting with early-exit cases |
| Switch/type code | Replace Conditional with Polymorphism | Switch on type that grows with each feature |
| Temp variables | Replace Temp with Query | Temp only assigned once and used in expression |
| Flag arguments | Remove Flag Argument | Boolean parameter changes function behavior |
| Speculative generality | Remove Dead Code / Collapse Hierarchy | Abstractions never used by multiple implementations |

**Reorganize Techniques** (improving structure)
| Smell | Refactoring | When |
|-------|-------------|------|
| Shotgun surgery | Move/Inline Function | Single change requires editing many classes |
| Divergent change | Split Phase / Extract Class | One class changed for multiple different reasons |
| Middle man | Remove Middle Man | Class delegates everything without adding value |
| Insider trading | Encapsulate Collection / Hide Delegate | Modules share too much internal knowledge |

### Phase 3: Risk Assessment

For each proposed refactoring:

- **Risk level**: Low (rename, extract) / Medium (restructure, move) / High (change interface, split module)
- **Test coverage**: Is the code covered? Can we add tests first?
- **Blast radius**: How many files/modules are affected?
- **Reversibility**: Can this be undone easily?
- **Incremental**: Can this be done in small, individually-safe steps?

### Phase 4: Execution Plan

For each approved refactoring, provide:

1. **Pre-conditions** — tests to write or verify first
2. **Steps** — atomic, individually-committable steps
3. **Verification** — how to confirm each step didn't break anything
4. **Post-conditions** — the expected state after completion

## Output Format

```markdown
# Refactoring Guide

## Target
[Module/file being refactored and why]

## Current Issues
1. [Smell] in [location] — [impact]

## Proposed Refactorings

### 1. [Refactoring Name] — [Target]
- **Technique**: [Fowler catalog name]
- **Risk**: Low/Medium/High
- **Blast radius**: N files
- **Pre-condition**: [Tests needed]

**Steps:**
1. [Atomic step]
2. [Atomic step]
3. Run tests → verify green

### 2. ...

## Execution Order
[Ordered list with dependencies noted]

## Safety Checklist
- [ ] All existing tests pass before starting
- [ ] Each step is committed separately
- [ ] Tests run after each step
- [ ] No behavior changes (refactoring only)
- [ ] Typecheck passes after each step
```

## Notes

- Refactoring means changing structure without changing behavior — if behavior changes, it's a rewrite
- Always ensure test coverage before refactoring; if tests are missing, write them first
- Prefer small, incremental refactorings over big-bang rewrites
- Each refactoring step should be committable and deployable on its own
