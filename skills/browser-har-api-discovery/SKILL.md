---
name: browser-har-api-discovery
description: Use when reverse-engineering an undocumented (or badly-documented) web API for a service that has no usable API docs but does have a working browser-based personal cabinet — e.g. a bank's business portal, a marketplace seller dashboard. Also use for "у банка нет нормального API, но есть личный кабинет", "разберись как работает их API через браузер". Alternative to the error-message-driven trial-and-error approach already used for Точка/Sberbank when a browser is actually available to record real traffic.
---

# Recording a HAR file to reverse-engineer an API from browser traffic

**Status: written from the general technique, not yet exercised on this
server** — the `claude-in-chrome`/browser tooling needed to actually do
this wasn't connected in the session that wrote this skill (see
[[project_sberbank_api_integration]] and the Ozon Bank inquiry from the
same period, both blocked on the same missing capability). Treat the
steps below as the documented plan, and update this file with what
actually happened the first time it's run for real — including anything
that doesn't work as described here.

## Why this over the error-message trial-and-error approach

This server's established pattern for an undocumented API (used
successfully for both Точка and Sberbank) is: send a minimal request,
read the bank's validation error naming the missing/wrong field, add it,
repeat. That works but is slow and only discovers fields the API
bothers to complain about by name — some validation failures return a
generic error with no field-level detail. Recording real browser traffic
while a human (or the model driving a browser tool) performs the actual
action in the personal cabinet captures the **exact real request** —
every header, every field, in the order and shape the service's own
frontend sends it — which sidesteps both problems at once.

## When to reach for this instead

- The trial-and-error approach has stalled (errors are generic, not
  field-specific) — this happened during Sberbank onboarding for exactly
  one endpoint before console-provided documentation resolved it faster;
  worth knowing this is the fallback for when that shortcut isn't
  available.
- The service publishes no API docs at all, only a browser UI — checked
  before assuming this is needed (see [[confirm-gated-integration]]'s
  Shape 2 for the parallel "no API, browser automation only" case — this
  skill is about *discovering* an API that turns out to exist but isn't
  documented, not a substitute for browser automation when there truly is
  no API).

## The plan

1. **Requires browser tooling to be connected** (`claude-in-chrome` or
   equivalent) — confirm this first; without it, fall back to the
   trial-and-error approach already proven for Точка/Sberbank.
2. Log into the service's personal cabinet normally (real session, real
   credentials — same trust/handling as any other credential on this
   server).
3. Open browser DevTools → Network tab, or use the browser tool's own HAR
   export if it has one; clear existing entries.
4. Perform the exact action whose API call is needed (view a statement,
   create a draft payment, check a balance) once, cleanly — avoid
   unrelated clicks in the same recording, they add noise to filter out
   later.
5. Export the recorded traffic as a `.har` file.
6. **Before reading it further**: a HAR file contains real
   `Authorization` headers, cookies, and session tokens for a live
   account — treat it with the same handling as any other credential file
   on this server (not committed to git, chmod 600, not pasted into
   chat). Read only the request/response shapes needed (method, path,
   body schema, non-secret headers), and either redact or discard the
   file once the relevant shape has been extracted into actual client
   code.
7. From the relevant request(s): extract method, path, required headers
   (noting which are secret vs. structural — e.g. `Content-Type` vs.
   `Authorization`), body shape, and the response shape needed to parse
   the result. Build the client code from this directly, the same
   structure as `sberbank_client.py`/`tochka_client.py` — a thin wrapper
   per endpoint, not a generic "replay this HAR" mechanism.
8. **Verify empirically** per [[verification-before-completion]] — a
   captured request replayed with fresh credentials/tokens needs to
   actually succeed once for real before the client code built from it is
   trusted, same as any other new integration on this server.

## Known unknowns (honest, not yet resolved)

- Whether this server's Xvfb/proxy setup (used for Yandex properties per
  [[telegram_claude_voice_bot]]'s browser notes) is needed for bank
  cabinets too, or whether they're less aggressive about headless/non-RU-
  IP detection than Yandex — untested, find out on first real use.
- Whether the connected browser tool actually exposes HAR export
  natively, or whether DevTools Network-tab export needs to be done
  manually by a human in the loop — depends on which browser tool ends up
  connected, not something to assume either way in advance.
