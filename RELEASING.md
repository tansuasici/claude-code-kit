# RELEASING

How `@tansuasici/claude-code-kit` ships, plus the failure modes the npm side will surface if it isn't set up right. Read this before cutting a release.

## 1. Normal release

release-please opens a PR titled `chore(main): release X.Y.Z` whenever there are unreleased `feat:` / `fix:` commits on `main`. Merge that PR. The release workflow then tags, publishes to npm, and updates the plugin marketplace automatically.

## 2. NPM_TOKEN setup (one-time)

Create a **Granular Access Token** at https://www.npmjs.com/settings/\<user\>/tokens:

- Scope: `@tansuasici/claude-code-kit`
- Permissions: Read + Write
- Expiry: 1 year

Paste it into the `NPM_TOKEN` repo secret via GitHub UI → Settings → Secrets and variables → Actions. Never pass it through CLI history, chat, or screenshots. Set a calendar reminder ~11 months out to rotate.

## 3. 2FA mode requirement (the lesson)

Set the npm account 2FA mode to **`Authorization only`**, not `Authorization and writes`. Check at https://www.npmjs.com/settings/\<user\>/profile. With `Authorization and writes`, every `npm publish` requires an interactive OTP — CI will fail with `EOTP` regardless of token type or validity. This is an account-level setting; the repo cannot configure it.

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

If a token is ever exposed (chat, logs, screenshots, terminal scrollback), revoke it immediately at https://www.npmjs.com/settings/\<user\>/tokens. Generate a fresh one. Update the `NPM_TOKEN` GitHub Secret. Do not reuse a token that may have been compromised, even if it "looks fine."

## 6. Plugin marketplace publication

`.claude-plugin/marketplace.json` and `.claude-plugin/plugin.json` versions stay in sync with the npm package via release-please — there is no separate publish step. Users install the plugin with:

```text
/plugin marketplace add tansuasici/claude-code-kit
/plugin install claude-code-kit@claude-code-kit
```

---

## Sources

- npm Granular Access Tokens — https://docs.npmjs.com/about-access-tokens
- npm Two-Factor Authentication — https://docs.npmjs.com/about-two-factor-authentication
- Claude Code plugins — https://code.claude.com/docs/en/plugins
