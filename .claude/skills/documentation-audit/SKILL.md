---
name: documentation-audit
description: Audits code documentation quality including inline comments, API docs, README completeness, and doc-code sync
user-invocable: true
---

# Documentation Audit

## When to Use

Invoke with `/documentation-audit` when:

- Assessing documentation quality for a project
- Preparing a project for open-source release
- Onboarding new team members and finding documentation gaps
- After major feature additions to ensure docs are updated
- Before a due diligence or code quality review

## Process

### Phase 1: Documentation Inventory

Catalog existing documentation:

1. **README** — Does it exist? Is it useful?
2. **API docs** — Inline docs, generated docs, API reference
3. **Architecture docs** — High-level design, system diagrams
4. **Inline comments** — Code-level documentation
5. **Examples** — Usage examples, tutorials, quickstart guides
6. **Changelog** — Version history, migration guides

### Phase 2: README Assessment

Evaluate the project README:

**Essential Sections**
- [ ] Project name and one-line description
- [ ] What the project does (not how it's built)
- [ ] Quick start / installation instructions
- [ ] Basic usage example
- [ ] Prerequisites and requirements

**Good-to-Have Sections**
- [ ] Configuration options
- [ ] API overview or link to full docs
- [ ] Contributing guidelines
- [ ] License
- [ ] Status badges (build, coverage, version)

**Quality Checks**
- Are instructions copy-pasteable? (no placeholder values without explanation)
- Are versions/requirements current?
- Does the quick start actually work?

### Phase 3: Inline Documentation

Audit code-level documentation:

**Public API Documentation**
- Are public functions/methods documented? (parameters, return values, exceptions)
- Are complex algorithms explained? (not what the code does, but why)
- Are non-obvious design decisions documented?
- Are edge cases and limitations noted?

**Comment Quality**
- **Useful comments**: explain WHY, not WHAT (the code says what)
- **Outdated comments**: comments that don't match the current code
- **Redundant comments**: comments that repeat what the code already says
- **TODO/FIXME/HACK**: are these tracked? Do they reference issues?
- **Commented-out code**: should be removed, not commented

**Anti-patterns**
- Functions with complex behavior but no documentation
- Public APIs without parameter descriptions
- Error codes/messages without explanation
- Magic numbers without explanation
- Regex patterns without explanation

### Phase 4: API Documentation

If the project exposes an API (REST, GraphQL, library):

- Are all endpoints/functions documented?
- Are request/response schemas documented?
- Are error responses documented?
- Are authentication requirements documented?
- Are rate limits and pagination documented?
- Is there an OpenAPI/Swagger spec (REST) or schema file (GraphQL)?
- Are examples provided for common use cases?

### Phase 5: Documentation-Code Sync

Check that docs match reality:

- Do documented APIs still exist? (no references to removed endpoints)
- Do documented config options match the actual config schema?
- Do code examples in docs actually compile/run?
- Are version references current?
- Do links in docs point to valid targets?

## Output Format

```markdown
# Documentation Audit Report

## Documentation Inventory
| Type | Exists | Quality | Notes |
|------|--------|---------|-------|
| README | ✅/❌ | Good/Fair/Poor | ... |
| API Docs | ✅/❌ | Good/Fair/Poor | ... |
| Inline Docs | ✅/❌ | Good/Fair/Poor | ... |
| Architecture | ✅/❌ | Good/Fair/Poor | ... |
| Examples | ✅/❌ | Good/Fair/Poor | ... |
| Changelog | ✅/❌ | Good/Fair/Poor | ... |

## Critical Gaps
1. [Undocumented public API / missing README section / outdated docs]

## Outdated Documentation
| Location | Issue | Current State |
|----------|-------|---------------|
| README line 45 | References removed config option | Option removed in v2.0 |

## Comment Quality Issues
| File | Line | Issue |
|------|------|-------|
| api/handler.ts | 23 | Comment contradicts code behavior |

## Recommendations
### Must Fix
1. ...

### Should Fix
1. ...

### Nice to Have
1. ...

## Documentation Score
[Overall: Poor / Fair / Good / Excellent]
[Key metric: % of public APIs documented]
```

## Notes

- Good documentation explains WHY, not WHAT — the code already says what
- Don't recommend documenting everything — focus on public APIs, complex logic, and non-obvious decisions
- Over-documentation is as bad as under-documentation — redundant comments become noise
- Consider the audience: library docs need more than internal app docs
