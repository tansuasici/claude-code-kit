---
name: performance-audit
description: Identifies performance bottlenecks including rendering, startup, memory, and I/O issues across any tech stack
user-invocable: true
---

# Performance Audit

## When to Use

Invoke with `/performance-audit` when:

- Users report slowness or performance degradation
- Before a production launch or scale-up
- After adding significant new features
- During optimization sprints or performance budgeting

## Process

### Phase 1: Identify Stack

Read project config files to determine the tech stack:

- **Frontend**: React, Vue, Angular, Svelte, Flutter, native mobile
- **Backend**: Node.js, Python, Go, Rust, Java, .NET
- **Database**: SQL, NoSQL, ORM in use
- **Infrastructure**: Caching layers, CDN, message queues

### Phase 2: Startup & Load Performance

Analyze initial load and startup paths:

- **Entry points**: Main module, bootstrap files, initialization sequences
- **Lazy loading**: Are heavy modules loaded upfront unnecessarily?
- **Import chains**: Deep import trees that block startup
- **Initialization**: Synchronous blocking during startup (DB connections, config loading)
- **Bundle size** (web): Large dependencies, missing tree-shaking, unoptimized assets

### Phase 3: Runtime Bottlenecks

Scan for common runtime performance issues:

**CPU-bound**
- O(n²) or worse algorithms in hot paths
- Unnecessary re-computation (missing memoization/caching)
- Synchronous heavy computation on the main/UI thread
- Regex backtracking on user input

**Memory**
- Memory leaks: event listeners not cleaned up, growing caches without eviction
- Large object retention: holding references to data no longer needed
- Unbounded collections: arrays/maps that grow without limits
- String concatenation in loops (in languages where strings are immutable)

**I/O-bound**
- N+1 query patterns (loop with DB/API call inside)
- Sequential API calls that could be parallel
- Missing database indexes on filtered/sorted columns
- Unbatched writes (inserting rows one at a time)
- Missing connection pooling

**Rendering (UI applications)**
- Unnecessary re-renders (React: missing memo/useMemo/useCallback, Vue: reactive over-tracking)
- Layout thrashing (reading layout properties between DOM writes)
- Large lists without virtualization
- Heavy computation in render paths
- Unoptimized images/assets (missing lazy loading, wrong formats, no responsive sizes)
- Animations on non-composited properties (layout-triggering CSS)

### Phase 4: Caching & Data Flow

Check caching strategy:

- Missing caching for expensive computations or API responses
- Cache invalidation issues (stale data served)
- Over-caching (caching cheap operations, wasting memory)
- Missing HTTP caching headers for static assets
- Database query result caching

### Phase 5: Concurrency & Async

Review async patterns:

- Unparallelized independent async operations (sequential await in loop)
- Missing backpressure handling (unbounded queues, no rate limiting)
- Thread pool exhaustion (blocking calls in async context)
- Deadlock potential in concurrent code

## Output Format

```markdown
# Performance Audit Report

## Executive Summary
[Overall performance health, top 3 critical findings]

## Critical Bottlenecks
| # | Category | Location | Issue | Impact | Fix |
|---|----------|----------|-------|--------|-----|
| 1 | I/O      | file:line | N+1 query in user list | O(n) DB calls per request | Batch query with IN clause |

## Optimization Opportunities
| # | Category | Location | Issue | Estimated Gain | Fix |
|---|----------|----------|-------|----------------|-----|

## Metrics
- Hot paths analyzed: N
- Critical bottlenecks: N
- Optimization opportunities: N
- Estimated impact: low/medium/high improvement potential

## Quick Wins
[List of easy fixes with high impact]

## Requires Investigation
[Issues that need profiling data to confirm]
```

## Notes

- This audit identifies likely bottlenecks through static analysis — profiling data confirms impact
- Focus on hot paths (request handlers, frequently called functions, render loops)
- Don't recommend premature optimization — only flag issues in paths that matter
