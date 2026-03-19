---
name: project-health-report
description: Generates a comprehensive project health report covering code quality, architecture, testing, dependencies, and documentation
user-invocable: true
---

# Project Health Report

## When to Use

Invoke with `/project-health-report` when:

- Due diligence assessment of a codebase (acquisition, handoff, audit)
- Periodic project health check (quarterly review)
- New team lead onboarding to assess project state
- Planning a major initiative and need to understand the baseline
- Stakeholder reporting on technical health

## Process

### Phase 1: Project Overview

Gather basic project information:

1. **Tech stack** — languages, frameworks, databases, infrastructure
2. **Project size** — lines of code, number of files, number of modules
3. **Age & activity** — git history depth, commit frequency, contributor count
4. **Build & deploy** — build system, CI/CD pipeline, deployment targets

### Phase 2: Multi-Dimensional Assessment

Run a condensed version of each specialized audit:

**Code Quality** (from `/code-quality-audit`)
- Top 3-5 code smell categories
- Error handling consistency
- Naming and readability assessment
- Overall maintainability score

**Architecture** (from `/architecture-review`)
- Architectural pattern identification
- SOLID compliance summary
- Module coupling assessment
- Scalability concerns

**Testing** (from `/testing-audit`)
- Test coverage level (estimated from test file presence and density)
- Test quality assessment
- Testing strategy gaps
- CI integration status

**Dependencies** (from `/dependency-audit`)
- Dependency count and freshness
- Known vulnerability count
- License compatibility status
- Bloat/redundancy issues

**Documentation** (from `/documentation-audit`)
- README quality
- API documentation coverage
- Inline documentation quality
- Doc-code sync status

**Performance** (from `/performance-audit`)
- Obvious bottleneck patterns
- Resource management issues
- Caching strategy assessment

### Phase 3: Risk Assessment

Identify project-level risks:

- **Bus factor** — how many people understand the critical paths?
- **Technical debt** — accumulated shortcuts and workarounds
- **Dependency risk** — critical dependencies that are unmaintained or vulnerable
- **Scalability risk** — architectural limits that will hit at growth
- **Security risk** — vulnerability surface area

### Phase 4: Scoring

Rate each dimension on a 5-point scale:

| Score | Meaning |
|-------|---------|
| 5 | Excellent — exemplary practices |
| 4 | Good — solid with minor issues |
| 3 | Fair — functional but has notable gaps |
| 2 | Poor — significant issues affecting development |
| 1 | Critical — fundamental problems requiring immediate attention |

## Output Format

```markdown
# Project Health Report

## Project Overview
| Attribute | Value |
|-----------|-------|
| Tech Stack | [languages, frameworks] |
| Size | [~N lines, M files] |
| Age | [first commit date] |
| Contributors | [N active] |

## Health Dashboard

| Dimension | Score | Status | Key Finding |
|-----------|-------|--------|-------------|
| Code Quality | N/5 | 🟢/🟡/🔴 | ... |
| Architecture | N/5 | 🟢/🟡/🔴 | ... |
| Testing | N/5 | 🟢/🟡/🔴 | ... |
| Dependencies | N/5 | 🟢/🟡/🔴 | ... |
| Documentation | N/5 | 🟢/🟡/🔴 | ... |
| Performance | N/5 | 🟢/🟡/🔴 | ... |
| **Overall** | **N/5** | **🟢/🟡/🔴** | |

## Top Risks
1. [Risk + impact + likelihood]
2. ...
3. ...

## Top Recommendations
### Immediate (this week)
1. ...

### Short-term (this month)
1. ...

### Long-term (this quarter)
1. ...

## Detailed Findings

### Code Quality
[Summary of findings, top issues]

### Architecture
[Summary of findings, structural concerns]

### Testing
[Summary of findings, coverage gaps]

### Dependencies
[Summary of findings, update priorities]

### Documentation
[Summary of findings, gaps]

### Performance
[Summary of findings, bottlenecks]

## Conclusion
[1-2 paragraph executive summary: overall health, biggest risk, top priority action]
```

## Notes

- This is a breadth-first report — for depth on any dimension, use the specialized audit skill
- Scores are relative assessments, not absolute metrics — a 3/5 for a startup MVP has different implications than for enterprise software
- The report is a snapshot — recommend periodic re-assessment (quarterly for active projects)
- For due diligence, combine this report with manual code review of critical paths
