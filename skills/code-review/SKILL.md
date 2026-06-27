---
name: code-review
description: Use when explicitly asked to review a GitHub PR or branch's changes. Reviews only what the branch introduced via merge-base diff, previews scope for confirmation, then reports findings without modifying the branch or posting to GitHub.
disable-model-invocation: true
---

# Code Review

Review **only what the change introduced**, then report findings. Never modify the branch; never post to GitHub.

**Requires:** `gh` (authenticated), `jq`, git repo on disk.

## Paths

| Path | When | Scope |
|------|------|-------|
| **1 — PR URL** | User passes a PR URL or number | That PR vs its base branch (GitHub) |
| **2 — PR detected** | No PR URL; open PR found for upstream head | Same as path 1 |
| **3 — Branch** | No PR URL; no open PR for this branch | Current branch vs repo default branch (`origin` HEAD) |

Path 2 looks up the PR by **upstream tracking branch name** (remote prefix stripped), not the local branch name — so `pr-408-feat-login-form` tracking `origin/feat/login-form` still finds PR #408. Falls back to local branch name when there is no upstream.

## Hard gates (never skip)

1. **After scope preview** — print the preview, ask the user to confirm, **end your turn and wait**. Do not read or analyze any changed file until they confirm.
2. **Before save** — ask before writing the review to disk.

| Rationalization | Reality |
|---|---|
| "I'll read files while they decide" | Reading a changed file is reviewing. Wait for confirmation. |
| "Scope is obviously right" | The gate is for the user, not you. |
| "Small PR, skip the pause" | Size never waives the gate. |

## 1. Resolve scope

Run `resolve-scope.sh` (next to this file) from inside the target repo:

```bash
# Path 1 — PR URL or number
/path/to/code-review/resolve-scope.sh https://github.com/org/repo/pull/123

# Path 2 or 3 — auto-detect
/path/to/code-review/resolve-scope.sh
```

On error (no `gh`, not authed, not a git repo, unrelated histories, current branch is the base branch): report the error and stop. There is no git-only fallback.

**Diff rule:** scope always uses merge-base semantics (`base...head`, three-dot). Never two-dot `base head` — that pulls in unrelated changes from a stale target branch.

## 2. Preview scope — STOP

Print the script output verbatim, then ask: **"Confirm this scope?"**

Until the user confirms, you MUST NOT read changed files, fetch diffs for analysis, enrich, or review. If they correct base/branch/PR, re-run the script and stop again.

## 3. Existing discussion (paths 1 and 2 only)

After scope is confirmed, fetch PR discussion **before** reading the diff:

```bash
/path/to/code-review/fetch-discussion.sh <pr-url|#n>
```

Print the output for context. Then apply these rules during review:

| Thread state | Action |
|---|---|
| **Unresolved** | Verify against current diff. Include still-valid points in `Unresolved threads`. Do not duplicate in `Comments`. |
| **Resolved** | Do not re-raise as new findings. Spot-check the cited line; if still broken, add to `Comments` as a new `[bug]` (resolved ≠ fixed). |
| **Conversation / formal reviews** | Use for intent and blocking context (`reviewDecision`, `CHANGES_REQUESTED`). |

Skip this step on path 3 (no PR).

## 4. Review

Priority: **correctness/bugs** → security → quality (style, naming, tests).

Fetch the diff after discussion context:

```bash
gh pr diff <pr>              # paths 1–2
git diff origin/<base>...HEAD -- <path>   # path 3, per file
```

Resolve repo root once: `repo_root=$(git rev-parse --show-toplevel)`. Cite paths repo-root-relative (`src/foo.ts:42`).

## 5. Output (chat)

Scope header (from step 2) + review body:

- `Summary:` — what the change does
- `Discussion:` — one line: `N resolved, M open` (from fetch-discussion); omit on path 3
- `Comments` — numbered; `[severity]` tags: bug / security / quality / perf / test / release; line cites as `path:line`; only **new** findings (not duplicates of open threads)
- `Unresolved threads` — required when any exist; other reviewers' open inline points with `path:line` and status (still valid / addressed / needs author)
- `Verdict:` — required: **approve** | **approve with comments** | **comment** | **request changes**; factor in open threads and `reviewDecision`

Example comment:

```markdown
1. [bug] src/components/Button.tsx:42 — Missing null check before `.map()`
2. [quality] src/utils/format.ts:12 — Extract repeated validation into a helper
3. (no line) — [release] Missing changeset entry
```

## 6. Save (on confirmation only)

Ask: "Save to `<path>`?" — write only if confirmed.

```bash
/path/to/code-review/review-save-path.sh <base-branch>
```

Writes the same markdown shown in chat. Filename pattern: `YYYY-MM-DD-NN-<branch>.<base>.md` under `.goerwin/code-reviews/` (repo) or `~/.goerwin/code-reviews/` (no repo).

## Edge cases

- **No changes** — report and stop after scope preview (user may still want an empty review).
- **PR closed/merged** — still reviewable; note state from scope output.
- **Dirty working tree** — review committed scope only; note uncommitted changes exist.
- **Fork PR** — path 1/2 via `gh` handles fork heads correctly.
