---
name: learnings-md
description: Use when starting work on a project that has accumulated troubleshooting history/incidents worth remembering across sessions but doesn't have a dedicated place for it yet, or when CLAUDE.md is growing incident-log entries instead of standing conventions (see [[trim-claude-md]]). Also use for "веди журнал по проекту", "запомни это на будущее для этого проекта", "куда записывать находки по багам". Sets up a project-local Learnings.md that any Claude Code session working in that repo reads at the start and appends to at the end.
---

# Learnings.md — a per-project running log of what actually happened

`CLAUDE.md` should hold standing conventions — things true *now* and
likely to stay true. Incident entries ("found 2026-08-27: X regex bug
truncates 12-digit values") don't belong there — they accumulate forever,
which is exactly the growth pattern `trim-claude-md` exists to catch and
fix after the fact. `Learnings.md` is the place those entries should have
gone in the first place: a dated, append-only-in-spirit log, separate
from the standing-rules file, that any Claude Code session opening this
project reads on the way in and updates on the way out.

## When to set this up

A project that's accumulating real troubleshooting history across
multiple sessions — a bot with recurring edge cases (regex/API quirks,
known-flaky integrations), a codebase where "why is it built this way"
keeps needing re-discovery. Not worth it for a short-lived script or a
project touched once and left alone — the overhead of maintaining a log
nobody re-reads isn't worth paying.

## Setup

1. Create `Learnings.md` at the project root (next to `CLAUDE.md`).
2. Add one line to `CLAUDE.md` pointing at it, e.g.:
   ```
   Read Learnings.md at the start of a session; append a dated entry
   before finishing any non-trivial task (bug fix, new finding, a
   decision that wasn't obvious from the code).
   ```
   This is a pointer, not a copy — don't duplicate the mechanism's
   description into every project's `CLAUDE.md`, one line linking here is
   enough.

## Entry format

```
[YYYY-MM-DD] — <short task/context>: <Observation/Action/Confidence>
```

- **Observation** — what was actually found (a bug, a quirk of an
  external API, why something is built the way it is).
- **Action** — what was done about it (fixed, worked around, deliberately
  left alone and why).
- **Confidence** — how sure this is still true (verified live / inferred
  from one incident / guessed) — lets a later session judge whether to
  trust it at face value or re-verify, the same caution the auto-memory
  system's staleness warnings apply to memory files.

Example (style, not a real entry):
```
[2026-08-27] — OCR extraction for ЭКО invoices: INN regex truncated
12-digit values to 10 because the alternation `\d{10}|\d{12}` matched the
shorter branch first. Fixed to `(\d{10,12})(?!\d)`. Verified against 6
real documents post-fix. Confidence: verified live.
```

## Keeping it from growing forever

When `Learnings.md` passes roughly 80-100 lines, move the older/
lower-relevance entries into `learnings_archive.md` in the same
directory, keeping only the recent and still-load-bearing entries in the
main file. This is the same problem `trim-claude-md` solves for
`CLAUDE.md`, applied to this file — don't let it grow unbounded just
because it's not `CLAUDE.md`.

## Relation to the global auto-memory system

This server's Claude Code sessions also have a personal, cross-project
auto-memory store (`~/.claude/projects/*/memory/`, see the memory
instructions in the system prompt) — it can feel redundant with
`Learnings.md` at first glance. They're not the same thing:

- **Auto-memory** is tied to *this specific Claude Code installation*
  (this home directory) and is personal to the assistant across every
  project it touches — useful for things like user preferences and
  cross-project patterns, not something that travels with the repo.
- **`Learnings.md`** lives *inside the project's own repo*, travels with
  `git clone`, and is readable by any Claude Code session that opens that
  project — including a headless `claude -p` bot invocation with a
  different `cwd`/`--add-dir` than this home directory, or a future clone
  on another machine (`claude2` on Windows, see project memory) that
  doesn't share this server's `~/.claude` store at all.

Rule of thumb: an insight about *this operator's* preferences or a
pattern that repeats across unrelated projects → auto-memory. An insight
about *this specific codebase* that the next person/bot/session opening
this repo needs → `Learnings.md`. When genuinely unsure, it's fine for
the same finding to live in both — they don't conflict, they just serve
different readers.
