## Security False-Positive Filtering

Shared filter so security findings stay high-signal. A finding is worth reporting only if you'd
confidently raise it in a PR review — a concrete, exploitable issue with a clear attack path. Aim
for **>80% confidence**. Better to miss a theoretical issue than to flood the report with noise.
When unsure, drop it.

### Out of scope — do not report

- DOS, resource exhaustion, rate limiting, memory/CPU consumption — except untrusted input that
  spends operator money (see *Still in scope*).
- ReDoS / regex injection.
- Outdated third-party dependencies — that is `/dependency-audit`'s job; do not duplicate it here.
- Memory-safety bugs (buffer overflow, use-after-free) in memory-safe languages (Rust, Go, JS/TS, Python…).
- Findings in test-only files, or inside documentation / markdown files. (Code that *assembles* a
  prompt from a markdown template stays in scope.)
- Lack of hardening, defense-in-depth, or audit logs — code need not implement every best practice; flag concrete vulns only.
- Log spoofing — unsanitized user input written to logs is not itself a vuln. Logging non-PII is fine even if it feels "sensitive."
- Theoretical race conditions / timing attacks — report only when concretely exploitable.

### Trusted by assumption — an attack that relies on controlling these is invalid

- **Environment variables and CLI flags** — trusted in a normal deployment. (Whether a *deployed*
  value switches a control on is a different question: if the repo can't show it, that's NEEDS
  VALIDATION, not a dropped finding.)
- **UUIDs** — assume unguessable; they do not need validation.
- **Client-side (browser JS/TS) auth or permission checks** — the backend owns validation, so their
  absence client-side is not a vuln. Same for any client → backend flow: the backend is responsible
  for validating and sanitizing all inputs.

### Framework / pattern precedents

- **React & Angular auto-escape.** Do not report XSS in `.tsx`/`.jsx`/Angular components unless they
  use `dangerouslySetInnerHTML`, `bypassSecurityTrustHtml`, or an equivalent unsafe escape hatch —
  including model output rendered through a Markdown/HTML renderer with raw HTML enabled.
- **SSRF** is reportable only if it controls the host or protocol — path-only control is not.
- **Command injection in shell scripts** is usually not exploitable (shell scripts rarely run on
  untrusted input) — report only with a concrete untrusted-input path.
- **GitHub Actions workflows and Jupyter notebooks (`.ipynb`)** are rarely exploitable in practice —
  require a specific, concrete attack path with untrusted input before reporting.
- **Subtle web issues** (tabnabbing, XS-Leaks, prototype pollution, open redirects) — report only at very high confidence.

### LLM, agent and MCP code

Applies wherever a model's context, output or tool calls touch a trust decision: chat and RAG,
agent memory, tool-calling loops, MCP servers and clients.

- **Prompt injection alone is not a finding.** Report it only with a code-level boundary failure:
  the injected content reaches another principal's context, invokes authority the requester lacks,
  discloses data they can't read, drives a sink they can't reach directly, or causes an action the
  affected principal didn't request or approve (see action binding below).
- **A guardrail prompt is not a security boundary.** "Never reveal…" or "only call X when…" in a
  prompt neither makes a path safe nor is its absence a finding. Only deterministic controls count:
  authorization on the resource, isolation, allowlists, scoped credentials.
- **Model output, retrieved content, memory, tool results and MCP tool descriptions are untrusted
  input.** Trace model-produced tool arguments to their sink (SQL, shell, path, URL fetch) like
  request parameters. A JSON schema narrows the shape; it isn't authorization.
- **Confused deputy** — the tool runs under a service credential and the handler doesn't re-check
  the requesting user's permission on the named resource. Not a finding when the shared credential
  carries enforced per-user scope, or the user could do the same thing directly anyway.
- **Authorization and action binding are separate.** Attacker-controlled content that makes an
  action run under a victim's valid authority, when the victim didn't request or approve that exact
  action, is a finding even though the victim is allowed to do it. So is an approval for one set of
  arguments that executes with another.
- **Cross-tenant context** — history, embeddings, retrieval results or prompt caches keyed too
  broadly. Check the tenant/ACL filter in the query and in every cache key, not just on the record.
- **Persistent memory poisoning** — attacker content or a model summary written into durable memory
  that later shapes another user's or a privileged session. Report it only when you can point to
  both the attacker-controlled write and that later read; a write with no such reader isn't enough.
- **When the deciding fact is outside the repo** — model or provider behaviour, whether a renderer
  executes raw HTML, which MCP server is really behind a name — report NEEDS VALIDATION, naming
  that fact.
- **Not findings:** disclosing a generic system prompt (disclosing credentials or another user's
  data from the context is); a user's own memory used only for that user's own requests.
  An intentional, direct request that uses the requester's own authority isn't a defect just
  because a model carries it out.
- The exploit scenario must name the attacker, the affected principal, the identity the action
  runs as, the resource, the action, and the observable impact.

These rules are adapted from the core discipline in Cloudflare's [security-audit-skill](https://github.com/cloudflare/security-audit-skill).

### Still in scope — do report these

- Hardcoded credentials / API keys / tokens committed to source. (The kit does not assume a separate secret scanner.)
- Logging high-value secrets (passwords, tokens) or PII in plaintext. Logging URLs is assumed safe.
- Injection with a real untrusted-input → sink path: SQLi, command injection, path traversal, template/XXE/deserialization, `eval`.
- Auth bypass, privilege escalation, broken object-level authorization — on the server side.
- **Untrusted input that spends operator money.** An anonymous caller (including free
  self-signup), or a request whose attacker-set count, size, `max_tokens`, model tier or fan-out
  multiplies the billed work, triggering model calls, paid third-party APIs, SMS or email sends, or
  expensive per-job compute (GPU inference, sandbox/VM spin-up, transcoding) with nothing bounding
  it. Same for an agent or tool loop where one request can enqueue repeated paid calls with no
  per-request budget. Check body limits, quotas and loop caps in the code before calling a path
  unbounded. If the code has no bound and the deciding one would sit outside the repo (an API-gateway
  or WAF quota in front of the route), report NEEDS VALIDATION naming it; a provider's account-wide
  spending cap isn't a per-request bound. The exploit scenario states attacker effort against
  operator cost (e.g. one anonymous POST → N model calls). File it under `auth` — the missing piece
  is a quota or access boundary. Severity tops out at HIGH (anonymous, or one request amplifying to
  large spend); MEDIUM when it needs an account or sustained volume. Not findings: a missing rate
  limit on work that costs the operator nothing extra, and a user spending within their own plan or
  quota.

### Every reported finding must include

- A concrete **exploit scenario** — the specific input/request and what it achieves. If you cannot write one, the finding is not ready.
- A specific `file:line` and an actionable fix.
