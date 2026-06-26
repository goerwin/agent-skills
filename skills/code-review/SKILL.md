---
name: code-review
description: Use when explicitly asked to review a GitHub PR or branch's changes. Reviews only what the branch introduced via the merge-base diff (never stale or unrelated files), then reports findings without modifying the branch or posting to GitHub.
disable-model-invocation: true
---

# Code Review

Review **only what the PR/branch introduced**, then report findings. Never modify the branch; never post to GitHub.

## THE RULE (read first)

Always diff against the **merge-base** — three-dot `base...head` — **never** two-dot `base head`.
Two-dot also shows files the *target* branch changed after this branch diverged, so a stale branch drags in unrelated files. Three-dot shows only this branch's changes and matches GitHub's "Files changed" tab even when the branch is behind target.

## Hard gates (never skip)

This skill has two points where you MUST stop and wait for the user. They are the
most-skipped parts of the skill — treat each as a hard barrier, not a suggestion:

1. **After step 2 (scope preview)** — wait for the user to confirm scope *before* reading or analyzing any changed file.
2. **Before step 6 (save)** — ask before writing the review to disk.

These thoughts mean you are about to skip gate 1 — STOP:

| Rationalization | Reality |
|---|---|
| "I'll read the files while they decide" | Reading a changed file IS reviewing. It happens after confirmation. |
| "I already know the scope is right" | The gate is for the user to confirm, not you. Print it and wait. |
| "Gathering context isn't reviewing yet" | Opening any changed file is step 4. Stop at step 2. |
| "It's a small / obvious PR" | Size never waives the gate. Always pause. |

## 1. Resolve scope

Decide what to review:

- A PR number/URL was given, **or** an open PR exists for the current branch → **Scenario A** (PR is source of truth).
  Detect an open PR for the current branch (resolve the head from the upstream
  tracking ref — the local branch name can differ from the remote/PR head, e.g.
  worktrees that rename slash→dash; fall back to the local name):
  ```bash
  up=$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null); head_ref=${up#*/}
  gh pr view "${head_ref:-$(git branch --show-current)}" --json number,baseRefName,headRefName 2>/dev/null
  ```
- Otherwise → **Scenario B** (branch-vs-branch).

### Scenario A — PR is source of truth
- `gh` authed → the PR scope and diff come from GitHub (already merge-base; handles fork PRs):
  ```bash
  gh pr view <pr> --json title,body,state,url,baseRefName,headRefName,additions,deletions,changedFiles
  gh pr diff <pr> --name-only      # changed files
  gh pr diff <pr>                  # full diff (review file-by-file for large PRs)
  ```
- `gh` NOT available → fall back to the local merge-base diff (below) against the PR's base branch, and **tell the user** GitHub couldn't be used.

### Scenario B — branch-vs-branch (local)
- `head` = current branch.
- `base` = repo default branch: `git remote show origin | sed -n 's/.*HEAD branch: //p'`. Show it and proceed; ask only if it can't be determined or `head == base`.
- Fetch (non-destructive), then diff three-dot:
  ```bash
  git fetch --quiet origin
  git diff --name-status origin/<base>...HEAD   # changed files (status + path)
  git diff --shortstat   origin/<base>...HEAD   # file / line totals
  git diff origin/<base>...HEAD -- <path>       # per file
  ```

## 2. Preview scope — STOP and wait for confirmation

🛑 **MANDATORY STOP.** Print the scope header + changed-file list (format below), ask the user to confirm the scope is right, then **end your turn and wait for their reply.** Do not continue in the same response.

Until the user replies, you MUST NOT:
- read, open, `Read`, or otherwise inspect any changed file,
- fetch the full diff or any per-file diff for analysis,
- run step 3 (enrich) or step 4 (review), or
- call any further tool.

The only actions allowed before this point are the scope-gathering commands in steps 1–2. **Reading or analyzing a changed file is reviewing** — it happens *after* confirmation, never before. If the user corrects the base/branch, re-run scope and stop again.

```
Scope: <head> -> <base> | merge-base <short-sha> | <N> files, +<adds>/-<dels> | <X> commits behind <base>
PR: #<number> <url>                    # Scenario A only — omit this line in Scenario B
Source: GitHub (gh pr diff) | local fallback (gh unavailable) | branch-vs-branch
Files:
  <status> <path>
  ...
```

Where the values come from:
- PR / url: Scenario A with `gh` → `number`,`url` from `gh pr view <pr> --json number,url` (same call as step 1; reuse the result). Omit the `PR:` line when there is no PR (Scenario B) or when using local fallback without a resolved PR.
- files / +adds / -dels: gh → `additions`,`deletions`,`changedFiles` from `gh pr view`; local → `git diff --shortstat origin/<base>...HEAD`.
- merge-base / commits behind: local → `git merge-base origin/<base> HEAD` and `git rev-list --count HEAD..origin/<base>`; gh-only (no clone) → `gh api repos/{owner}/{repo}/compare/<base>...<head> --jq '.merge_base_commit.sha[0:7], .behind_by'`.

## 3. Enrich (Scenario A, when `gh` is available)

- Use the PR **title/body** to write the summary and sanity-check intent vs. implementation.
- Factor in existing discussion — skip already-resolved points, flag unresolved ones as risks:
  ```bash
  gh pr view <pr> --json comments                   # issue comments
  gh api repos/{owner}/{repo}/pulls/<pr>/comments    # inline review threads
  ```

## 4. Review (brief — you already know how)

Cover, in priority order: **correctness/bugs first**, then security, then quality (style, naming, tests, simplification). Review file-by-file for large diffs.

**Repo root for paths** — resolve once and use for every path in scope, comments, and saved output:

```bash
repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
```

All file paths must be **repo-root-relative** (e.g. `src/components/Button.tsx`), never cwd-relative or scoped to the folder being edited. Paths from `git diff` / `gh pr diff` are already correct — reuse them verbatim. When reading a file by absolute path, strip the `repo_root/` prefix before citing.

## 5. Output (chat)

The review record is the **scope header from step 2** followed by the review body. Print
(and, on save, store) them together.

Structure:

- Scope / Source header (same as step 2)
- `Summary:` — what the change does
- `Comments` — numbered list; line-specific items cite `repo-root/path:line` on the same line
- `Unresolved threads` — optional; other reviewers' open points with `path:line` when applicable
- `Verdict:` — required

Example comment output:

```markdown
1. [bug] src/components/Button.tsx:42 — Missing null check before `.map()`
2. [quality] src/utils/format.ts:12 — Extract repeated validation into a helper
3. (no line) — [release] Missing changeset entry
```

Cite locations as `path:line` (or `path:start-end` for a range). Path must be **repo-root-relative** (`src/components/Button.tsx:42`), never cwd-relative (`Button.tsx:42`).

**Comments** — one numbered item per suggestion with a `[severity]` tag (bug / security / quality / perf / test / release). PR-level items with no specific line use `(no line)`. Keep other reviewers' still-open threads in **Unresolved threads**, each with `path:line` when a line applies.

**Verdict** is required — pick one. It maps to GitHub's review actions and is advisory only (the skill never posts to GitHub):
- **approve** — good to merge, no blocking concerns.
- **approve with comments** — fine to merge; non-blocking notes attached.
- **comment** — feedback only; not approving or blocking (e.g. open questions to resolve first).
- **request changes** — should not merge until findings are addressed.

## 6. Save (only on confirmation)

After printing the review, **ask** "Save to `<dir>/<filename>`?". Write the file only if the user confirms.

- Location: `.goerwin/code-reviews/` at the repo root when inside a git repo; `~/.goerwin/code-reviews/` when no repo is found.
- Filename: `<yyyy-mm-dd>-<NN>-<branch>.<base>.md`. `NN` = next per-day index from `01`; `<branch>` = current git branch (Scenario A: the PR's head branch); sanitize `/`→`-` within each branch name.
  ```bash
  if git rev-parse --git-dir >/dev/null 2>&1; then
    root=$(git rev-parse --show-toplevel)
    dir="$root/.goerwin/code-reviews"
  else
    dir="$HOME/.goerwin/code-reviews"
  fi
  d=$(date +%F); mkdir -p "$dir"
  last=$(ls "$dir" 2>/dev/null | sed -nE "s/^$d-([0-9]{2})-.*/\1/p" | sort -n | tail -1)
  n=$(printf '%02d' $(( 10#${last:-0} + 1 )))
  up=$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null); branch=${up#*/}        # PR/remote head (Scenario A); strips remote prefix
  branch=${branch:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'no-repo')}   # fall back to local branch name
  br=$(printf '%s' "$branch" | tr '/' '-'); b=$(printf '%s' "<base>" | tr '/' '-')
  file="$dir/$d-$n-$br.$b.md"   # e.g. .goerwin/code-reviews/2026-06-22-01-feat-button.main.md
  ```
  Write the same markdown shown in chat (scope header + review) to `$file`.

## Edge cases
- No merge-base (unrelated histories) → stop, explain.
- No changes / `head == base` → report and stop.
- PR closed/merged → still reviewable; note the state.
- Dirty working tree → review committed changes; note uncommitted ones exist.
