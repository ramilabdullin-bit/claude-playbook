---
name: export-claude-sessions
description: Use when the owner asks to "сохрани нашу сессию", "удали всё предыдущее общение", "почисти сессии", or before a subscription-limit cutoff — turns raw ~/.claude/projects/<proj>/*.jsonl transcripts into readable Markdown (user/assistant text only), scrubs secrets, archives the raw files with a tarball and removes them so the project starts clean.
---

# Export and clean Claude Code sessions

Raw session files (`~/.claude/projects/<proj>/<id>.jsonl`) hold every tool
output — bot tokens, ssh output, `.env` contents. They are NOT safe to
commit or send anywhere. Readable text of the dialogue is what the owner
actually wants to keep.

## Steps

1. Identify sessions: first/last user prompt per file (see `export.py`
   logic). Never touch the CURRENT session (`cur` in the script) or `memory/`.
2. `python3 export.py` → `docs/sessions/<first>_<last>_<id8>.md`, one per
   session, user/assistant text only, `<system-reminder>` blocks dropped,
   Telegram/Anthropic tokens and PEM keys replaced by `[секрет вырезан]`.
3. **Scrub passwords by hand** — regex catches tokens, not human passwords:
   ```
   grep -niE 'парол|password|логин *[:=]' docs/sessions/*.md
   grep -nE '[A-Za-z0-9+/_-]{40,}' docs/sessions/*.md | grep -vE 'https?://|[а-яА-Я]{3}'
   ```
   Owners paste passwords into chat (09.09.2026: three found — web-app
   password, bot unlock password, smb creds). `sed -i` them out before commit.
4. Archive raw files: `tar czf data/sessions_archive_<date>.tar.gz <jsonl + dirs>`,
   `chmod 600`, keep OUT of git (`data/` in .gitignore). Then `rm -r` the
   listed files. Bot sessions that resume by id (911's `sessions.json`) must
   be empty/reset first, otherwise `--resume` breaks.
5. Write a memory note: what was cut off, where the archive is, what is
   pending.

## Gotchas

- `queue-operation` records appear in interactive sessions too — don't use
  them to tell bot sessions from chat sessions; use `cwd`/first prompt.
- Decode with `errors='ignore'`: a `tail -c` cut mid-multibyte kills json.
- Auto-mode classifier blocks `ssh host 'git commit'` on another server —
  give the owner the command instead of retrying.
