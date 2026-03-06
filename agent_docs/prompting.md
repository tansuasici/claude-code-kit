# Prompting & Bias Awareness

## The Sycophancy Problem

Agents are designed to follow instructions and please the user. This means:

- If you say "find a bug", it **will** find a bug — even if it has to invent one
- If you say "this code is broken", it will agree and "fix" working code
- If you say "is this good?", it will say yes more often than it should

This isn't a flaw — it's a design characteristic. Understanding it lets you work with it instead of against it.

---

## Neutral Prompting

Frame tasks so you don't bias the agent toward a predetermined outcome.

| Biased (avoid) | Neutral (prefer) |
|----------------|-------------------|
| "Find the bug in the database module" | "Walk through the database module logic and report your findings" |
| "This function is too slow, optimize it" | "Profile this function's performance and report what you find" |
| "Is there a security issue here?" | "Review this code and report anything noteworthy" |
| "Fix the authentication problem" | "Trace the authentication flow end-to-end and document how it works" |

### Why Neutral Works Better

A neutral prompt lets the agent report what it **actually finds**, which might be:
- No bugs (good news!)
- A different bug than you expected
- A performance characteristic, not a problem
- A design question, not a defect

A biased prompt forces the agent to produce the expected result, even if the truth is different.

---

## Adversarial Verification Pattern

For high-stakes reviews (security, data integrity, production bugs), use multiple agents with opposing incentives:

### The Three-Agent Pattern

```text
┌─────────────┐    ┌──────────────────┐    ┌─────────────┐
│  Finder      │    │  Adversary       │    │  Referee     │
│              │    │                  │    │              │
│  Goal: Find  │───>│  Goal: Disprove  │───>│  Goal: Judge │
│  all issues  │    │  false positives │    │  accurately  │
└─────────────┘    └──────────────────┘    └─────────────┘
```

**Agent 1 — Finder**: Incentivized to find issues aggressively.
- "Review this code for bugs. Score: +1 low impact, +5 medium, +10 critical."
- Will over-report (including false positives). This is intentional — it casts a wide net.

**Agent 2 — Adversary**: Incentivized to disprove false positives.
- "For each bug, prove it's NOT a bug. Score: +points for correct disproval, -2x points if you wrongly dismiss a real bug."
- Will aggressively challenge findings, but cautiously (penalty for mistakes).

**Agent 3 — Referee**: Incentivized to be accurate.
- "Judge each finding. +1 for correct judgment, -1 for incorrect."
- Has no incentive to lean either way.

### When to Use This Pattern

- Security audits
- Pre-production code reviews
- Data migration validation
- Critical bug hunts

### When NOT to Use This Pattern

- Simple feature implementation
- Routine code reviews
- Tasks where a single agent's judgment is sufficient

---

## Working WITH Sycophancy

Sycophancy isn't always a problem — you can leverage it deliberately:

### Enthusiastic Exploration
Tell the agent it will be rewarded for thoroughness:
- "Search exhaustively. Every edge case you find is valuable."
- The agent will be hyper-thorough, which is exactly what you want for exploration.

### Strict Compliance
Tell the agent there are consequences for deviation:
- "Follow this specification exactly. Any deviation from the spec is a failure."
- The agent will be rigidly compliant, which is exactly what you want for implementation.

### Quality Gates
Set explicit standards it will try to meet:
- "This code must pass a staff engineer's review. No shortcuts, no stubs, no TODOs."
- The agent will aim higher because you set the bar explicitly.

---

## Assumption Detection

Agents fill in gaps silently when they don't have enough context. This is where most bad outputs come from.

### Signs the Agent Is Making Assumptions

- It introduces dependencies or patterns you didn't mention
- It implements features you didn't ask for
- It makes architectural choices without flagging alternatives
- It confidently states something that feels like a guess

### How to Prevent It

1. **Be specific**: More detail in the prompt = fewer gaps to fill
2. **Require flagging**: "If you need to make any assumptions, list them before implementing"
3. **Use contracts**: Explicit completion criteria leave no room for interpretation
4. **Check after compaction**: Context loss forces the agent to assume — re-read rules prevent this

---

## Red Flags in Agent Output

| Symptom | Likely Cause |
|---------|-------------|
| Agent "finds" exactly what you asked about | Sycophancy — rephrase neutrally |
| Agent agrees with your incorrect assessment | Sycophancy — state facts, not opinions |
| Agent implements something you didn't request | Gap-filling — be more specific |
| Agent's output contradicts earlier output | Context bloat — start fresh session |
| Agent confidently describes non-existent code | Hallucination — ask it to show the file:line |
| Agent says "I've verified" but you see no test runs | Compliance theater — require actual commands |
