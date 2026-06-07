---
name: web-read
description: Extract clean, readable markdown from a web page with the Defuddle CLI — strips nav, ads, and boilerplate to cut tokens versus WebFetch. Use when given a URL to read or analyze (docs, articles, blogs, changelogs, RFCs). Do NOT use for .md or JSON/API URLs — use WebFetch directly.
user-invocable: true
---

# Web Read

## Core Rule

When handed a content URL to read, extract clean markdown with the Defuddle CLI instead of pulling raw HTML through WebFetch — it strips nav, ads, cookie banners, and boilerplate, so the same content costs far fewer tokens. Never silently install a global tool: if Defuddle is missing, surface the one-line install and fall back to WebFetch so the task isn't blocked.

## When to Use

When the user gives a URL to read, summarize, or analyze:

- Documentation pages, API guides, RFCs, specs
- Articles, blog posts, release notes, changelogs
- Any standard, content-heavy web page

Do NOT use for:

- URLs ending in `.md` / `.txt` — already clean; use WebFetch directly
- JSON / API endpoints — use WebFetch or `curl`
- Pages behind auth — Defuddle fetches anonymously; use an authenticated path instead
- Vendoring library docs into `docs/references/` — that's `/references-sync`'s job (it may call this skill to do the extraction step)

## Prerequisites

Check once per session:

```bash
command -v defuddle >/dev/null && echo ok || echo missing
```

If missing, tell the user the install and ask before running it — a global install is a tool change worth surfacing:

```bash
npm install -g defuddle
```

While it's unavailable, fall back to `WebFetch` rather than blocking.

## Process

1. Extract clean markdown:

   ```bash
   defuddle parse <url> --md
   ```

2. For long pages, save to a file and read only the slice you need instead of inlining the whole thing:

   ```bash
   defuddle parse <url> --md -o /tmp/<slug>.md
   ```

3. Pull a single metadata field when that's all you need:

   ```bash
   defuddle parse <url> -p title
   defuddle parse <url> -p description
   ```

Run `defuddle --help` for the current flag set — prefer it over memorized options, it stays in sync with the installed version.

## Output Format

Clean Markdown of the page's main content, with site chrome removed. Use it as the source for summaries, extraction, or analysis; when you quote the page, quote from this cleaned text.

| Flag | Output |
|------|--------|
| `--md` | Markdown — default choice |
| `--json` | JSON with both HTML and markdown |
| `-p <name>` | A single metadata field (`title`, `description`, `domain`) |
| (none) | Raw HTML — rarely what you want |

## Notes

- Defuddle is a global CLI (`npm i -g defuddle`), not a project dependency — it never touches `package.json`, so it doesn't trip the Protected-Changes dependency gate. Surface the install anyway before running it.
- The token win is real on heavy pages (docs sites, news, marketing): raw HTML through WebFetch carries layout, scripts, and nav that Defuddle drops.
- Pairs with `/references-sync`, which can call this to extract vendor docs before writing `docs/references/<pkg>-llms.txt`.
- Upstream: <https://github.com/kepano/defuddle>
