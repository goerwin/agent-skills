# Agent Skills

Personal agent skills for coding assistants — installable with [npx skills](https://github.com/vercel-labs/skills).

## Skills

| Skill                                      | Description                                                                                                                                                                                                                                                                                                                                 |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [code-review](skills/code-review/SKILL.md) | Scoped, merge-base-correct review of a GitHub PR or branch — reviews only what the change actually introduced. Invoke with `/code-review` in Cursor. Previews scope for confirmation, then optionally saves to `.goerwin/code-reviews/` (in a repo) or `~/.goerwin/code-reviews/` (no repo), e.g. `2026-06-22-01-feat-button:main.md`. Does not auto-trigger. |
| [plan](skills/plan/SKILL.md) | Manage implementation plans in `.goerwin/plans/`. Invoke with `/plan` in Cursor. Checks for existing plans, creates or updates with user approval, asks about branch/worktree before implementing. Does not auto-trigger. |
| [supacode-pull-request](skills/supacode-pull-request/SKILL.md) | Create a supacode worktree for a GitHub PR from a PR URL. Invoke with `/supacode-pull-request`. Names the local branch `pr-<n>-<headRef-dashed>` (shown in supacode's sidebar) tracking the real PR branch on origin, so pull/push update the PR. Run inside the repo's supacode tab. Does not auto-trigger. |

## Install

Requires [Node.js](https://nodejs.org/) (for `npx`). The CLI supports Cursor, Claude Code, Codex, and [many other agents](https://github.com/vercel-labs/skills#supported-agents).

### All skills

```bash
npx skills add goerwin/skills
```

### One skill

```bash
npx skills add goerwin/skills --skill <skill>
```

### Global install (available in every project)

```bash
npx skills add goerwin/skills -g
```

### List skills without installing

```bash
npx skills add goerwin/skills --list
```

### Install from a local clone

```bash
git clone https://github.com/goerwin/skills.git
npx skills add ./skills
```

## Update & remove

```bash
npx skills update <skill>
npx skills remove <skill>
npx skills list
```

## Links

- [skills CLI](https://github.com/vercel-labs/skills) — `npx skills`
- [skills.sh](https://skills.sh) — discover more skills
