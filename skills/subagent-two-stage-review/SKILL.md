---
name: subagent-two-stage-review
description: Use when reviewing a non-trivial change before it ships — especially a new external integration, a payment/money-touching code path, or anything added to [[confirm-gated-integration]]'s scope — and a single self-review pass isn't enough assurance. Also use for "review this before we ship it", "второе мнение перед деплоем", "проверь и по спецификации, и по качеству кода". Runs two independent subagent passes instead of one combined one: does it do what was asked, then separately, is the code itself sound.
---

# Two separate review passes: spec-compliance, then code-quality

A single review pass tends to blend two different questions into one
judgment, and the blending is where things slip through: "does this
match what was asked" and "is this well-written, safe, maintainable" pull
attention in different directions, and a reviewer (human or model)
focused on one tends to under-weight the other in the same pass. Splitting
them into two independent subagent calls — each with a narrow mandate and
no visibility into the other's verdict — catches more than either alone,
because neither pass gets to rationalize a miss in its own lane as "the
other pass will catch it."

## When this earns the extra cost

Two full subagent passes cost more than one combined pass — reserve this
for changes where the cost of a miss is genuinely higher than the cost of
the extra review:

- A new bank/payment integration (see [[confirm-gated-integration]]) —
  this server's own experience is that these carry real, undocumented
  validation gotchas (Sber's `payerKpp` and `payee_bank_corr_account`
  issues, found only by a live test call) that a single read-through
  review is unlikely to catch by inspection alone.
- A change to shared state that could affect more than one user/account
  (the kind of bug [[verification-before-completion]] documents — a
  single reviewer focused on "does this do the task" can miss that the
  state is now shared across users, because that's a different lens).
- A new security-relevant hook or gate ([[destructive-command-gate]],
  [[secret-file-guard]]) — spec-compliance ("does it block what it's
  supposed to") and code-quality ("is the regex actually correct, no
  bypass") are genuinely different failure modes worth separating.

Not worth it for routine bug fixes, small features, or anything where a
single self-review (test it, read the diff once) already gives adequate
confidence — most changes on this server don't need this weight.

## How

Two separate `Task`/`Agent` calls, run sequentially (the second needs the
first's verdict as context, and running them concurrently risks both
missing the same thing for the same reason if they somehow converge on
the same blind spot):

**Pass 1 — spec compliance.** Fresh subagent, given the original request/
task description and the diff, with a narrow mandate: does this actually
do what was asked, completely, including edge cases implied but not
spelled out? Not asked to comment on code style/architecture at all —
that's out of scope for this pass on purpose.

**Pass 2 — code quality.** A *different* fresh subagent (or the
`code-reviewer` type if available), given only the diff (not necessarily
the original request), asked to review for correctness, safety,
maintainability — bugs, edge cases the code itself doesn't handle,
security issues, anything that would fail
[[verification-before-completion]]'s bar if run live. Deliberately not
told the outcome of Pass 1, so it isn't anchored by it.

Synthesize both verdicts into one final judgment before considering the
change reviewed — a passing Pass 1 and a passing Pass 2 independently are
a materially stronger signal than either alone, and where they disagree
(Pass 1 says done, Pass 2 finds a bug) is exactly the case this exists to
surface.

## What this doesn't replace

Not a substitute for [[verification-before-completion]]'s actual live
verification (running the real regex against real input, making the real
API call) — review catches what's visible by reading; verification
catches what's only visible by running. Do both for anything that
qualifies for this level of scrutiny in the first place.
