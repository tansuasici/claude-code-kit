---
name: references-sync
description: Sync llms.txt-style dependency reference docs into docs/references/ so the agent has library docs in-context — scans package manifests and fetches known vendor references. Use when working with a third-party library whose docs aren't yet local.
user-invocable: true
---

# References Sync

## Core Rule

This skill is for **in-repo agent context**, not SEO. Google explicitly says `llms.txt` does not affect Search visibility (see [AI Optimization Guide, "Mythbusting"](https://developers.google.com/search/docs/fundamentals/ai-optimization-guide)). The skill exists so the agent has dependency docs in its working set — `docs/references/` files are read alongside code, not published to the web.

## Kit Context

Before starting this skill, ensure you have completed session boot:
1. Read `CODEBASE_MAP.md` for project understanding
2. Read `CLAUDE.project.md` if it exists for project-specific rules
3. Read `tasks/lessons/_index.md` for accumulated corrections (Top Rules + index)

If any of these haven't been read in this session, read them now before proceeding.

## When to Use

Invoke with `/references-sync` when:

- A new dependency is added and you want its docs in the agent's context
- A dependency is bumped to a major version (refresh the reference)
- Onboarding to a project — populate `docs/references/` for the existing manifest
- As a scheduled background task (`/loop monthly /references-sync`) to keep references fresh

## Default Behavior

When the user asks to sync, refresh, populate, or "set up references" for dependencies, produce the full references-sync workflow automatically using the Process and Output Format sections below. Do not require the user to specify which packages — the skill scans manifests itself.

This skill **writes files** by design — that's its job. It writes only inside `docs/references/` and never modifies code outside that directory. CLAUDE.md is touched only on the first successful run (to add the `## Reference Docs` pointer section), and only if the user agrees in interactive mode.

## Scope

This skill covers:

- `package.json` → npm dependencies + devDependencies
- `pyproject.toml` / `requirements.txt` → Python packages
- `Cargo.toml` → Rust crates
- `go.mod` → Go modules
- `Gemfile` → Ruby gems
- `composer.json` → PHP packages

It does NOT cover:

- Transitive dependencies (only direct ones — keeps `docs/references/` focused)
- Internal/workspace packages (auto-detected and skipped)
- Private registries (no access; skill skips gracefully)

## Process

### Phase 1: Inventory (first-pass leads)

This pass produces **candidates**, not findings. Treat manifest entries as leads for the next phases — not every dependency has a useful llms.txt.

1. Detect manifests at repo root. If none found, exit with a one-line message.
2. Parse each manifest to extract direct dependencies (name + version).
3. Cross-reference each against `templates/known-sources.yaml` to identify packages with known llms.txt URLs.
4. Bucket each candidate:
   - **Known** — has a curated llms.txt URL → Phase 2
   - **Unknown** — no curated URL but a public package → Phase 3 (fallback)
   - **Private/workspace** — skip silently
5. Read `docs/references/index.md` (if present) to see what's already synced.

### Phase 2: Fetch known references

For each "known" package:

1. Check if `docs/references/<package>-llms.txt` already exists and was modified within the last 30 days. If yes and `--force` was not passed, skip (already fresh).
2. Use **WebFetch** with the URL from `known-sources.yaml`. If 200, save body to `docs/references/<package>-llms.txt`. Prepend a 3-line header:
   ```text
   # <package> — fetched from <url> on <ISO date>
   # See https://llmstxt.org/ for the llms.txt format spec.
   # This file is for in-repo agent context, not SEO.
   ```
3. If fetch fails (network error, 4xx, 5xx), log the failure to the run summary but do not abort — move on.
4. Track per-package status (`fetched | cached | failed`).

### Phase 3: Fallback for unknown packages

For each "unknown" package:

1. Check if `docs/references/<package>-fallback.md` already exists. If yes, skip.
2. Generate a placeholder file from `templates/package-fallback.md`, substituting `{{name}}`, `{{version}}`, `{{manifest_path}}`, `{{homepage}}` (if discoverable from the manifest).
3. The placeholder is intentionally **stub-only** — it tells the agent "this package exists but no automated reference is available; add notes manually as you learn the API."

Do NOT auto-generate content from package READMEs in this skill. Auto-summarisation of README content tends to produce stale or misleading reference docs; the placeholder approach forces a human (or a more deliberate `/skill-extractor` invocation) to capture genuine learnings.

### Phase 4: Update `docs/references/index.md`

Maintain a managed-block table in `docs/references/index.md`:

```markdown
<!-- references-sync:start -->

_Last sync: 2026-05-18T14:23:00Z — references-sync v1_

| Package | Version | Source | File |
|---------|---------|--------|------|
| @anthropic-ai/sdk | 0.32.1 | official llms.txt | [./@anthropic-ai-sdk-llms.txt](./@anthropic-ai-sdk-llms.txt) |
| openai | 4.50.0 | official llms.txt | [./openai-llms.txt](./openai-llms.txt) |
| zod | 3.23.8 | fallback (stub) | [./zod-fallback.md](./zod-fallback.md) |

<!-- references-sync:end -->
```

Content outside the markers is preserved (users can hand-edit notes above/below the table).

### Phase 5: Update CLAUDE.md (first run only)

On the first run where `docs/references/index.md` is created, propose adding this section to CLAUDE.md:

```markdown
## Reference Docs

If `docs/references/index.md` exists, scan it when working with third-party libraries.
Per-package files (`<package>-llms.txt`, `<package>-fallback.md`) contain in-repo
context for those dependencies. These files are agent context, not public docs.
```

In interactive mode, ask before writing. In headless mode, write only if CLAUDE.md doesn't already contain `## Reference Docs`.

## Run Mode

| Decision point | Interactive default | Headless default (`mode:headless`) |
|---|---|---|
| Confirm before WebFetch | No (proceed) | Always proceed |
| `docs/references/` missing | Create it | Create it |
| Add `## Reference Docs` to CLAUDE.md | Ask | Add if section is absent |
| Refresh files within 30-day TTL | Skip (cached) | Skip (cached) |
| `--force` re-fetch all | Ask | Honour the flag |
| Fetch failure for a known package | Log + continue | Log + continue |

See `.claude/skills/_shared/blocks/mode-detection.md`.

## Loop / Schedule Integration

```text
/loop monthly  /references-sync mode:headless
/schedule weekly /references-sync mode:headless
```

Monthly cadence is the recommended default — llms.txt files rarely change daily, and the WebFetch budget is non-trivial.

## Output Format

```markdown
# References Sync Report

_Run: 2026-05-18T14:23:00Z — references-sync v1_

## Summary

| Metric | Value |
|--------|-------|
| Manifests scanned | 1 (package.json) |
| Direct dependencies | 47 |
| Known sources matched | 6 |
| Fetched (this run) | 4 |
| Cached (within TTL) | 2 |
| Fallback stubs written | 3 |
| Failed fetches | 0 |
| Skipped (private) | 2 |

## Fetched

- ✅ @anthropic-ai/sdk → docs/references/@anthropic-ai-sdk-llms.txt
- ✅ openai → docs/references/openai-llms.txt
- ✅ stripe → docs/references/stripe-llms.txt
- ✅ next → docs/references/next-llms.txt

## Cached (within 30-day TTL)

- ⏸ vercel-blob (last fetched 2026-04-22)
- ⏸ @vercel/edge (last fetched 2026-04-22)

## Fallback stubs

- 📝 zod → docs/references/zod-fallback.md (no known llms.txt)
- 📝 drizzle-orm → docs/references/drizzle-orm-fallback.md
- 📝 @tanstack/react-query → docs/references/tanstack-react-query-fallback.md

## Failures

_None._

## Index updated

`docs/references/index.md` table refreshed.
```

## Templates

- `templates/known-sources.yaml` — curated registry of vendors with llms.txt URLs. Users extend with project-specific entries.
- `templates/package-fallback.md` — stub for packages without llms.txt.
- `templates/references-index.md` — initial `docs/references/index.md` skeleton (used on first run).

## Notes

- **Privacy:** WebFetch hits the URLs listed in `known-sources.yaml`. The skill ships only public, well-known endpoints (Anthropic, OpenAI, Stripe, Vercel, etc.). If your project uses internal/private endpoints, add them to a `.claude/known-sources.local.yaml` file (gitignored by default).
- **No transitive deps:** Only direct dependencies are scanned. If you need an indirect dependency in `docs/references/`, add it manually to `known-sources.yaml` or create a stub by hand.
- **Pairs with `/harness-init`:** That skill scaffolds `docs/` and `docs/references/index.md`. This skill populates the per-package files.
- **Pairs with `/doc-gardening`:** When a dependency is removed from the manifest, `docs/references/<package>-*.md` becomes stale — `/doc-gardening` flags it as a stale path on the next sweep.
- **Refresh strategy:** 30-day TTL on cached files. Use `--force` to bypass. Major version bumps in the manifest are not auto-detected — the user should run `/references-sync --force` after a major upgrade.
