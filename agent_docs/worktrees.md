# Worktree Isolation

Claude Code can run a subagent in its own [git worktree](https://git-scm.com/docs/git-worktree) — a separate working directory with its own files and branch, sharing the same repository history and remote as your main checkout. Edits the subagent makes never touch your working tree.

This is a sharp tool with a narrow edge. Read the semantics before reaching for it — the default behaviour surprises people, and using it in the wrong place quietly does the wrong thing.

---

## Semantics (what actually happens)

- **Clean base, not your dirty tree.** A subagent worktree is branched from your repository's default branch (`origin/HEAD`) — or from local `HEAD` if you set `worktree.baseRef: "head"`. Either way it is a **clean checkout**. Your **uncommitted and unpushed** changes (staged + unstaged) are **NOT** carried into the worktree.
- **No automatic merge-back.** When the subagent finishes, its changes stay on the worktree's branch. Nothing is merged or committed back into your main working tree automatically. You review and merge/cherry-pick yourself.
- **Auto-cleanup only if untouched.** If the subagent makes **no** changes, Claude Code removes the worktree automatically. If it made changes, the worktree and its branch remain on disk until the cleanup sweep (`cleanupPeriodDays`) — and only when there are no uncommitted changes, no untracked files, and no unpushed commits.
- **Where it lands.** `.claude/worktrees/<name>/` at the repo root.

> Verified against the Claude Code docs (`/worktrees`, `/sub-agents`). Frontmatter key introduced around v2.1.154.

---

## When to use it

Worktree isolation exists for **one** job: letting **file-mutating** agents run **in parallel** without colliding on the same files. Reach for it when:

- You spawn **several agents that each write**, and you don't want their edits to interleave in one checkout — e.g. three forks each attempting a different implementation of the same feature, so you can compare branches and keep the best.
- You want a mutating agent's work **quarantined** on its own branch for review before it touches your tree.

That's the shape it's built for: parallel writers, branch-per-attempt, manual merge.

---

## When NOT to use it (the trap)

**Do not put `isolation: worktree` on read-only reviewer agents** — `code-reviewer`, `security-reviewer`, `qa-reviewer`, `planner`, `devils-advocate`. Two reasons, both decisive:

1. A reviewer makes no changes, so the worktree is created and then immediately auto-discarded — pure overhead for zero isolation benefit (there is nothing to isolate).
2. Far worse: the worktree is a clean checkout of `origin/HEAD`. A reviewer running there would review the **committed remote state and miss your uncommitted local changes** — which is exactly the diff a review is supposed to inspect. The review would look clean while silently examining the wrong tree.

This is why the kit's review agents deliberately **do not** carry `isolation: worktree`. They read your live working tree, which is the point.

The same caveat applies to any agent that needs to see your **current uncommitted work**: a worktree hides it.

---

## How to invoke it

Three entry points, same feature:

- **Per-subagent frontmatter** — set it on an agent that genuinely mutates files in parallel:
  ```yaml
  ---
  name: parallel-implementer
  description: Builds a feature attempt on an isolated branch
  isolation: worktree
  ---
  ```
- **Ad-hoc via the Agent tool** — when you spawn a fork yourself: `isolation: "worktree"`.
- **CLI** — `claude --worktree <name>` runs a whole session in its own worktree (these are never auto-removed by the cleanup sweep — you manage them).

For the common "try N approaches in parallel, keep the best" pattern, you don't need a dedicated agent — ask for parallel forks with worktree isolation and review the resulting branches.

---

## Housekeeping

`.claude/worktrees/` is gitignored by the kit so worktree contents never show up as untracked files in your main checkout. Don't commit it. If a mutating agent leaves a branch you want, merge or cherry-pick it; otherwise delete the worktree (`git worktree remove`) and the cleanup sweep will collect the rest.
