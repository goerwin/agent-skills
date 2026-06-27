#!/usr/bin/env bash
#
# Print the path for saving a code review markdown file.
#
# Usage: review-save-path.sh <base-branch>
#   e.g. review-save-path.sh main
#
# Output: absolute path to write (directory is created). Does not write the file.

set -euo pipefail

base="${1:-}"
[ -n "$base" ] || { echo "usage: $(basename "$0") <base-branch>" >&2; exit 2; }

if git rev-parse --git-dir >/dev/null 2>&1; then
  root=$(git rev-parse --show-toplevel)
  dir="$root/.goerwin/code-reviews"
else
  dir="$HOME/.goerwin/code-reviews"
fi

d=$(date +%F)
mkdir -p "$dir"
last=$(ls "$dir" 2>/dev/null | sed -nE "s/^$d-([0-9]{2})-.*/\1/p" | sort -n | tail -1)
n=$(printf '%02d' $(( 10#${last:-0} + 1 )))

up=$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null) || true
branch=${up#*/}
branch=${branch:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'no-repo')}
br=$(printf '%s' "$branch" | tr '/' '-')
b=$(printf '%s' "$base" | tr '/' '-')

printf '%s/%s-%s-%s.%s.md\n' "$dir" "$d" "$n" "$br" "$b"
