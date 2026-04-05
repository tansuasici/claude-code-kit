---
name: ship
description: Full deployment pipeline — tests, coverage audit, CHANGELOG generation, bisectable commits, and PR creation
user-invocable: true
---

# Ship

## When to Use

Invoke with `/ship` when:

- Feature is complete and ready for merge
- All local verification has passed
- You want an automated ship pipeline instead of manual steps
- Preparing a clean, bisectable PR from a feature branch

## Process

### Phase 1: Pre-flight Checks

Before anything else, verify readiness:

1. **Working tree clean** — no uncommitted changes (stash or commit first)
2. **On a feature branch** — never ship directly from main/master
3. **Base branch up to date** — rebase or merge latest main
4. **Run full verification suite** in order:
   - Typecheck (`tsc`, `mypy`, `go vet`, `cargo check`, etc.)
   - Lint (project's configured linter)
   - Tests (full suite, not just changed files)
   - Build (ensure production build succeeds)

If any check fails, stop and report. Do not proceed with a failing pipeline.

### Phase 2: Coverage Audit

Trace new/changed code paths and verify test coverage:

1. **Identify changed files** — `git diff main...HEAD --name-only`
2. **Trace new code paths** — new functions, endpoints, event handlers, UI flows
3. **Check each path has tests** — search for test files that exercise the new code
4. **Report untested paths** — ask user whether to write tests or skip

```markdown
### Coverage Audit
| New Code Path | Test Coverage | Status |
|---------------|--------------|--------|
| POST /api/users | test/api/users.test.ts:45 | Covered |
| handleUpload() | — | UNTESTED |
```

If critical paths are untested, ask the user: "Write tests now or ship without?"

### Phase 3: Commit Hygiene

Ensure commits are clean and bisectable:

1. **Review commit history** — `git log main..HEAD --oneline`
2. **Check each commit**:
   - Does it have a conventional message? (`feat:`, `fix:`, `refactor:`, etc.)
   - Is it atomic? (one logical change per commit)
   - Does each commit build independently?
3. **If messy** — suggest interactive rebase to squash/reorder (with user approval)
4. **Never force-push** without explicit user consent

### Phase 4: CHANGELOG Generation

Generate or update CHANGELOG from commit history:

1. **Read existing CHANGELOG.md** (if present)
2. **Categorize commits** since last release:
   - Features (`feat:`)
   - Bug Fixes (`fix:`)
   - Breaking Changes (`BREAKING CHANGE:`)
   - Other (refactor, perf, docs)
3. **Draft entry** with human-readable descriptions (not raw commit messages)
4. **Present to user** for review before writing

```markdown
## [Unreleased]

### Features
- Add user search with full-text filtering (#45)

### Bug Fixes
- Fix timezone handling in export CSV (#42)
```

### Phase 5: Version Bump (if applicable)

If the project uses semantic versioning:

- **PATCH** — bug fixes only → auto-suggest
- **MINOR** — new features, no breaking changes → auto-suggest
- **MAJOR** — breaking changes → always ask user
- Update `VERSION`, `package.json`, `pyproject.toml`, or equivalent

### Phase 6: PR Creation

Create a clean pull request:

1. **Push branch** to remote (with `-u` flag)
2. **Generate PR title** — short, descriptive (&lt;70 chars)
3. **Generate PR body**:
   - Summary of changes (from CHANGELOG)
   - Test plan (what was verified)
   - Coverage audit results
   - Breaking changes (if any)
   - Screenshots (if UI changes, ask user to attach)
4. **Create PR** via `gh pr create`
5. **Report PR URL** to user

## Output Format

```markdown
# Ship Report

## Pre-flight
- [x] Clean working tree
- [x] Feature branch: feat/user-search
- [x] Base branch up to date
- [x] Typecheck: passed
- [x] Lint: passed
- [x] Tests: 142 passed, 0 failed
- [x] Build: succeeded

## Coverage Audit
| Path | Coverage | Status |
|------|----------|--------|
| ... | ... | ... |

## Commits (N total)
1. feat: add search endpoint
2. feat: add search UI component
3. test: add search integration tests

## CHANGELOG
[Draft entry]

## PR
- URL: https://github.com/org/repo/pull/123
- Title: feat: add user search
- Base: main ← feat/user-search
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Small change, no review needed" | Small changes cause production outages too. Every change gets the same pipeline. |
| "I'll add tests after merging" | Post-merge tests never get written. Untested code stays untested. |
| "CI will catch it" | CI catches what tests check. No tests = nothing to catch. CI is not magic. |
| "It's just a config change" | Config changes can take down production faster than code changes. Verify. |
| "The deadline is tight, skip coverage audit" | Shipping broken code creates more work than the time saved by skipping checks. |

## Notes

- This skill automates the ship process but always asks for user confirmation on judgment calls (version bumps, untested paths, commit squashing)
- Auto-fix mechanical issues (commit message typos), ask for judgment calls (MAJOR version bump)
- If the project has CI/CD, this skill prepares the PR — CI handles the rest
- Never force-push or merge without explicit user approval
