---
name: telegram-bot-command-pattern
description: Use when adding a new command/feature to /root/telegram-claude-bot (bot.py), or building a similar Telegram bot on this server that needs owner-only access and a confirm-before-mutating flow. Also use for "add a command to the bot", "новая команда боту".
---

# Adding a command to telegram-claude-bot

Read `/root/telegram-claude-bot/CLAUDE.md` first — it documents the modes
(chat/seo/slides), the marketplace-agents HTTP integration, and the
check→apply pending-state pattern already in use. This skill is the
recipe for extending it consistently, not a description of what exists.

## Read-only command (safe to run immediately)

Follow `cmd_pricing_check`/`cmd_reviews_check` as the template:
1. `check_access(user_id)` first, always — every handler in this bot
   starts with this, no exceptions.
2. Do the read (HTTP to marketplace-agents, Claude CLI call, or local
   file read) and reply. No confirmation needed for read-only actions.

## Mutating command (changes something live — price, publishes a post,
## sends a message, changes a campaign)

Never let a single command both compute and apply irreversibly. Use the
two-step pending pattern already established:
1. `<name>_check` command — computes/proposes, stores the proposal in
   `data/<name>_pending.json` keyed by `user_id` (see
   `set_pending_pricing`/`get_pending_pricing` for the exact shape:
   load-mutate-save on a dict keyed by `str(user_id)`), replies showing
   what it found and how to confirm.
2. `<name>_apply` command — reads the pending entry, refuses with a clear
   message if there isn't one ("сначала выполни /..._check"), performs the
   actual mutating call, then `clear_pending_<name>(user_id)`.

This mirrors the requirement already enforced for the SEO mode
(`SEO_SYSTEM_PROMPT_APPEND` rule 2): the owner must see what's about to
happen and confirm in a separate message before anything irreversible runs.
Don't skip the two-step even for "obviously safe" mutations — the pattern
is the safety net, not a judgment call per-command.

## If the new feature calls Claude CLI directly (not marketplace-agents)

- Always pass an explicit `--system-prompt` — omitting it lets the default
  Claude Code system prompt through, which drags in auto-memory behavior
  that breaks headless calls made with `--tools ""` (tool_use without
  tool_result → 400).
- If it needs project-scoped tool access (like SEO mode), use
  `--setting-sources ""` so it doesn't inherit whatever broad
  `.claude/settings.local.json` permissions exist from manual interactive
  sessions in that project directory.
- Keep the allowed-tools list as narrow as the feature needs — SEO mode's
  `SEO_ALLOWED_TOOLS` (exact `Bash(...)`/`Edit(...)` entries, not a bare
  tool name) is the model to copy, not `--tools` left wide open.

## After editing bot.py

```bash
python3 -m py_compile /root/telegram-claude-bot/bot.py
systemctl restart telegram-claude-bot
tail -f /root/telegram-claude-bot/bot.log
```
Also update the `HELP_TEXT` constant and
`/root/telegram-claude-bot/CLAUDE.md` — a command the owner can't discover
via `/start` and that isn't documented for the next session is a command
that gets re-explained or re-discovered at real token cost later.
