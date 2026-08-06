---
name: onboard-new-project
description: Use when a project directory on this server has no CLAUDE.md/.git yet (or the user asks to "set up Claude Code for this project", "git init this", "подготовь проект для Клода") — sets up CLAUDE.md, .gitignore, and a git repo the same way it was done for e-comportal, telegram-claude-bot, marketplace-agents and agents.
tools: Read, Glob, Grep, Bash, Write
---

# Onboard a new project on this server

Checklist used the first time Claude Code works seriously in a project
directory here. Skips any step already done (check before acting).

## 1. Read before writing anything

- `ls -la <dir>` — what's actually there (source files, `.env`, `venv/`,
  data/state dirs, existing `.git`/`.claude`/`CLAUDE.md`).
- Read the main source files enough to describe architecture accurately —
  don't guess. If the project already has a memory entry under
  `/root/.claude/projects/-root/memory/`, read it too — it may already have
  answers a fresh code read would take longer to re-derive.

## 2. Write CLAUDE.md

Not a directory listing — capture what a fresh session would otherwise have
to re-derive by reading code: purpose, architecture, where state lives, what
talks to what (other projects/services on this server, external APIs),
non-obvious constraints or safety rules, and exact ops commands (restart,
logs, deploy). See `/root/telegram-claude-bot/CLAUDE.md` and
`/root/marketplace-agents/CLAUDE.md` for the level of detail expected —
tables for routes/commands, explicit "known limitation" callouts for things
like missing auth or rate limits, not just prose.

## 3. Write .gitignore before git init — never after

Always exclude, adjusted to what actually exists in the project:
```
.env
venv/
.venv/
__pycache__/
*.pyc
.claude/settings.local.json
```
Plus anything project-specific holding live credentials or session state:
`cookies*.json`, `*token*.json`, `*_cookies.json`, log files, a `data/`
directory of runtime JSON state (owner/session/mode files — these are
generated state, not source, same reasoning as ignoring `venv/`).

## 4. git init, then verify before committing

```bash
git init
git add -A
git status --short   # READ this output — do not skip
```
Confirm nothing matching `.env`, `cookies`, `token`, `password`, `secret`,
`.pem`, `.key` appears in the staged list. If anything looks like a
credential, stop and fix `.gitignore` before committing — do not `git rm
--cached` after a commit as the fix, prevent it from being staged at all.

Global git identity is already configured on this machine
(`Ramil Abdullin <ramil.abdullin@gmail.com>`) — no need to set it per repo.

## 5. Commit

```bash
git commit -m "Initial commit: <one-line description of the project>"
```
Only commit when the user has asked to (or this skill was invoked
specifically to do onboarding, which implies it) — see the standing rule:
never commit unasked in an unrelated task.

## 6. Tell the user what's now covered

Name the CLAUDE.md file and confirm the git status is clean. Don't push
anywhere — this repo is local-only unless the user separately asks to wire
it to a remote (see the `secret-file-guard` skill's neighbor concerns don't
apply here, but pushing is its own confirmation-worthy step regardless).
