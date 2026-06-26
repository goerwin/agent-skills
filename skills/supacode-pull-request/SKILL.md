---
name: supacode-pull-request
description: Use when explicitly asked to create a supacode worktree for a GitHub pull request, given a PR URL (e.g. https://github.com/goerwin/dotfiles/pull/408). Invoke explicitly; do not auto-trigger.
disable-model-invocation: true
---

# Supacode Pull Request

Create a [supacode](https://github.com/supabitapp/supacode) worktree for a GitHub PR, named so supacode's sidebar shows a `pr-<n>-…` label. Run it from a supacode tab for the PR's repo.

## How supacode names worktrees (why this exists)

supacode's sidebar shows the **local git branch name**, not the folder name. So the worktree's local branch is named `pr-<n>-<headRef-with-slashes-as-dashes>` and is set to **track the real PR branch** on origin. `git pull`/`git push` then update the PR.

Example — PR #408 with head `feat/login-form`:
- local branch + folder: `pr-408-feat-login-form`  (sidebar label)
- upstream: `origin/feat/login-form`  (the actual PR branch)
- prompt reads: `… on 🌱 pr-408-feat-login-form:feat/login-form`

## Usage

Run the bundled script with a full PR URL, from inside the repo's supacode tab:

```bash
"$(dirname "$0")/worktree-from-pr.sh" https://github.com/goerwin/dotfiles/pull/408
```

The script at `worktree-from-pr.sh` (next to this file):
1. Parses the PR number from the URL.
2. Reads the PR head branch + fork status via `gh pr view` (accepts the URL directly).
3. Targets the current repo via `$SUPACODE_REPO_ID` (the repo of the tab it runs in — no repo lookup).
4. Creates the worktree with `supacode repo worktree-new --branch pr-<n>-… --base origin/<headRef> --name pr-<n>-… --fetch`, then sets the branch's upstream to the real PR branch.

Re-running for the same PR is safe: if the worktree already exists, the script reports it and exits without recreating.

## Requirements

- `gh` CLI, authenticated (`gh auth login`).
- supacode CLI (`/Applications/supacode.app/Contents/Resources/bin/supacode`, usually on `PATH` as `supacode`).
- Run inside a supacode tab for the PR's repo, so `$SUPACODE_REPO_ID` is set. The PR must belong to that repo.

## Edge cases

- **Fork PRs** (`isCrossRepository: true`): the head branch isn't on origin, so the script fetches `refs/pull/<n>/head` and bases the worktree on `FETCH_HEAD`. Upstream isn't set (no matching origin branch); push back via the fork remote or `gh pr checkout`.
- **`$SUPACODE_REPO_ID` unset** (not run inside supacode) → error.
- **Worktree already exists** → reports it and exits without recreating.
