# Reference Docs

> In-repo context for third-party dependencies. **Not for SEO** — Google
> explicitly says `llms.txt` does not affect Search visibility. These files
> exist so the agent has dependency docs alongside the code it's editing.

## How this directory works

- `<package>-llms.txt` — official `llms.txt` fetched from the vendor (kept fresh by `/references-sync`)
- `<package>-fallback.md` — stub for packages without a published llms.txt; hand-maintained
- `index.md` — this file. The table below is auto-maintained between markers; content outside the markers is preserved.

## Sync

```text
/references-sync              # incremental (skip files fetched in last 30 days)
/references-sync --force      # re-fetch everything
/loop monthly /references-sync mode:headless
```

## Catalog

<!-- references-sync:start -->

_No references synced yet. Run `/references-sync` to populate this table._

<!-- references-sync:end -->

## Add a source manually

If your project depends on a package that publishes an `llms.txt` but isn't in
the kit's curated list, add it to `.claude/known-sources.local.yaml` (same
schema as `templates/known-sources.yaml` in the skill). Or submit a PR to the
kit to share the source with everyone.
