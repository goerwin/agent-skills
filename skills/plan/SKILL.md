---
name: plan
description: Manage implementation plans in .goerwin/plans/. Invoke explicitly; do not auto-trigger when starting work, resuming tasks, or planning implementation.
disable-model-invocation: true
---

# Plan

## Location

Plans live in `.goerwin/plans/` at the repo root when inside a git repo; `~/.goerwin/plans/` when no repo is found.

```bash
if git rev-parse --git-dir >/dev/null 2>&1; then
  plans_dir="$(git rev-parse --show-toplevel)/.goerwin/plans"
else
  plans_dir="$HOME/.goerwin/plans"
fi
mkdir -p "$plans_dir"
```

## When invoked

1. Check `plans_dir` for an existing plan that covers the work — single `.md` files or folders with `plan.md`.
2. If one exists, read and follow it unless the user directs otherwise.
3. If none exists and the task is multi-step or architectural, create a plan before implementing.

## Creating a plan

Use one of two layouts:

**Single file** — default for most plans:

- `<plans_dir>/<yyyy-mm-dd>-<NN>-<reasonable-name>.md`

**Folder** — when the plan needs more than one file (diagrams, reference data, split docs):

- `<plans_dir>/<yyyy-mm-dd>-<NN>-<reasonable-name>/plan.md` — main plan (steps, decisions, status)
- Additional files in the same folder (e.g. `context.md`, `stack.md`, `references.json`)

`<NN>` is the next per-day index starting at `01`. Use the same `<yyyy-mm-dd>-<NN>-<reasonable-name>` stem for both layouts.

```bash
d=$(date +%F)
last=$(ls "$plans_dir" 2>/dev/null | sed -nE "s/^$d-([0-9]{2})-.*/\1/p" | sort -n | tail -1)
n=$(printf '%02d' $(( 10#${last:-0} + 1 )))
# single file: $plans_dir/$d-$n-my-feature.md
# folder:      $plans_dir/$d-$n-my-feature/plan.md
```

- Keep plans concise and actionable. Write for resumability — implementation may stop and be picked up later by another agent. Prefer steps, file paths, and decisions over prose.
- Get user approval on the plan before implementing.
- Before starting implementation, ask the user whether to use a new branch or worktree.

## Updating a plan

- Get user approval before updating an existing plan.
- If a plan conflicts with other instructions, ask the user for clarification before proceeding.
