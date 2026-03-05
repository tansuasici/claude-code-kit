# Subagent Strategy

## When to Use Subagents

Use the `Task` tool to spawn subagents when:

| Scenario | Agent Type | Why |
|----------|-----------|-----|
| Broad codebase search | `Explore` | Searches multiple patterns without polluting main context |
| Architecture analysis | `Plan` | Designs approach without filling context with exploration |
| Independent research questions | `general-purpose` | Runs in parallel, returns summary |
| Running tests/builds | Relevant custom agent | Isolates noisy output |

## When NOT to Use Subagents

- Simple file reads — use `Read` directly
- Specific grep/glob — use `Grep`/`Glob` directly
- Tasks requiring sequential decisions based on context
- When you already know what file to edit

**Rule of thumb:** If it takes < 3 tool calls, do it yourself.

---

## Agent Types

### Explore (read-only)
- Fast codebase search and navigation
- Cannot edit files
- Use for: "find all API endpoints", "how does auth work?", "where is X defined?"

### Plan (read-only)
- Architecture design and implementation planning
- Cannot edit files
- Use for: "design the approach for feature X", "what's the best way to refactor Y?"

### general-purpose (full access)
- Can read, write, edit, run commands
- Use for: complex multi-step tasks that need autonomy
- Heavier than Explore/Plan — use only when editing/execution is needed

---

## Parallelization Patterns

### Independent research (parallel)
When you need answers to multiple unrelated questions:

```text
Task 1: "Find all database query patterns in src/repositories/"
Task 2: "Find all API middleware in src/middleware/"
Task 3: "Check what testing framework is configured"
```

Launch all three simultaneously — they don't depend on each other.

### Sequential dependency (serial)
When each step depends on the previous:

```text
Step 1: "Find the auth module"          → returns file paths
Step 2: "Read and analyze auth flow"    → needs Step 1's paths
Step 3: "Plan auth refactor"            → needs Step 2's analysis
```

Must run in order.

### Fan-out / fan-in
Research in parallel, then synthesize:

```text
Parallel: Explore frontend, Explore backend, Explore shared types
Then: Plan the full-stack feature using all three results
```

---

## Context Management

### Why subagents help with context
- Each subagent gets a fresh context window
- Noisy search results don't pollute your main conversation
- Failed explorations don't waste main context space

### What to include in subagent prompts
- Be specific about what you need back
- Include relevant file paths if known
- Specify whether you want code or just information
- Tell the agent whether to write code or just research

### What comes back
- Subagent returns a single summary message
- The full exploration history is NOT visible to you
- Ask for specific details in the prompt if you need them

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Spawning a subagent for 1 file read | Use `Read` directly |
| Duplicating research you delegated | Trust the subagent result |
| Not being specific in the prompt | Tell it exactly what to return |
| Using `general-purpose` for read-only tasks | Use `Explore` — it's faster |
| Running dependent tasks in parallel | Check for dependencies first |
| Spawning subagent for a task you could do in 2 steps | Just do it yourself |
