# RELEASING

How `@tansuasici/claude-code-kit` ships, plus the failure modes the npm side will surface if it isn't set up right. Read this before cutting a release.

## 1. Normal release (GitHub Actions)

release-please opens a PR titled `chore(main): release X.Y.Z` whenever there are unreleased `feat:` / `fix:` commits on `main`. Merge that PR. The release workflow then tags, publishes to npm, and updates the plugin marketplace automatically.

This needs GitHub-hosted Actions. When they are unavailable (for example the account's Actions minutes are locked), use the local flow in §1a–§1c instead.

## 1a. Validate locally

`scripts/ci-local.sh` runs every check in `.github/workflows/validate.yml` on this machine — Markdown Lint, Link Check, Template Validation, KitBench, the smoke tests, and the sync/drift guards. It runs them all even after one fails and exits non-zero if any did.

```bash
./scripts/ci-local.sh
```

It needs `node`/`npx` (markdownlint, pinned to the version CI runs), `python3`, and `lychee` (`brew install lychee`) with network access for the link check. It covers the current OS only; CI also runs KitBench on macOS and Linux.

To run it before every push, link it as a pre-push hook (one-time, per clone):

```bash
ln -s ../../scripts/ci-local.sh .git/hooks/pre-push
```

`git push --no-verify` skips it for a single push.

Do not replace hosted Actions with a self-hosted runner on this repo. It is public, so any `pull_request` from a fork would run arbitrary code on that machine.

## 1b. Cut a release locally

release-please's CLI talks to the GitHub API, not to Actions, so it does the same job from a terminal. Run it from an up-to-date `main` with `gh` signed in:

```bash
npx --yes release-please@17.11.2 release-pr --token "$(gh auth token)" --repo-url tansuasici/claude-code-kit
```

That opens (or updates) the `chore(main): release X.Y.Z` PR, which bumps `VERSION`, `package.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.release-please-manifest.json`, and `CHANGELOG.md`. Check out the PR branch, run `./scripts/ci-local.sh`, then merge it. After the merge:

```bash
npx --yes release-please@17.11.2 github-release --token "$(gh auth token)" --repo-url tansuasici/claude-code-kit
```

That creates the `vX.Y.Z` tag and the GitHub release.

The `main` ruleset requires the Link Check, Markdown Lint, and Template Validation statuses from GitHub Actions. With Actions down nothing can post them, so a PR cannot merge until the repo owner relaxes that rule (or adds a bypass) for the duration. That is a repo-settings decision, not something a script should change.

## 1c. Publish to npm (manual)

From the release tag:

```bash
git fetch --tags
git checkout vX.Y.Z
npm publish
```

`npm publish` opens a browser for the 2FA approval. If it asks for a one-time code in the terminal instead, rerun it as `npm publish --otp=` followed by the current code from your authenticator. Then return to `main` and verify:

```bash
git checkout main
npm view @tansuasici/claude-code-kit version
```

## 2. NPM_TOKEN setup (one-time)

Create a **Granular Access Token** at `https://www.npmjs.com/settings/<user>/tokens`:

- Scope: `@tansuasici/claude-code-kit`
- Permissions: Read + Write
- Expiry: 1 year

Paste it into the `NPM_TOKEN` repo secret via GitHub UI → Settings → Secrets and variables → Actions. Never pass it through CLI history, chat, or screenshots. Set a calendar reminder ~11 months out to rotate.

## 3. 2FA mode requirement (the lesson)

Set the npm account 2FA mode to **`Authorization only`**, not `Authorization and writes`. Check at `https://www.npmjs.com/settings/<user>/profile`. With `Authorization and writes`, every `npm publish` requires an interactive OTP — CI will fail with `EOTP` regardless of token type or validity. This is an account-level setting; the repo cannot configure it.

## 4. EOTP recovery (manual publish fallback)

When CI publish fails with `EOTP`:

```bash
git fetch --tags
git checkout vX.Y.Z
npm login                                       # browser auth
npm publish --access public                     # OTP prompt at terminal
git checkout main
npm view @tansuasici/claude-code-kit version    # verify
```

Then fix the underlying cause (almost always §3 above) so the next release doesn't need this step.

## 5. Token rotation hygiene

If a token is ever exposed (chat, logs, screenshots, terminal scrollback), revoke it immediately at `https://www.npmjs.com/settings/<user>/tokens`. Generate a fresh one. Update the `NPM_TOKEN` GitHub Secret. Do not reuse a token that may have been compromised, even if it "looks fine."

## 6. Plugin marketplace publication

`.claude-plugin/marketplace.json` and `.claude-plugin/plugin.json` versions stay in sync with the npm package via release-please — there is no separate publish step. Users install the plugin with:

```text
/plugin marketplace add tansuasici/claude-plugins
/plugin install code-kit@tansuasici
```

---

## Sources

- npm Granular Access Tokens — <https://docs.npmjs.com/about-access-tokens>
- npm Two-Factor Authentication — <https://docs.npmjs.com/about-two-factor-authentication>
- Claude Code plugins — <https://code.claude.com/docs/en/plugins>
