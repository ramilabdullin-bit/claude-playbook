---
name: composite-message-consistency
description: Use when building or reviewing a customer/user-facing message that is assembled from multiple independently-triggered pieces — LLM-generated free text plus deterministic template blocks/callouts, each with its own condition for whether it appears. Also use for "why did the message contradict itself", "add a new callout/note to an auto-reply", "уведомление противоречит себе".
---

# Composite message consistency

An automated message that's built by concatenating independent
blocks/paragraphs (some from an LLM call, some hardcoded strings gated by
`if` conditions) will drift into self-contradiction over time, because each
block gets added/edited in isolation without anyone re-reading the whole
message with fresh eyes. Two concrete real bugs from one session building a
KP-reply engine (`leads-agent/tools/kp.py`):

1. **LLM text vs. deterministic code, generated at different times with
   different information.** The LLM answered a client's literal question
   ("do you take new clients?") based only on COMPANY_FACTS, before the
   code had computed whether this specific client falls into a paused
   capacity tier. Two paragraphs later, the deterministic capacity-note
   block said the opposite. The LLM was never wrong about the facts it had
   — it just didn't have the fact that mattered, because that fact isn't
   decided until later in the pipeline.
2. **Two deterministic blocks, each individually correct, added on
   different days.** `INDIVIDUAL_NOTE` ("happy to discuss custom terms")
   was unconditional. `CAPACITY_NOTE` ("we're not taking new contracts of
   this size right now") was added later for a different reason. Neither
   block is wrong on its own. Together, in the same message, "happy to
   discuss custom terms" directly before "not taking new business right
   now" reads as either confused or dishonest to the recipient.

Both bugs shipped, were tested (unit tests for each block's *own*
condition passed), and were only caught when a human read the full
composed message end to end.

## The check

Before treating a change to a composed-message system as done — new block,
new condition, new LLM-answerable field — enumerate every block that CAN
co-occur with the one you're touching (same code path, conditions not
mutually exclusive on their face) and ask, for each pair: **read both
sentences back to back as the recipient would — do they assert or imply
opposite things?** Not "are both individually true" — a pause notice and a
willingness-to-discuss notice are both individually true and still
contradictory together.

Specific patterns to watch for:
- **A yes/no or status claim that both an LLM prompt and deterministic
  code can independently produce for overlapping subject matter**
  (capacity, availability, pricing, eligibility, timelines). If the LLM
  answers general questions from a fact sheet and code separately decides
  a status via later logic (classification, thresholds), the LLM's prompt
  needs an explicit denylist: "never answer questions about X, that's
  decided downstream" — don't rely on the fact sheet simply not mentioning
  it, because the LLM will still reason from adjacent context.
- **A block added under one code path assuming it's unconditional**, when
  a later block added under a different, unrelated code path can make that
  assumption false. Search for the block's own trigger condition, then
  search the rest of the function for `if`/`elif` branches whose condition
  isn't the pure negation of it — those are the co-occurrence risk.
- **Politeness/offer language ("happy to help further", "let us know")
  stacked against a hard constraint stated elsewhere** in the same
  message (paused, declined, unavailable, over budget) — these read as
  contradictory even when technically about different things, because the
  recipient reads them as one continuous voice.

## Fix pattern

Make the co-occurring blocks **mutually exclusive by construction**, not
by hoping their conditions never overlap:

```python
on_pause = <condition B>
if not on_pause:
    blocks.append(block_a)   # was unconditional — that was the bug
if on_pause:
    blocks.append(block_b)
```

For LLM-vs-code conflicts, exclude the topic from the LLM's domain
explicitly in the prompt, and give a one-line reason so it doesn't get
"corrected" back in later: *"never answer district X, that's decided by Y
after this call returns."*

## Before calling it done

Render the actual final text (not just check that each block's unit test
passes) for at least one scenario where the newly-added/changed block
co-occurs with each of its neighbors, and read it top to bottom as the
recipient would. This is the step that was skipped both times in the
session that produced this skill — every individual block was correct and
tested, the composed message wasn't.
