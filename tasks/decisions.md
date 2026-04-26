# Architecture Decision Records

Track important technical decisions here so they don't get lost between sessions.

---

## Format

```markdown
### ADR-[number]: [Short title]
- **Date**: YYYY-MM-DD
- **Status**: proposed | accepted | rejected | superseded
- **Context**: [What problem are we solving? What constraint exists?]
- **Options**:
  - A) [Option] — Pros: ... / Cons: ...
  - B) [Option] — Pros: ... / Cons: ...
- **Decision**: [Which option and why]
- **Consequences**: [What changes as a result? Any risks?]
```

---

## Example

### ADR-001: Use Zod for request validation
- **Date**: 2026-03-01
- **Status**: accepted
- **Context**: API endpoints accept user input without validation. Need runtime validation with TypeScript type inference.
- **Options**:
  - A) Zod — Pros: TypeScript-first, small bundle, great DX / Cons: another dependency
  - B) Joi — Pros: mature, battle-tested / Cons: no TS inference, larger
  - C) Manual validation — Pros: no dependency / Cons: error-prone, verbose
- **Decision**: Zod (A). TypeScript inference eliminates duplicate type definitions. Small enough to justify the dependency.
- **Consequences**: All route handlers must validate input with Zod schemas. Schemas live in `src/schemas/`.

---

<!-- Add new decisions below this line -->

### ADR-002: Squash-only merge for kit and web repos
- **Date**: 2026-04-26
- **Status**: accepted
- **Context**: Past CHANGELOGs (v1.6.0–v1.7.2) showed every PR's bug-fix line *twice*. Each entry came from (1) the original `fix:`/`feat:` commit on the feature branch and (2) the merge commit GitHub creates on `--merge`, whose body auto-inherits the feature branch's HEAD commit subject. release-please's conventional-commits parser saw both and emitted two entries per PR.
- **Options**:
  - A) **Squash merge only** — single commit on `main` with PR title as subject. One changelog entry per PR. Loses intermediate branch commits (acceptable for this repo size).
  - B) **Rebase merge only** — replays each commit on `main` linearly. No merge commit pollution. But every "fix lint" / "address review" commit ends up in changelog separately.
  - C) **Keep merge + filter release-please** — config a regex to drop merge commits. Brittle, depends on release-please internals.
- **Decision**: A (squash only). Disabled `--enable-merge-commit` and `--enable-rebase-merge` at GitHub repo level for both `claude-code-kit` and `claude-code-kit-web` so the wrong strategy can't be selected by mistake.
- **Consequences**:
  - Future PRs must be merged with `gh pr merge --squash` (the only option GitHub now exposes).
  - release-please will produce one changelog entry per PR.
  - Past v1.6.x / 1.7.x duplicate entries remain — git history is immutable, fixing them isn't worth a force-push.
  - Documented in `agent_docs/conventions.md` under "Merging Pull Requests".
