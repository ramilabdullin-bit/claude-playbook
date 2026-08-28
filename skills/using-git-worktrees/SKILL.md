---
name: using-git-worktrees
description: Use when starting a non-trivial change on a repo that already has other in-progress work you don't want to disturb — a parallel feature, an experiment you're not sure will land, or any change you want isolated from the working tree someone (or some running process) is actively relying on. Also use for "изолируй эту правку", "work on this in a separate branch without touching my current changes", "parallel onboarding of the next X". NOT needed for a normal single-threaded edit-test-commit cycle.
---

# Isolating parallel work with git worktrees

`git worktree` checks out a second (or third...) working directory from
the same repository, on its own branch, sharing the same `.git` history —
edits in one worktree never touch the files in another, and neither does
a `git checkout` in one affect the other. This matters specifically on
this server because several projects here are **live processes with a
working tree they read from directly** (a bot's `venv`/`.env` sit next to
its `bot.py` in the same directory a systemd service is running out of) —
switching branches or leaving half-edited files in that directory while
also trying to work on something else in it is a real, not hypothetical,
risk of breaking a running bot mid-edit.

## When this earns its overhead

- Onboarding a new item in a series (a new Sber company, a new marketplace
  client, a new bank integration) while a *different* change to the same
  repo is also in flight and shouldn't see half-finished state from the
  other.
- Trying something that might not pan out, without disturbing the
  branch/directory a running service is currently serving from.
- Any case where "two things being edited in the same directory at once"
  is the actual risk, not just a hypothetical — most single-person,
  single-task edits on this server do **not** need this; don't reach for
  it by default.

## How

```bash
cd /root/tg-bank-bot
git worktree add ../tg-bank-bot-sber-portal -b sber-portal-onboarding
cd ../tg-bank-bot-sber-portal
# separate venv needed here too — it's a fresh checkout, not a symlink
python3 -m venv venv && venv/bin/pip install -r requirements.txt
```

The new directory is a full independent checkout — copy over whatever the
`.gitignore`'d runtime state needs (`.env`, credential directories) from
the original, don't assume it's shared. When done:

```bash
cd /root/tg-bank-bot
git worktree remove ../tg-bank-bot-sber-portal   # after merging/discarding
```

`git worktree list` from any of the worktrees shows every active one tied
to this repo.

## What NOT to do with it

- Don't leave a worktree's own copy of `.env`/credential files with looser
  permissions than the original — chmod 600 applies per-copy, it doesn't
  travel automatically ([[secret-file-guard]] blocks Claude's own
  Read/Edit/Write on it regardless of which directory it lives in, but
  file permissions are a separate, per-file thing to redo).
- Don't point a bot's actual systemd `ExecStart`/`WorkingDirectory` at a
  worktree meant to be temporary — merge the finished work back into the
  main checkout first, worktrees are for development, not for becoming
  the permanent deployment path by accident.
- A worktree still shares the same `.git` object database as the main
  checkout — a `git worktree remove` doesn't delete commits already made
  on that branch, only the extra working directory. Merge or explicitly
  delete the branch separately if it's truly meant to be discarded.
