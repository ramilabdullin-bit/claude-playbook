---
name: destructive-command-gate
description: Use when a new headless `claude -p ... --dangerously-skip-permissions` bot is set up on this server (or a similar unrestricted-tools deployment elsewhere), when a new destructive command pattern should be blocked, or when asked "поставь гейт на разрушительные команды" / "block destructive commands technically, not just in the prompt". Global PreToolUse hook that vetoes specific catastrophic Bash patterns (rm -rf, git push --force, git reset --hard, git clean -f, DROP TABLE/DATABASE) even under --dangerously-skip-permissions.
---

# Technical gate on destructive Bash commands

Every unrestricted bot on this server (`telegram-claude-admin-bot`,
`claude-file-inbox-bot`) runs `claude -p --dangerously-skip-permissions`
with its `ADMIN_SYSTEM_PROMPT`/`INBOX_SYSTEM_PROMPT` asking the model to
pause and confirm before irreversible actions. Both files say outright
that this is a *behavioral* control, not a technical one — a direct
request in the same message overrides it, by design (that's the whole
point of the unrestricted mode). That leaves a real gap for the handful
of genuinely catastrophic command shapes where "the model chose not to"
shouldn't be the only thing standing between a phone message and, say, a
wiped git history.

Added 2026-08-28 after a research pass through public Claude Code skill
discussions surfaced hook-based command gating as a pattern several
people use for exactly this. Confirmed against the official docs
(`hooks-guide.md`, "Hooks and permission modes" section) before
installing, not assumed from a blog post: **`PreToolUse` hooks fire
before any permission-mode check, in every mode, including
`bypassPermissions`/`--dangerously-skip-permissions`** — a hook returning
`permissionDecision: "deny"` blocks the tool call regardless of that
flag. This is a different, stronger guarantee than `permissions.deny` in
the same `settings.json` (that list is only consulted by the normal
permission system, which `--dangerously-skip-permissions` explicitly
bypasses — it does NOT protect the headless bots at all, only interactive
sessions running in the default permission mode).

## What it covers

`/root/.claude/settings.json` → `hooks.PreToolUse` has a second entry
(alongside the `Edit|Write|MultiEdit|Read` one from
[[secret-file-guard]]) with `matcher: "Bash"`. Its `jq` filter denies the
tool call when `.tool_input.command` matches, case-insensitive:

- `rm -rf *` / `rm -rf ~` / `rm -rf /` / `sudo rm -rf *` — same literal
  target set already vetted in `permissions.deny`, deliberately narrow
  (a targeted `rm -rf /path/to/specific/thing` is NOT blocked — that's a
  normal, frequent, legitimate operation for these bots; only the
  whole-filesystem/whole-home/whole-cwd wildcards are).
- `git push` combined with `--force`/`-f` (as a real flag, not a
  substring — see the regex bug below) or any `--force-*` variant
  (`--force-with-lease` included, matched via the `--force\b` word
  boundary).
- `git reset --hard`.
- `git clean` with an `-f`-containing flag combination (`-fd`, `-fdx`,
  etc).
- `DROP TABLE` / `DROP DATABASE` / `DROP SCHEMA` (SQL, case-insensitive,
  matches inside a `psql -c "..."`/`mysql -e "..."` string same as a
  bare shell command).

Deliberately **not** covered: generic `curl`/outbound-POST-to-unknown-
domain (no reliable way to tell a legitimate API call from a bad one by
regex alone — every bot on this server routinely POSTs to Telegram/OpenAI/
bank APIs, a domain-based rule would need an allowlist that doesn't exist
yet and would false-positive constantly without one).

## No override, by design

Unlike `git-secret-scan`'s pre-commit hook (`--no-verify` bypasses it on
purpose — that one guards against honest mistakes, not deliberate
action), this hook has **no code-level escape hatch** for the patterns it
covers. That's intentional, matching the same philosophy as tgbankbot's
payments (always created as unsigned drafts, no exceptions): these
specific command shapes are rare and catastrophic enough that "type it
into a phone-controlled bot" should never be sufficient, full stop. If
one of these is genuinely needed, do it from a real terminal/SSH session,
not through an unrestricted bot.

## A regex trap hit while building this (worth knowing before extending)

The first version used one combined pattern:
`git\s+push\s+.*(--force\b|(^|\s)-f(\s|$))` — and it silently let
`git push -f origin main` through. Cause: `\s+` right after `push`
already consumed the delimiter space, so by the time `.*` backtracked
down to matching the `-f` flag, there was no leading whitespace left in
the *remaining substring* for `(^|\s)` to match against — `^` only
anchors to the true start of the whole string, not to wherever `.*` has
backtracked to. Fix: test the flag condition against the **full original
`$cmd`** as a separate ANDed clause instead of chaining it after `.*` in
one pattern:
```
($cmd | test("git\\s+push";"i")) and
  (($cmd | test("--force\\b";"i")) or ($cmd | test("(^|\\s)-f(\\s|$)")))
```
General lesson for any future jq/regex hook here: **never chain a
positional/anchor-sensitive sub-pattern after a `.*` inside one `test()`
call** — split it into independent ANDed `test()` calls against the
untouched original string instead. Caught only because every new pattern
was pipe-tested against both a hand-built dangerous list and a
hand-built safe list before writing anything — see below, do the same for
any addition.

**Second bug, found live in production use the same day** (not caught by
the test suite above, because the test suite didn't include a *chained*
command): the ANDed-clauses fix above checks `--force`/`-f` against the
**whole `$cmd` string**, which is correct for a single command but wrong
for a shell one-liner chaining several commands with `&&`/`;`/`|`. A real
commit-and-push sequence —
`git commit -F msg.txt && git push origin main && rm -f msg.txt` — got
denied, because "contains `git push`" was true (in clause 2) and
"contains a standalone `-f`" was *also* true (in clause 3's unrelated
`rm -f`), and the AND was evaluated against the concatenated string, not
per-clause. Fix: split `$cmd` on shell operators first, then require both
conditions to hold **within the same clause**:
```
($cmd | [splits("&&|\\|\\||;|\\|")]) as $clauses |
...
or (any($clauses[]; (. | test("git\\s+push";"i"))
  and ((. | test("--force\\b";"i")) or (. | test("(^|\\s)-f(\\s|$)")))))
...
```
This only matters for patterns built as an AND of independent `test()`
calls (only the git-push case, here) — the single self-contained regexes
(`rm -rf`, `git reset --hard`, `DROP ...`) don't have this failure mode,
since there's nothing to accidentally satisfy from an unrelated clause.
**Lesson on top of the lesson above:** a fix verified against a
comprehensive single-command test suite can still hide a bug that only
shows up in a *chained* command — add at least a few `&&`/`;`-joined
cases (both a real matching case split across clauses, and a real legit
multi-command one-liner) to the test suite for any hook condition built
from more than one `test()` call.

## How to verify it's still active

```bash
jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.type == "command") | .command' /root/.claude/settings.json
```
Exit 0 + prints the command = still wired up.

## How to test a change (don't skip this)

Testing this **inside an interactive Claude Code Bash tool call is
self-defeating** — the hook is global, so a test script whose own text
contains the literal dangerous strings (as here-doc test fixtures) will
trip the hook on the *test harness itself*, not on the simulated command.
Write the test script to a file first (`Write` tool, not `Bash`), then
invoke it with a plain `bash /path/to/script.sh` — that Bash *tool call*
doesn't itself contain any dangerous substring, so the outer hook stays
quiet while the script pipes fabricated JSON straight into the extracted
`jq` filter:
```bash
JQ_CMD=$(jq -r '.hooks.PreToolUse[] | select(.matcher=="Bash") | .hooks[0].command' /root/.claude/settings.json)
echo '{"tool_input":{"command":"rm -rf *"}}' | eval "$JQ_CMD"   # expect deny
echo '{"tool_input":{"command":"git status"}}' | eval "$JQ_CMD" # expect {}
```
Always test BOTH a representative dangerous set and a representative safe
set (legitimate ops these bots actually run — `git push` without force,
targeted `rm -rf /tmp/...`, `systemctl restart`, `curl` to a known API,
`grep -f`/`tail -f`/`git log -f` which contain a bare `-f` but aren't
git-push at all) before considering a pattern change done.

## Known gaps

- Bash-tool only, same as every hook here — a script that itself shells
  out to something destructive (e.g. a Python script calling
  `subprocess.run(["rm","-rf", path])`) isn't inspected; the hook only
  sees the literal command string handed to the `Bash` tool.
- Regex-based, not semantic — a sufficiently obfuscated command (variable
  concatenation building `rm -rf $X` at runtime, base64-decoded and
  eval'd) would slip through. Same class of limitation as
  [[git-secret-scan]] and [[skill-security-audit]]'s scanner; not solved
  here, just documented.
- SQL coverage is a plain substring/regex match on `DROP TABLE|DATABASE|
  SCHEMA` — doesn't parse SQL, so a genuinely weird multi-statement or
  comment-obfuscated DROP could theoretically slip past. No known
  real-world case where this mattered yet; revisit if one does.

## Reproducing this on a new server

Copy the `matcher: "Bash"` entry from this server's `hooks.PreToolUse`
array into the new machine's `~/.claude/settings.json` — global, not
per-project, same as [[secret-file-guard]].
