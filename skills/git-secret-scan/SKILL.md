---
name: git-secret-scan
description: Use when setting up a new git repository on this server, when asked to "protect against committing secrets" / "поставь секрет-скан на репозиторий", or when reviewing why a secret leaked into git despite [[secret-file-guard]] being active. Installs a content-based pre-commit hook that scans staged diffs for secret-shaped values, complementing the global filename-based PreToolUse hook.
---

# Content-based pre-commit secret scan

`secret-file-guard` (the global `PreToolUse` hook in `~/.claude/settings.json`)
blocks Claude from editing/writing/reading files whose *name* looks like a
credential file (`.env`, `cookies.json`, `token.json`, etc). It does **not**
catch a real secret pasted into a normally-named file (`config.py`,
`client.py`) — nothing about the filename triggers it, and it only fires on
Claude's own tool calls, not on `git commit` from a plain terminal.

This skill closes that specific gap: a `git` `pre-commit` hook that scans the
**content** of staged diffs for secret-shaped patterns, regardless of which
file they're in. Adapted from `artemiimillier/claude-code-starter`'s
`pre-commit.sample`, generalized for reuse across this server's repos rather
than tied to one project.

## What it catches

Per staged file, on the **added lines only** (`git diff --cached`):
- `.env`/`.env.*` staged at all → hard block, no content inspection needed.
  **Exception (added 2026-08-31):** `.env.example`, `.env.sample`,
  `.env.template`, `.env.dist` and `.env.<anything>.example` are *not*
  blocked by name — they are standard repo files that exist precisely to hold
  placeholders. The content checks below still run on them, so a real key
  pasted into an `.env.example` is caught exactly like anywhere else
  (regression-tested).
- `key/token/secret/password/bearer = "16+ chars"` pattern → warn (could be a
  placeholder, human judgment call). Two false-positive classes are filtered
  out (also 2026-08-31): **variable substitution** (`TOKEN="${MPSTATS_TOKEN}"`,
  `password = os.environ[...]`, `secret: "{{ vault_var }}"`, `process.env`,
  `System.getenv`) and **obvious placeholders** (`your_…`, `…_here`,
  `placeholder`, `changeme`, `dummy`, `xxxx`). The word `example` is
  deliberately **not** in that filter — too common, it would silence real
  findings.
- Recognizable real-looking key formats — OpenAI (`sk-`), Stripe
  (`sk_live_`), AWS (`AKIA...`), Google (`AIza...`), Slack (`xox...`),
  GitHub (`ghp_...`), Telegram bot tokens (`\d{8,10}:AA...`) → hard block.
- `BEGIN ... PRIVATE KEY` → hard block.

Hard blocks exit 1 (commit refused). The `key=value`-shaped warn is
non-blocking in spirit but the script currently exits 1 for it too — treat a
warn as "look at the diff before re-running", not as certainly a leak; use
`git commit --no-verify` only after actually re-reading the diff, never
reflexively.

## Install on a repo

```bash
cp /root/claude-playbook/skills/git-secret-scan/pre-commit-secret-scan.sh \
   <repo>/.git/hooks/pre-commit
chmod +x <repo>/.git/hooks/pre-commit
```

`.git/hooks/` is never tracked by git itself — this has to be installed
per-clone, per-repo, there is no way to make it travel with the repository
automatically. When setting up a new project (see `onboard-new-project`),
install this hook as one of the standard steps, same as `.gitignore`.

**Installed on 10 repos as of 2026-08-31** — the original 8 from 2026-08-25
(`agents`, `leads-agent`, `logistics-agent`, `ozon-agent`,
`telegram-claude-admin-bot`, `telegram-claude-bot`, `wb-agent`,
`claude-playbook`) plus `projects/e-comportal` and
`projects/3d-print-business`, which the original sweep **missed**.

That miss is the lesson: the 2026-08-25 sweep enumerated repos by grepping
for repos that *already had the hook*, so repos that never had it were
invisible to it — a self-confirming check. Enumerate from `find`, then
report the ones **without** the hook:

```bash
find /root -maxdepth 5 -type d -name .git 2>/dev/null \
  | grep -vE '/(venv|node_modules)/' \
  | while read -r g; do
      test -x "$(dirname "$g")/.git/hooks/pre-commit" || echo "MISSING: $(dirname "$g")"
    done
```

`e-comportal` was the worst one to have missed — it holds live VK/Yandex
cookies and tokens. (Verified at install time: no `.env` had actually
leaked into its index, no real-format keys in tracked files.)

Deliberately **not** installed on `/root/.claude/plugins/marketplaces/ponytail`
— a third-party plugin clone, not our repo, nothing is committed to it.

**The hook is copied, not linked** — editing this skill's
`pre-commit-secret-scan.sh` does *not* update the 8 installed copies. After
changing it, re-run the install command for every repo and verify with
`md5sum` that they match (done on 2026-08-31 for the false-positive fix).

## Verify it's active on a repo

```bash
test -x <repo>/.git/hooks/pre-commit && echo "installed" || echo "MISSING"
```

To prove it actually fires (safe, throwaway test — do this in a scratch repo,
not a real one):
```bash
TESTDIR=$(mktemp -d) && cd "$TESTDIR" && git init -q
cp /root/claude-playbook/skills/git-secret-scan/pre-commit-secret-scan.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
git config user.email t@t.com && git config user.name t
echo 'KEY = "sk-FAKE_TEST_KEY_DO_NOT_MATCH_REAL_PATTERN"' > leak.py
# ^ deliberately broken so THIS doc doesn't trip its own hook when committed
git add leak.py && git commit -m x   # expect: BLOCKED, exit 1
cd /root && rm -r "$TESTDIR"         # NOT rm -rf — that pattern is in
                                       # permissions.deny, see below
```

## Known gaps (don't oversell this)

- Per-clone install, not automatic — a fresh `git clone` of any of these
  repos on another machine won't have it until someone runs the install
  command above.
- `git commit --no-verify` bypasses it entirely — this is a speed bump for
  an honest mistake, not a hard technical barrier against a deliberate
  bypass.
- Regex-based — won't catch a secret that doesn't match any of the known
  formats (an internal/custom token scheme, a base64-wrapped value, a
  secret split across multiple lines).
- **Residual false positive (known, not fixed):** the `key = "16+ chars"`
  WARN regex can span *across* string-literal boundaries. Real case in
  `e-comportal/tools/yandex_business.py` line 274 — a line of the shape
  `if "csrf_token=" in u and "s" in u`, except with a longer gap between
  the two string literals. The regex reads `token`, then `=`, then the
  closing quote, and swallows the *code between the two literals* as if it
  were the value. (Example deliberately shortened above so this very file
  doesn't trip its own hook — same trick as the fake key further up.)
  Left alone on purpose: tightening it further risks silencing real
  findings, and a WARN is a "look at the diff" prompt, not a hard block.
- Only runs at commit time, not at push time — a secret committed and later
  amended/rebased out locally never reached this check on the intermediate
  commit, but neither did it reach the remote if never pushed. If it *was*
  pushed before being caught, the hook doesn't help — see
  `secret-file-guard`'s server for how to check whether something already
  leaked into git history (`git log --all -p | grep <pattern>`).

## Relation to `permissions.deny` in `~/.claude/settings.json`

Added the same day (2026-08-25) as this skill: `Bash(rm -rf *)`,
`Bash(export *&& curl *)`, `Bash(wget *$*)` and variants, also lifted from
the same starter template. Different layer — those block dangerous *shell
commands* regardless of git; this hook blocks dangerous *commit content*
regardless of command. Keep both, they don't overlap.
