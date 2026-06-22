# goerwin/skills

Personal agent skills for coding assistants — installable with [npx skills](https://github.com/vercel-labs/skills).

## Skills

| Skill                                      | Description                                                                                                                                                                                                                                                                                                                                 |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [code-review](skills/code-review/SKILL.md) | Scoped, merge-base-correct review of a GitHub PR or branch — reviews only what the change actually introduced. Invoke with `/code-review` in Cursor. Previews scope for confirmation, then optionally saves to `.goerwin/code-reviews/` (in a repo) or `~/.goerwin/code-reviews/` (no repo), e.g. `2026-06-22-01-feat-button:main.md`. |

## Install

Requires [Node.js](https://nodejs.org/) (for `npx`). The CLI supports Cursor, Claude Code, Codex, and [many other agents](https://github.com/vercel-labs/skills#supported-agents).

### All skills

```bash
npx skills add goerwin/skills
```

### One skill

```bash
npx skills add goerwin/skills --skill code-review
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
npx skills update code-review
npx skills remove code-review
npx skills list
```

## Links

- [skills CLI](https://github.com/vercel-labs/skills) — `npx skills`
- [skills.sh](https://skills.sh) — discover more skills
