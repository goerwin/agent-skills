---
name: code-review
description: Scoped, merge-base-correct review of a GitHub PR or branch changes — reviews only what the PR actually introduced (never stale/unrelated files). Invoke explicitly; do not auto-trigger from review requests.
---

# Code Review

Review **only what the PR/branch introduced**, then report findings. Never modify the branch; never post to GitHub.

## THE RULE (read first)

Always diff against the **merge-base** — three-dot `base...head` — **never** two-dot `base head`.
Two-dot also shows files the *target* branch changed after this branch diverged, so a stale branch drags in unrelated files. Three-dot shows only this branch's changes and matches GitHub's "Files changed" tab even when the branch is behind target.

## 1. Resolve scope

Decide what to review:

- A PR number/URL was given, **or** an open PR exists for the current branch → **Scenario A** (PR is source of truth).
  Detect an open PR for the current branch:
  `gh pr view --json number,baseRefName,headRefName 2>/dev/null`
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

## 2. Preview scope — confirm before reviewing

Print the scope header + changed-file list, then **pause** so the user can confirm the files match what they expect (or correct the base/branch). Review only after they confirm.

```
Scope: <head> -> <base> | merge-base <short-sha> | <N> files, +<adds>/-<dels> | <X> commits behind <base>
Source: GitHub (gh pr diff) | local fallback (gh unavailable) | branch-vs-branch
Files:
  <status> <path>
  ...
```

Where the values come from:
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

Cover, in priority order: **correctness/bugs first**, then security, then quality/style/naming/tests/simplification. Review file-by-file for large diffs.

## 5. Output (chat)

The review record is the **scope header from step 2** followed by the review body. Print
(and, on save, store) them together:

```
<same Scope / Source header as step 2>

Summary: <what the change does>

Comments
  1. <path>:<line> — [severity] <comment>
  2. <path>:<line> — [severity] <comment>
  3. (no line)     — [severity] <PR-level comment, e.g. missing changeset>

Unresolved threads (other reviewers)
  - <path>:<line> — [reviewer] <their point> → <your take>

Verdict: <approve | approve with comments | comment | request changes> — <one-line reason>
```

**Comments** — one numbered item per suggestion: `path:line` → a `[severity]` tag (e.g. bug / security / quality / perf / test / release) → the comment. PR-level items with no specific line use `(no line)`. Keep other reviewers' still-open threads in the **separate** Unresolved threads section, each with your take.

**Verdict** is required — pick one. It maps to GitHub's review actions and is advisory only (the skill never posts to GitHub):
- **approve** — good to merge, no blocking concerns.
- **approve with comments** — fine to merge; non-blocking notes attached.
- **comment** — feedback only; not approving or blocking (e.g. open questions to resolve first).
- **request changes** — should not merge until findings are addressed.

## 6. Save (only on confirmation)

After printing the review, **ask** "Save to `<dir>/<filename>`?". Write the file only if the user confirms.

- Location: `.goerwin/code-reviews/` at the repo root when inside a git repo; `~/.goerwin/code-reviews/` when no repo is found.
- Filename: `<yyyy-mm-dd>-<NN>-<branch>:<base>.md`. `NN` = next per-day index from `01`; `<branch>` = current git branch (Scenario A: the PR's head branch); sanitize `/`→`-` within each branch name.
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
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'no-repo')   # head branch; in Scenario A use the PR's headRefName
  br=$(printf '%s' "$branch" | tr '/' '-'); b=$(printf '%s' "<base>" | tr '/' '-')
  file="$dir/$d-$n-$br:$b.md"   # e.g. .goerwin/code-reviews/2026-06-22-01-feat-button:main.md
  ```
  Write the same markdown shown in chat (scope header + review) to `$file`.

## Edge cases
- No merge-base (unrelated histories) → stop, explain.
- No changes / `head == base` → report and stop.
- PR closed/merged → still reviewable; note the state.
- Dirty working tree → review committed changes; note uncommitted ones exist.
