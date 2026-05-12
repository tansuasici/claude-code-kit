## Run Mode

This skill supports two run modes:

| Mode | When | Behavior |
|------|------|----------|
| **Interactive** (default) | No mode token in arguments | Ask blocking questions at decision points; end with a "What's next?" prompt or follow-up clarification |
| **Headless** | `mode:headless` present in arguments | No blocking questions — apply documented defaults silently; end with a structured terminal report |

### Detection

Inspect the skill's argument bag (e.g., `$ARGUMENTS`) for a `mode:headless` token. Tokens starting with `mode:` are flags, not content — strip them before treating the remainder as user input or scope.

Examples:

```text
/skill-extractor                          # interactive
/skill-extractor mode:headless            # headless, no extra context
/skill-extractor mode:headless auth flow  # headless, context hint "auth flow"
```

### When headless mode applies

- Automations and hook invocations (no human present)
- Scheduled runs (`/loop`, cron, CI pipeline)
- Skill-to-skill orchestration (orchestrator chose the defaults)

### What headless mode changes

- **Skip every "ask the user" step.** Substitute the default documented in this skill's own Process section.
- **Never prompt for confirmation.** Decisions are pre-committed by the defaults.
- **No "What's next?" exit.** Replace the interactive end with a structured terminal report listing what was done and which decisions were taken silently.
- **Errors are reported, not escalated.** If a default cannot be satisfied (missing file, ambiguous scope), report the failure and exit non-zero rather than blocking on user input.

Headless mode applies for the entire run once detected — do not switch back to interactive mid-skill.
