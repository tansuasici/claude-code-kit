## Security False-Positive Filtering

Shared filter so security findings stay high-signal. A finding is worth reporting only if you'd
confidently raise it in a PR review — a concrete, exploitable issue with a clear attack path. Aim
for **>80% confidence**. Better to miss a theoretical issue than to flood the report with noise.
When unsure, drop it.

### Out of scope — do not report

- DOS, resource exhaustion, rate limiting, memory/CPU consumption.
- ReDoS / regex injection.
- Outdated third-party dependencies — that is `/dependency-audit`'s job; do not duplicate it here.
- Memory-safety bugs (buffer overflow, use-after-free) in memory-safe languages (Rust, Go, JS/TS, Python…).
- Findings in test-only files, or inside documentation / markdown files.
- Lack of hardening, defense-in-depth, or audit logs — code need not implement every best practice; flag concrete vulns only.
- Log spoofing — unsanitized user input written to logs is not itself a vuln. Logging non-PII is fine even if it feels "sensitive."
- Theoretical race conditions / timing attacks — report only when concretely exploitable.

### Trusted by assumption — an attack that relies on controlling these is invalid

- **Environment variables and CLI flags** — trusted in a normal deployment.
- **UUIDs** — assume unguessable; they do not need validation.
- **Client-side (browser JS/TS) auth or permission checks** — the backend owns validation, so their
  absence client-side is not a vuln. Same for any client → backend flow: the backend is responsible
  for validating and sanitizing all inputs.

### Framework / pattern precedents

- **React & Angular auto-escape.** Do not report XSS in `.tsx`/`.jsx`/Angular components unless they
  use `dangerouslySetInnerHTML`, `bypassSecurityTrustHtml`, or an equivalent unsafe escape hatch.
- **SSRF** is reportable only if it controls the host or protocol — path-only control is not.
- **Command injection in shell scripts** is usually not exploitable (shell scripts rarely run on
  untrusted input) — report only with a concrete untrusted-input path.
- **GitHub Actions workflows and Jupyter notebooks (`.ipynb`)** are rarely exploitable in practice —
  require a specific, concrete attack path with untrusted input before reporting.
- **Subtle web issues** (tabnabbing, XS-Leaks, prototype pollution, open redirects) — report only at very high confidence.

### Still in scope — do report these

- Hardcoded credentials / API keys / tokens committed to source. (The kit does not assume a separate secret scanner.)
- Logging high-value secrets (passwords, tokens) or PII in plaintext. Logging URLs is assumed safe.
- Injection with a real untrusted-input → sink path: SQLi, command injection, path traversal, template/XXE/deserialization, `eval`.
- Auth bypass, privilege escalation, broken object-level authorization — on the server side.

### Every reported finding must include

- A concrete **exploit scenario** — the specific input/request and what it achieves. If you cannot write one, the finding is not ready.
- A specific `file:line` and an actionable fix.
