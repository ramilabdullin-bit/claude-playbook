---
name: verification-before-completion
description: Use before declaring any non-trivial fix, feature, or integration "done" — specifically as a discipline check on the moment right before saying so. Also use for "проверь перед тем как сказать готово", "did you actually test this", or when reviewing why something reported as fixed turned out not to be. Applies hardest to money-touching, security-touching, and multi-account/multi-tenant code where "looks right" and "is right" diverge most expensively.
---

# Verify, don't infer, before saying "done"

"The code looks correct" and "the code is correct" are different claims,
and the gap between them is exactly where bugs survive review. This
server's own history has concrete cases in both directions worth knowing
before treating this as generic advice:

- **Caught by actually running it**: a regex fix for OCR field extraction
  that looked obviously correct on inspection (`\d{10,12}` instead of
  `\d{10}|\d{12}`) was verified against real documents before being
  called fixed — worth doing even for "obviously right" one-line changes,
  because the *previous* buggy version also looked obviously right at the
  time it was written.
- **Caught by using the real system, not a mock**: a Sberbank payment
  draft's `payerKpp` validation (`""` rejected, literal `"0"` required)
  and a missing `payee_bank_corr_account` param were both found only by
  making a real (safe, ₽1, unsigned-draft) production call — no amount of
  reading the API docs surfaced either, because the docs didn't cover
  these specific validation rules.
- **Caught by testing the actual failure path, not just the happy path**:
  a new destructive-command hook initially had a regex-backtracking bug
  that let `git push -f` through while correctly blocking `git push
  --force` — found only by testing both variants side by side, not by
  reading the single pattern and confirming it "looked right."
- **Missed until a real user hit it**: a cross-user data leak in a
  statement-export feature (`_LAST_STATEMENT` as one shared global dict,
  not keyed per Telegram user) shipped and worked fine for months with a
  single user, then broke the moment a second user (an accountant) used
  the same bot — the bug was real from day one, just untested under the
  condition that revealed it (more than one user).

## The check, concretely

Before calling something done, actually do one of these — which one
depends on what "wrong" would look like:

- **A parser/regex/extraction change** → run it against the real input
  that motivated the change (not a hand-typed toy example), and against
  at least one other real input of the same kind that was already
  working, to confirm nothing else broke.
- **An external API integration** → make one real call with real
  credentials (safe/reversible if the API supports a draft/dry-run mode —
  use that; if the action is genuinely irreversible, this is exactly the
  case to slow down and ask before "verifying" by actually doing it).
  Reading the docs is not a substitute — this server's own experience is
  that undocumented validation rules are the norm, not the exception, for
  every bank API integrated so far.
- **A security control (hook, permission gate, access check)** → test
  both a case that should be blocked AND a case that should be allowed,
  not just the blocked case — a gate that blocks everything technically
  "works" but is useless, and this is the more common way these bugs
  hide (see the regex-backtracking example above: the failure was a gap
  in coverage, not an over-broad block, and would only show up by testing
  the specific variant that slipped through).
- **Anything touching more than one account/user/tenant** → verify with
  at least two, not one. A bug that only manifests with 2+ concurrent
  users (shared mutable state, a cache keyed wrong) is invisible under
  single-user testing by construction, not by bad luck.
- **A UI/bot flow change** → actually trigger it through the real
  interface (click the button, send the Telegram message) at least once,
  not just confirm the underlying function returns the right value in
  isolation — wiring bugs (wrong callback data, unregistered handler) are
  invisible to a unit-level check.

## What this is NOT

Not a call for exhaustive test suites on every change — a one-line typo
fix doesn't need a verification ceremony. The judgment call is about
*consequence and non-obviousness*: money, security, multi-tenant state,
and "the docs/API don't actually document the real behavior" are the
recurring shapes where skipping this step has actually cost real
debugging time on this server. When genuinely unsure whether a change
needs this, the fast heuristic is: would being wrong here be expensive or
embarrassing to discover later from the user instead of now? If yes,
verify now.
