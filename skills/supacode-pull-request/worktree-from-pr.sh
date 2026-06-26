#!/usr/bin/env bash
#
# Create a supacode worktree for a GitHub pull request.
# Run this from inside a supacode tab for the PR's repo (uses $SUPACODE_REPO_ID).
#
# Usage: worktree-from-pr.sh <pr-url>
#   e.g. worktree-from-pr.sh https://github.com/goerwin/dotfiles/pull/408
#
# The local branch (and worktree folder) is named  pr-<n>-<headRef-with-slashes-as-dashes>;
# supacode's sidebar shows the local branch name. The branch tracks the real PR branch on
# origin, so pull/push update the PR.
#
# Why a script and not one supacode command: supacode's CLI has no GitHub-PR awareness
# (`repo worktree-new` only takes --branch/--base/--name), so we translate PR# -> head branch
# with `gh`, then call worktree-new for the current repo.
#
# Requires: gh (authenticated), the supacode CLI, and $SUPACODE_REPO_ID (set inside supacode).

set -euo pipefail

SC=$(command -v supacode || echo /Applications/supacode.app/Contents/Resources/bin/supacode)
[ -x "$SC" ] || { echo "error: supacode CLI not found" >&2; exit 1; }
command -v gh >/dev/null || { echo "error: gh CLI not found (install it and run 'gh auth login')" >&2; exit 1; }

# --- PR number from the URL (gh reads the rest from the URL itself) -----------
url="${1:-}"
[[ "$url" =~ ^https?://[^/]+/[^/]+/[^/]+/pull/([0-9]+) ]] \
  || { echo "usage: $(basename "$0") <pr-url>   e.g. https://github.com/goerwin/dotfiles/pull/408" >&2; exit 2; }
pr="${BASH_REMATCH[1]}"

# --- PR head branch + fork flag -----------------------------------------------
meta=$(gh pr view "$url" --json headRefName,isCrossRepository -q '[.headRefName,.isCrossRepository]|@tsv') \
  || { echo "error: gh could not read $url (auth / network / URL?)" >&2; exit 1; }
IFS=$'\t' read -r branch fork <<<"$meta"
[ -n "$branch" ] || { echo "error: empty head branch from gh" >&2; exit 1; }

wtname="pr-${pr}-${branch//\//-}"   # local branch + folder name (shown in supacode's sidebar)

# --- Current repo: supacode sets $SUPACODE_REPO_ID (worktree-new defaults to it) ---
repo_id="${SUPACODE_REPO_ID:-}"
[ -n "$repo_id" ] || { echo "error: \$SUPACODE_REPO_ID unset — run this inside a supacode repo tab" >&2; exit 1; }
repo_path=$(printf '%b' "${repo_id//%/\\x}")   # decode the repo ID (%2F -> /)
wt="$HOME/.supacode/repos/$(basename "$repo_path")/$wtname"

# --- Already created? Report and stop -----------------------------------------
if [ -d "$wt" ]; then
  echo "Worktree already exists: $wt"
  git -C "$wt" status -sb | head -1
  exit 0
fi

# --- Create the worktree ------------------------------------------------------
echo "PR #$pr → branch '$wtname' tracking origin/$branch (fork: $fork)"
if [ "$fork" = true ]; then
  # Fork PR: head branch isn't on origin — fetch the PR head ref directly.
  git -C "$repo_path" fetch origin "pull/$pr/head"
  "$SC" repo worktree-new --branch "$wtname" --base FETCH_HEAD --name "$wtname"
else
  "$SC" repo worktree-new --branch "$wtname" --base "origin/$branch" --name "$wtname" --fetch
fi

# --- Creation is async: wait for the folder, then track the real PR branch ----
for _ in $(seq 1 20); do [ -d "$wt" ] && break; sleep 1; done
[ -d "$wt" ] || { echo "Requested; folder not visible yet at $wt (supacode still initializing)." >&2; exit 0; }
[ "$fork" = true ] || git -C "$wt" branch --set-upstream-to="origin/$branch" >/dev/null 2>&1 || true
echo "Ready: $wt"
git -C "$wt" status -sb | head -1
