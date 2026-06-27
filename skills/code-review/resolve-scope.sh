#!/usr/bin/env bash
#
# Resolve code-review scope and print a preview block for user confirmation.
#
# Usage:
#   resolve-scope.sh              # Path 2 → 1 or 3: detect PR for current branch, else branch-vs-default
#   resolve-scope.sh <pr-url|#n>  # Path 1: PR is source of truth
#
# Requires: git (inside a repo), gh CLI (authenticated).
# Diff semantics: three-dot merge-base (matches GitHub "Files changed").

set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

require_gh() {
  command -v gh >/dev/null || die "gh CLI not found (install and run 'gh auth login')"
  gh auth status >/dev/null 2>&1 || die "gh not authenticated (run 'gh auth login')"
}

require_git_repo() {
  git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository"
}

default_base_branch() {
  local base
  base=$(git remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p' | head -1)
  [ -n "$base" ] || die "could not determine default branch from origin (set upstream or pass a PR URL)"
  printf '%s' "$base"
}

# Upstream tracking branch name (remote prefix stripped); falls back to local branch.
detect_head_ref() {
  local up head
  up=$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null) || true
  head=${up#*/}
  head=${head:-$(git branch --show-current)}
  [ -n "$head" ] || die "could not determine current branch"
  printf '%s' "$head"
}

repo_slug() {
  gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null \
    || die "could not resolve GitHub repo (is origin a GitHub remote?)"
}

# --- Path 1: PR is source of truth -------------------------------------------------
scope_from_pr() {
  local pr_ref="$1" path_label="${2:-pr-url}"
  local slug number url title state base head adds dels files mb behind

  slug=$(repo_slug)
  number=$(gh pr view "$pr_ref" --json number -q .number) \
    || die "could not read PR $pr_ref"
  url=$(gh pr view "$pr_ref" --json url -q .url)
  title=$(gh pr view "$pr_ref" --json title -q .title)
  state=$(gh pr view "$pr_ref" --json state -q .state)
  base=$(gh pr view "$pr_ref" --json baseRefName -q .baseRefName)
  head=$(gh pr view "$pr_ref" --json headRefName -q .headRefName)
  adds=$(gh pr view "$pr_ref" --json additions -q .additions)
  dels=$(gh pr view "$pr_ref" --json deletions -q .deletions)
  files=$(gh pr view "$pr_ref" --json changedFiles -q .changedFiles)

  mb=$(gh api "repos/$slug/compare/${base}...${head}" -q .merge_base_commit.sha 2>/dev/null) \
    || die "could not compare $base...$head on GitHub"
  behind=$(gh api "repos/$slug/compare/${base}...${head}" -q .behind_by)
  [ -n "$mb" ] || die "no merge-base between $base and $head (unrelated histories?)"

  printf 'Path: %s\n' "$path_label"
  printf 'Scope: %s -> %s | merge-base %s | %s files, +%s/-%s | %s commits behind %s\n' \
    "$head" "$base" "${mb:0:7}" "$files" "$adds" "$dels" "$behind" "$base"
  printf 'PR: #%s %s (%s)\n' "$number" "$url" "$state"
  printf 'Title: %s\n' "$title"
  printf 'Source: GitHub (gh pr diff)\n'
  printf 'Files:\n'
  gh api "repos/$slug/compare/${base}...${head}" \
    --template '{{range .files}}  {{.status}} {{.filename}}{{"\n"}}{{end}}'
}

# --- Path 3: current branch vs default base (local merge-base) -----------------------
scope_from_branch() {
  local base head mb behind shortstat files adds dels

  base=$(default_base_branch)
  head=$(git branch --show-current)
  [ -n "$head" ] || die "could not determine current branch"
  [ "$head" != "$base" ] || die "current branch is the base branch ($base) — nothing to review"

  git fetch --quiet origin

  mb=$(git merge-base "origin/$base" HEAD 2>/dev/null) \
    || die "no merge-base between origin/$base and HEAD (unrelated histories?)"
  behind=$(git rev-list --count HEAD.."origin/$base" 2>/dev/null || echo 0)

  shortstat=$(git diff --shortstat "origin/$base...HEAD" 2>/dev/null || true)
  files=$(printf '%s' "$shortstat" | sed -nE 's/ ([0-9]+) files? changed.*/\1/p')
  files=${files:-0}
  adds=$(printf '%s' "$shortstat" | sed -nE 's/.* ([0-9]+) insertions?\(\+\).*/\1/p')
  adds=${adds:-0}
  dels=$(printf '%s' "$shortstat" | sed -nE 's/.* ([0-9]+) deletions?\(-\).*/\1/p')
  dels=${dels:-0}

  printf 'Path: branch\n'
  printf 'Scope: %s -> %s | merge-base %s | %s files, +%s/-%s | %s commits behind %s\n' \
    "$head" "$base" "${mb:0:7}" "$files" "$adds" "$dels" "$behind" "$base"
  printf 'Source: branch-vs-branch (origin/%s...HEAD)\n' "$base"
  printf 'Files:\n'
  if [ "$files" != "0" ]; then
    git diff --name-status "origin/$base...HEAD" | sed 's/^/  /'
  fi
}

# --- Path 2: try PR for upstream head, else path 3 ---------------------------------
main() {
  require_gh
  require_git_repo

  if [ "${1:-}" != "" ]; then
    scope_from_pr "$1" "pr-url"
    exit 0
  fi

  local head_ref pr_num
  head_ref=$(detect_head_ref)
  if pr_num=$(gh pr view "$head_ref" --json number -q .number 2>/dev/null); then
    scope_from_pr "$pr_num" "pr-detected"
    exit 0
  fi

  scope_from_branch
}

main "$@"
