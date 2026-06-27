#!/usr/bin/env bash
#
# Fetch PR discussion: formal reviews, inline threads (resolved/open), conversation.
#
# Usage: fetch-discussion.sh <pr-url|#n>
#
# Output: human-readable block for the agent (paths 1–2 only, after scope confirmed).
# Requires: gh CLI (authenticated), jq (bundled with gh).

set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

require_gh() {
  command -v gh >/dev/null || die "gh CLI not found (install and run 'gh auth login')"
  gh auth status >/dev/null 2>&1 || die "gh not authenticated (run 'gh auth login')"
  command -v jq >/dev/null || die "jq not found (required for discussion parsing)"
}

main() {
  local pr_ref="${1:-}"
  [ -n "$pr_ref" ] || die "usage: $(basename "$0") <pr-url|#n>"

  require_gh

  local owner repo number
  number=$(gh pr view "$pr_ref" --json number -q .number) \
    || die "could not read PR $pr_ref"

  if [[ "$pr_ref" =~ github\.com/([^/]+)/([^/]+)/pull/ ]]; then
    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"
  else
    owner=$(gh pr view "$pr_ref" --json headRepositoryOwner -q .headRepositoryOwner.login) \
      || die "could not resolve PR owner"
    repo=$(gh pr view "$pr_ref" --json headRepository -q .headRepository.name) \
      || die "could not resolve PR repo name"
  fi
  [ -n "$owner" ] && [ -n "$repo" ] || die "could not resolve PR repository"

  local query
  query='query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        body
        reviewDecision
        reviews(first: 20) {
          nodes { author { login } state body submittedAt }
        }
        reviewThreads(first: 100) {
          totalCount
          nodes {
            isResolved
            path
            line
            originalLine
            comments(first: 1) {
              nodes { author { login } body }
            }
          }
        }
        comments(first: 30) {
          totalCount
          nodes { author { login } body createdAt }
        }
      }
    }
  }'

  local data
  data=$(gh api graphql -f query="$query" -f owner="$owner" -f repo="$repo" -F number="$number") \
    || die "could not fetch PR discussion from GitHub"

  # --- format with jq -----------------------------------------------------------
  jq -r '
    def oneline: gsub("\r"; "") | gsub("\n+"; " ") | gsub("  +"; " ");
    def trunc($n): oneline | if length > $n then .[0:$n] + "…" else . end;
    def thread_loc: (if .line then .line elif .originalLine then .originalLine else "?" end | tostring);
    def thread_row:
      . as $t
      | ($t.comments.nodes[0]) as $c
      | select($c != null)
      | "  \($t.path):\($t | thread_loc) — @\($c.author.login): \($c.body | trunc(160))";

    .data.repository.pullRequest as $pr
    | ($pr.reviewThreads.nodes // []) as $threads
    | ($threads | map(select(.isResolved)) | length) as $resolved
    | ($threads | map(select(.isResolved | not)) | length) as $open
    | ($pr.comments.totalCount // 0) as $conv_total
    | [
        "Discussion: \($resolved) resolved, \($open) open, \($conv_total) conversation comments | reviewDecision: \($pr.reviewDecision // "NONE")",
        "",
        (if ($pr.body // "") | length > 0 then
          ["PR body:", "  \($pr.body | trunc(300))", ""]
        else [] end),
        "Formal reviews:",
        (if ($pr.reviews.nodes | length) == 0 then
          ["  (none)"]
        else
          $pr.reviews.nodes[]
          | "  [\(.state)] @\(.author.login) (\(.submittedAt[0:10])): \(.body | trunc(160))"
        end),
        "",
        "Unresolved threads:",
        (if $open == 0 then ["  (none)"]
         else $threads[] | select(.isResolved | not) | thread_row
         end),
        "",
        "Resolved threads (context — do not re-raise unless code regressed):",
        (if $resolved == 0 then ["  (none)"]
         else $threads[] | select(.isResolved) | thread_row
         end),
        "",
        "Conversation comments:",
        (if ($pr.comments.nodes | length) == 0 then ["  (none)"]
         else $pr.comments.nodes[]
          | "  @\(.author.login) (\(.createdAt[0:10])): \(.body | trunc(160))"
        end)
      ]
    | flatten
    | .[]
  ' <<<"$data"
}

main "$@"
