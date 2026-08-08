---
name: trim-claude-md
description: Use when a project's CLAUDE.md has grown past ~200 lines, or when about to append another incident/finding entry to one that's already long. Also use for "CLAUDE.md too big", "should this go in CLAUDE.md or a skill", "clean up CLAUDE.md". Triggers on noticing a CLAUDE.md edit is adding historical/incident content rather than a standing convention.
---

# Keeping CLAUDE.md lean as a project accumulates history

CLAUDE.md loads in full, every session, whether or not that session needs
it — that's what makes it powerful (Claude always sees it) and expensive
(it's fixed overhead on every single call). Anthropic's own guidance is to
keep it under ~200 lines and move everything else out. On this server that
guidance gets violated by default: every incident this playbook tells you
to document ("после любой правки — задокументировать в CLAUDE.md") lands
in the same file as the standing conventions, and the file only grows.

Check `wc -l <project>/CLAUDE.md` before adding another entry — if it's
already past ~200 lines, split before appending, don't just keep growing
it.

## Two kinds of content end up in the same file — separate them

1. **Standing conventions** — true every session, small, stable: build
   commands, directory layout, access patterns, hard rules ("never do
   X"). This is what CLAUDE.md is actually for. Keep this at the top,
   keep it short.
2. **Incident/finding log** — "on 2026-08-08 we found X was broken
   because Y, fixed by Z". True once, useful as a reference when
   something similar comes up again, not needed in every session's
   context. This is what tends to balloon a CLAUDE.md on this server,
   because the playbook policy says to document fixes, and CLAUDE.md is
   the default place to put them.

## Where to move the incident log

- **A dedicated reference skill** (e.g. `known-issues-<project>` or
  split by area, `wp-integration-notes`) if the entries are the kind of
  thing you'd search for later ("why does X work this way") rather than
  something every session must know upfront. Skills load on-demand —
  zero cost in sessions that don't need them, full detail when they do.
- **`.claude/rules/<topic>.md` with `paths:` frontmatter** if the content
  is specific to a subdirectory or file type (e.g. rules that only
  matter when touching `tools/wp.py` specifically) — loads only when
  Claude is actually working with matching files, not every session.
- **Leave it in CLAUDE.md** only if it changed a standing convention
  going forward (then rewrite it as a rule, not a story — "update_post
  checks the post's current status before mutating" belongs in
  CLAUDE.md; "on 2026-08-08 we discovered this was missing and added it
  because..." belongs in the skill/rules file, with the CLAUDE.md line
  pointing at it if useful).

## How to split an existing oversized file

1. `wc -l` it, read through, and tag each section as convention vs.
   incident-log using the definitions above.
2. Move incident-log sections into a new skill (or rules file) verbatim
   first — don't rewrite content while moving it, that's a separate step
   and conflates two kinds of changes in one edit.
3. In CLAUDE.md, leave at most a one-line pointer if the moved content is
   something a session might need to go looking for ("known wp.py
   quirks — see skill wp-integration-notes"), otherwise nothing at all.
4. Re-read what's left in CLAUDE.md — if it's still over ~200 lines, it
   likely has more reference material that reads like documentation
   rather than a rule; keep splitting.

## Don't over-apply this

A short, information-dense CLAUDE.md well under 200 lines doesn't need
splitting just because it *could* be split further — the goal is keeping
sessions from paying for content they don't need, not minimizing line
count for its own sake. If every line is a standing convention someone
would genuinely want loaded every session, leave it alone.
