---
name: secret-file-guard
description: Use when a new kind of credential/session file shows up on this server that isn't covered yet by the global secret-file hook (e.g. a new cookies/token/key file pattern), when the hook needs to be reproduced on a new machine, or when asked "protect this file from being edited" / "extend the secrets hook".
---

# Global secret-file PreToolUse hook

`/root/.claude/settings.json` has a `PreToolUse` hook on
`Edit|Write|MultiEdit` that denies the tool call outright (not just warns)
when the file's basename looks like a credential file. It applies to every
project on this server, not per-project — the reasoning was: writing this
once beats remembering to add per-project protection every time a new
project appears.

## Current coverage

The hook's `jq` command matches basename against, case-insensitive:
- `^\.env($|\..*)$` — `.env`, `.env.local`, etc.
- `cookies.*\.json` — anywhere in the name: `cookies.json`,
  `yandex_cookies.json`, `cookies.json.txt` all match (substring test, not
  anchored — deliberately broad since a false-positive here just means an
  extra confirmation, not a real block).
- `token.*\.json` — `vk_ads_token.json`, etc.
- `service.*account.*\.json` — Google Cloud service-account key files, e.g.
  `google_service_account.json`.
- `credentials.*\.json` — generic OAuth/API credential dumps, e.g.
  `credentials.json`.

It does NOT cover: `.pem`/`.key` files, arbitrary `*password*` or
`*secret*` names, or non-`.json` token files — none of those exist on this
server yet. If one shows up, extend the jq filter rather than adding a
second hook; keep the credential-file logic in one place.

## How to verify it's still active

```bash
jq -e '.hooks.PreToolUse[] | select(.matcher == "Edit|Write|MultiEdit") | .hooks[] | select(.type == "command") | .command' /root/.claude/settings.json
```
Exit 0 + prints the command = still wired up. A broken/missing entry here
silently means Edit/Write on `.env` etc. would go through unblocked — this
is worth checking after any manual edit to `settings.json`.

## How to extend it (new pattern)

1. Read `/root/.claude/settings.json`, find the `PreToolUse` →
   `Edit|Write|MultiEdit` hook's `command`.
2. Add one more `or ($base | test("<new-pattern>";"i"))` clause to the jq
   filter — same shape as the existing three.
3. **Pipe-test before writing**, don't just edit and hope:
   ```bash
   echo '{"tool_input":{"file_path":"/path/to/a/matching/file"}}' | <the jq command>
   ```
   Expect the deny JSON for a file that should match, `{}` for one that
   shouldn't (test both).
4. Write the change, re-run the `jq -e` validation above, then prove it
   fires with a real Edit call on a matching file in this session (expect
   the tool call to error with the deny reason) — and a real Edit on an
   unrelated file to confirm nothing broke (make + immediately revert a
   trivial change).

## Reproducing this on a new server

Copy the whole `hooks.PreToolUse` block from this server's
`/root/.claude/settings.json` into the new machine's — it's global
(`~/.claude/settings.json`), not tied to any project, so no per-project
setup is needed there either.
