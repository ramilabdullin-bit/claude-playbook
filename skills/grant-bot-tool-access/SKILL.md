---
name: grant-bot-tool-access
description: Use when a headless `claude -p` bot on this server (or a similar restricted-tools deployment elsewhere) needs access to Skills, subagents (Task), or another built-in tool it currently can't reach — or when building a new bot and deciding what its --tools allowlist should include. Also use for "why can't the bot use skills", "add subagent access to a bot", "what tools does this bot have".
---

# Giving a restricted headless session access to Skills/Task/other tools

`--tools <list>` on `claude -p` is a **strict allowlist** of built-in tool
*names* — Bash, Read, Edit, Grep, Glob, WebSearch, WebFetch, Skill, Task,
etc. If a tool's name isn't in that list, the session cannot use it, full
stop — no amount of skills in `~/.claude/skills` or subagents in
`.claude/agents/` matters if the session was never given the `Skill` or
`Task` tool to invoke them with. `--allowedTools`/`--disallowedTools` are
a *second*, finer-grained layer on top (e.g. restricting Bash to specific
command patterns) — they don't grant a tool that `--tools` excluded.

This is easy to miss because the failure is silent from the outside: the
bot just never uses skills/subagents, and it looks like a prompting
problem ("it's not following the instruction to check for a skill")
rather than a capability problem (it literally cannot).

## How to check what a bot currently has

Find the exact `claude` invocation the bot's code builds (its
`--tools`/`--allowedTools` construction), then reproduce those flags in a
cheap one-turn live call and just ask:

```bash
claude -p "Есть ли у тебя доступ к инструментам Skill и Task прямо сейчас? Ответь да/нет по каждому и почему." \
  --tools "<exact same list the bot uses>" --output-format json [other matching flags]
```

This is cheap (one turn, a few cents) and gives a real, confirmed answer
instead of guessing from the flags — confirmed 2026-08-08 against this
server's SEO-mode bot (`telegram-claude-bot`), which turned out to have
neither Skill nor Task despite a rich skills playbook existing on the same
machine.

## No `--tools` flag at all = full default toolset

If a bot's code never passes `--tools` (this server's admin bot,
`telegram-claude-admin-bot`, is the deliberately-unrestricted example),
the session gets Claude Code's complete default toolset, Skill and Task
included, automatically — no extra wiring needed. Custom subagents in
`.claude/agents/` and skills in `~/.claude/skills` (or wherever
`--setting-sources` points) just work. Verified live 2026-08-08: adding a
custom subagent there and invoking it through the admin bot's exact flags
worked on the first try.

## Adding Skill/Task to a bot that currently has a `--tools` allowlist

1. Add `Skill` and/or `Task` to the `--tools` list.
2. Decide whether that's actually safe for this bot's trust level. Task
   in particular lets the model choose *any* subagent it can discover
   (built-in ones like `general-purpose`, plus anything in
   `.claude/agents/` at the scopes this session's `--setting-sources`
   loads) — opening it isn't the same as opening one specific narrow
   subagent. If the goal is "let it delegate search to this one isolated
   read-only helper" rather than "let it spawn arbitrary subagents",
   check whether the CLI version in use supports scoping Task the same
   way Bash gets scoped (`Task(<subagent-name>)`-style pattern in
   `--allowedTools`) before assuming a bare `Task` grant is narrow enough
   — don't assume, verify against the installed `claude --help` output,
   syntax changes between versions.
3. If the bot's system prompt already documents its confirmation rules
   for irreversible actions, add a line telling it *when* to delegate
   (e.g. "if a task needs finding/understanding something before acting,
   use the `<name>` subagent instead of exploring in the main
   conversation") — granting the capability doesn't mean the model forms
   the habit of using it without a nudge.
4. Restart, then re-run the same one-turn confirmation check from above
   before trusting it in production — don't assume the flag change did
   what you intended.

## Don't open it just because you can

A bot's `--tools` allowlist is usually deliberately narrow for a reason
(this server's SEO bot is scoped to a handful of read/write patterns
specifically so it can't touch the rest of the filesystem). Before adding
Skill/Task to a restricted bot, check whether the actual problem it would
solve is already fixed some other way — this server's SEO-mode PDF-cost
problem, for instance, was fixed by converting PDFs to text before the
model ever saw them, not by adding subagent isolation, and opening Task
for a locked-down bot without a concrete need is pure attack-surface
growth for no benefit.
