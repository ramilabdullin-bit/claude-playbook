---
name: analyze-claude-session-cost
description: Use when a headless `claude -p` call (a bot, a cron job, any subscription-billed invocation) turned out expensive and you need to find out why — or as part of a standing duty to proactively audit task cost and cut it without being asked. Triggers on "why was this so expensive", "reduce cost", "проверь траты", "analyze spending", or when reviewing bot logs that show a high `cost=$` value.
---

# Diagnosing and cutting the cost of a Claude Code session

Headless `claude -p ... --output-format json` calls report `total_cost_usd`,
`num_turns`, `duration_ms` in their JSON output, but that number alone
doesn't explain *why* a call was expensive. The full reasoning trace is on
disk regardless of what the caller (a bot, a script) chose to log — this
skill is how to read it and turn the finding into a concrete, safe fix.

## 1. Find the session transcript

Every `claude` session (interactive or `-p --resume`/`--session-id`) is
persisted as JSONL, keyed by the working directory it ran in:

```bash
find ~/.claude/projects -iname "*<session_id>*"
```

The project folder name is the `cwd` with `/` replaced by `-` (e.g.
`/root/projects/e-comportal` → `-root-projects-e-comportal`). If you only
have a timestamp/task description, not the session_id, grep the caller's
own log first (bot.log, cron log) for the `session_id`/`session=` field
next to the request.

## 2. Pull per-turn usage

Each `assistant`-type line has `message.usage` with `input_tokens`,
`cache_read_input_tokens`, `cache_creation_input_tokens`, `output_tokens`,
and `message.model`. Sum them and look at the *shape*, not just the total:

```python
import json
with open(path) as f:
    for line in f:
        obj = json.loads(line)
        if obj.get('type') == 'assistant':
            u = obj['message'].get('usage', {})
            tools = [c.get('name') for c in obj['message'].get('content', [])
                     if isinstance(c, dict) and c.get('type') == 'tool_use']
            print(u.get('input_tokens'), u.get('cache_read_input_tokens'),
                  u.get('cache_creation_input_tokens'), u.get('output_tokens'),
                  obj['message'].get('model'), tools)
```

Also list the tool-call sequence alone (name + first ~100 chars of input) —
this is usually more diagnostic than the token counts, because it shows
*what the agent spent its turns doing*.

## 3. Recognize the common expensive patterns

- **Blind rediscovery.** The first N calls are `ls`/`find`/`grep` hunting
  for a project, then reading its CLAUDE.md, then reading a helper script
  to learn its CLI — all knowledge that a *different*, purpose-built
  session already has baked into its system prompt or `cwd`. Symptom: a
  general-purpose/admin agent (broad `cwd`, generic system prompt) doing a
  task that's really about one specific known project.
  → Fix: add a short "known projects on this server" map to that agent's
  system prompt (paths + one line on what's there + which helper script to
  read first) — doesn't reduce capability, just removes the rediscovery
  tax. Keep it short; it's paid on every single call the agent makes.

- **Oversized raw documents.** A large PDF/binary gets read by the model's
  native file tool in paginated chunks (each chunk often round-tripped
  through a redirect-to-file when the result doesn't fit inline), and the
  agent ends up reading the whole document cover-to-cover for a task that
  only needed one or two sections.
  → Fix: convert to plain text *before* the model ever sees it (e.g.
  `pypdf`/`pdfplumber` for PDF, `openpyxl` for xlsx) and, in the prompt,
  suggest grepping the text for task-relevant keywords instead of reading
  linearly. Only do this for formats where extraction is lossless (real
  text layer, not a scan) — fall back to the native tool otherwise.

- **Cache not being reused turn-to-turn.** Watch `cache_read_input_tokens`
  vs `cache_creation_input_tokens` across consecutive turns: healthy reuse
  looks like a stable/growing `cache_read` baseline with small
  `cache_creation` deltas; a red flag is `cache_creation` repeatedly
  rewriting a large, growing prefix from the same earlier `cache_read`
  checkpoint — that's the *same* content being paid for as a fresh
  (expensive) write again instead of a cheap read. This has been observed
  across separate `-p` subprocess invocations resuming the same session
  (each subprocess reconstructs and resends context) and is not something
  `--betas` cache-TTL headers can fix under subscription OAuth auth (that
  flag is API-key-only). No confirmed lever here yet beyond reducing how
  much content needs re-sending in the first place (the two fixes above).

- **High turn count from trial-and-error.** Several near-duplicate
  throwaway scripts in a row (`script.py`, `script2.py`, `script3.py`)
  usually means the agent didn't have a clear reference for a tool's API
  and was discovering it by running variations. → Fix: point the system
  prompt/CLAUDE.md at the exact helper file to read first, or add a short
  usage example next to the tool if it's used often enough to be worth it.

## 4. Apply fixes autonomously, but only if they're actually safe

Model/tool/context-shape changes that don't reduce the guaranteed
correctness of the outcome are fair to make without asking first (see the
owning project's own cost-optimization policy if one exists). Do NOT
silently swap to a cheaper/weaker model for a step whose whole job is
factual accuracy (e.g. extracting real prices/tariffs that must not be
hallucinated) — that trades cost for a correctness risk the task owner
hasn't agreed to. When in doubt about whether a fix changes behavior, not
just cost, ask.

After applying a fix: syntax-check, restart the affected process, confirm
clean startup, and write down in the project's CLAUDE.md *why* the change
was made (which transcript, which pattern) — the next person diagnosing a
cost spike should not have to re-derive this from scratch.
