---
name: dependency-audit
description: Audits project dependencies for security vulnerabilities, outdated versions, license risks, and bloat
user-invocable: true
---

# Dependency Audit

## When to Use

Invoke with `/dependency-audit` when:

- Reviewing a project's dependency health before a release
- Investigating supply chain security concerns
- Planning a dependency update or migration
- Assessing technical debt from outdated packages
- Onboarding to a project and evaluating its dependency choices

## Process

### Phase 1: Inventory

Catalog all dependencies:

1. **Read dependency manifests** — `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `Gemfile`, `pom.xml`, `build.gradle`
2. **Separate categories** — production vs development dependencies
3. **Count totals** — direct dependencies, estimate transitive depth
4. **Identify lock file presence** — `package-lock.json`, `poetry.lock`, `go.sum`, `Cargo.lock`

### Phase 2: Version Health

Check currency of dependencies:

**Version Analysis**
- How many major versions behind are critical dependencies?
- Are there dependencies pinned to exact versions vs ranges?
- Are there conflicting version requirements?
- Are lock files committed and up to date?

**Deprecation Check**
- Are any dependencies officially deprecated?
- Are any dependencies archived/unmaintained (no commits in 12+ months)?
- Are there dependencies with known successors? (e.g., `request` → `got`/`node-fetch`)

### Phase 3: Security Assessment

Check for known vulnerabilities:

- **CVE database check**: known vulnerabilities in current versions
- **Dependency confusion risk**: private package names that could be squatted
- **Supply chain risks**: dependencies with very few maintainers, recent ownership changes
- **Post-install scripts**: dependencies that run arbitrary code on install
- **Excessive permissions**: dependencies that request unnecessary system access

Recommend running:
- `npm audit` / `yarn audit` (Node.js)
- `pip audit` / `safety check` (Python)
- `go vuln check` (Go)
- `cargo audit` (Rust)
- `bundle audit` (Ruby)

### Phase 4: License Compliance

Check license compatibility:

- List all dependency licenses
- Flag incompatible licenses for the project type:
  - **GPL** in a proprietary/MIT project (copyleft contamination)
  - **AGPL** in any non-AGPL project
  - **No license** (legally unusable)
  - **Custom/unknown licenses** (need legal review)
- Check for license changes between versions

### Phase 5: Bloat & Redundancy

Identify unnecessary weight:

- **Duplicate functionality**: multiple packages doing the same thing (e.g., `lodash` + `underscore`, `moment` + `date-fns`)
- **Oversized dependencies**: large packages used for one small feature
- **Dev dependencies in production**: test/build tools in production deps
- **Unused dependencies**: packages in manifest but not imported anywhere
- **Bundle impact** (web): packages that significantly increase bundle size

### Phase 6: Quality Signals

Evaluate dependency quality:

- **Popularity**: download counts, GitHub stars (not definitive but signals)
- **Maintenance**: recent releases, responsive issue handling
- **Test coverage**: does the dependency have its own tests?
- **TypeScript support**: type definitions available? (for TS projects)
- **Breaking change frequency**: how often do major versions land?

## Output Format

```markdown
# Dependency Audit Report

## Summary
- Total dependencies: N direct, ~N transitive
- Outdated: N (N major, N minor, N patch behind)
- Vulnerabilities: N (N critical, N high, N medium)
- License issues: N

## Security Vulnerabilities
| Package | Current | Fixed In | Severity | CVE |
|---------|---------|----------|----------|-----|
| lodash  | 4.17.15 | 4.17.21  | High     | CVE-2021-23337 |

## Outdated Dependencies
### Critical (2+ major versions behind)
| Package | Current | Latest | Risk |
|---------|---------|--------|------|

### Notable (1 major version behind)
| Package | Current | Latest | Breaking Changes |
|---------|---------|--------|-----------------|

## License Issues
| Package | License | Issue |
|---------|---------|-------|

## Redundancy & Bloat
| Issue | Packages | Recommendation |
|-------|----------|---------------|
| Duplicate utility | lodash + ramda | Consolidate to one |

## Recommendations
### Immediate (security)
1. ...

### Short-term (updates)
1. ...

### Long-term (replacements)
1. ...
```

## Notes

- This audit uses static analysis of manifest/lock files — run the recommended CLI audit tools for CVE verification
- License analysis is informational, not legal advice — consult legal for compliance decisions
- Don't recommend updating everything at once — prioritize security fixes, then major updates incrementally
