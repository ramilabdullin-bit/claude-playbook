---
name: confirm-gated-integration
description: Use when adding a new external integration (REST API client or browser automation) that can take a real, live-money or public/irreversible action — e.g. a new ad platform, a new social/CMS account, anything that posts publicly or spends budget. Also use for "add a new ad account integration", "новый рекламный кабинет", "подключить новую соцсеть/площадку".
---

# Adding an integration that can take a real irreversible action

Two proven patterns from this server's e-comportal tools
(`vk_ads_api.py`, `yandex_business.py`, `yandex_direct.py`,
`vk_community.py`, `dzen.py`) for the two shapes an integration usually
takes. Pick the one that matches; both share the same underlying rule:
**mutating/public actions always need the owner's explicit "подтверждаю"
in a separate message for that specific action** — everything below is
just how to enforce that in code, not a replacement for it.

## Shape 1 — official REST API (has real write endpoints)

Copy this exact pattern (from `vk_ads_api.py`, reused in
`yandex_direct.py`/`vk_community.py`):

```python
CONFIRM_PHRASE = "подтверждаю"

class ConfirmationRequired(YourAPIError):
    pass

@staticmethod
def _check_confirm(confirm: str | None, action: str) -> None:
    if (confirm or "").strip().lower() != CONFIRM_PHRASE:
        raise ConfirmationRequired(
            f"Refusing to {action}: requires --confirm \"{CONFIRM_PHRASE}\" "
            "(the owner's explicit confirmation for this specific action, "
            "not a general task go-ahead)."
        )
```

- Call `_check_confirm(confirm, action)` as the **first line** of every
  mutating method, before any network request.
- Every mutating CLI subcommand gets a plain `--confirm` argument
  (default `None`) piped straight through — argparse does no validation,
  the method does.
- Mutating methods return `{"before": ..., "after": ...}` (fetch state,
  mutate, fetch state again) so the caller/owner can see exactly what
  changed, not just "ok".
- Read-only methods (status/list/stats) need none of this — only gate
  what actually writes.
- **Verify the gate before shipping**: construct the client with dummy
  creds and call the mutating method without `--confirm` — it must raise
  before any network call happens (no mocking needed, the check runs
  before the request is built). Do this for every new mutating method,
  it's cheap and catches "forgot to call `_check_confirm`" immediately.

## Shape 2 — browser automation (no API, only a web UI)

When the platform has no API for the action you need (confirmed this is
genuinely true — search first, don't assume), copy the skeleton from
`yandex_business.py` (also used in `dzen.py`):

- Cookie-based auth: export via Cookie-Editor, convert to Playwright
  format (`load_cookie_editor_export` — copy verbatim,
  `expirationDate→expires`, `sameSite` string→enum map).
- **For any Yandex property specifically**: launch **headed**
  (`headless=False`) from the start, not headless — confirmed
  empirically (2026-08-04, `yandex_business.py`) that headless Chromium
  gets SmartCaptcha'd on every request regardless of cookie validity,
  identical cookies pass headed. Render onto the Xvfb display already
  running on this host (`YANDEX_DISPLAY`, default `:99`) rather than
  spinning up a new one. Route through `RU_PROXY_SERVER`
  (`socks5://127.0.0.1:1080`) if the session's cookies were minted from
  a Russian IP.
- Login detection: don't rely on CSS selectors (they rot across
  redesigns) — regex for the account's email in `page.content()` plus a
  `_detect_challenge()` helper that checks the URL/text for
  captcha/passport-redirect signals. Copy both from `yandex_business.py`.
- **No code-level `--confirm` for browser tools** — `browser.py`
  established this project's convention: confirmation for browser-driven
  mutations (publishing, editing live content) is enforced only
  behaviorally, through the calling agent's system prompt, not a CLI
  flag. Keep that consistent; don't invent a code-level gate for one
  browser tool and not others.
- **If you can't verify selectors against a live login** (no cookies
  available yet when writing the code): say so loudly in the module
  docstring ("UNVERIFIED AGAINST LIVE UI"), ship best-effort generic
  selectors (`role=textbox`, `[contenteditable=true]`), and include
  `sniff_requests`/`find_in_page`/`screenshot` diagnostic methods (copy
  from `yandex_business.py`) so the first live run can self-diagnose
  instead of failing silently or guessing blind.

## Wiring a new tool into the Telegram bot's SEO mode

See `telegram-bot-command-pattern` skill for the general command-adding
recipe. Specific to this pattern: add the new `tools/<name>.py` to both
`SEO_ALLOWED_TOOLS` (`Bash(...)` + `Edit(...)` entries) and add a new
numbered rule to `SEO_SYSTEM_PROMPT_APPEND` spelling out, per command,
what's free (read-only) vs. what needs the owner's "подтверждаю" — follow
the exact phrasing style of the existing numbered rules, don't summarize
loosely. If the tool holds its own credential/cookie file, add it to
`SEO_DISALLOWED_TOOLS` (`Read(<file>)`).

## Unattended/scheduled jobs (e.g. a daily cron-like job_queue task)

If the integration might get called from an unattended scheduled job
(not a live chat turn), the confirmation rule above already holds by
construction **as long as you don't weaken it**: an unattended run has no
incoming "подтверждаю" message to receive, so a correctly-prompted agent
physically cannot pass the gate during that run. When extending a daily
job's prompt to use a new integration, add drafting/checking steps freely
but never add wording like "in the daily run, publish automatically" —
that would be the one way to actually break this safety property.
