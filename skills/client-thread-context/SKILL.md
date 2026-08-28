---
name: client-thread-context
description: Use when building or reviewing an autonomous/semi-autonomous client-reply agent (email, Telegram, VK, any channel) — anything that decides what to send a client based on incoming messages. Also use for "read the full conversation before replying", "бот дублирует сообщение клиенту", "переписку вели через ТГ, не нужно ещё раз отправлять запрос", "почему бот переспросил то, на что уже ответили", "why did the bot repeat itself to a client".
---

# Full conversation context before an autonomous reply

An agent that decides what to send a client by reacting to the latest
inbound message plus its own internal state flags will duplicate, repeat,
or re-ask things whenever a human — the business owner, an employee, or
the client themself — handled part of the conversation somewhere the
agent's own log doesn't cover. The agent isn't wrong about what it sees;
it's wrong about what it thinks is the *whole* conversation.

Five real incidents from one session building `leads-agent/tools/kp.py` +
`telegram-claude-bot/bot.py` (an autonomous email/Telegram KP-reply
engine for a fulfillment business) — the last one reached a live customer
before the owner caught and deleted it:

1. **Pure acknowledgments got a full reply anyway.** A client wrote
   "Спасибо! Вернусь с ОС)" (thanks, will follow up) — the autonomous
   poller saw "new message, 5+ minutes old" and resent the entire quote
   it had already sent. Fix: `needs_reply` field in the extraction
   schema — false for closing/acknowledgment messages with no new
   question or data, checked before any pricing/escalation logic runs.
2. **The owner's own replies were invisible to the bot.** Telegram
   Business API relays both directions of a chat as the same event type
   — the bot's webhook handler dropped the owner's own outgoing messages
   (correctly, to avoid logging them as a new lead under his own id) but
   that meant the reply-generator had zero signal that the owner had
   already personally engaged, and restarted the scripted intro
   ("have you emailed us before?") on top of an already-progressed
   conversation. Fix: log the owner's own messages into the same
   thread-history the reply-generator reads (just not classified as a
   new lead), and gate the scripted intro on an `owner_engaged` flag.
3. **A canned decline got resent word-for-word.** A client asked "why
   won't you work with us?" after a templated decline — the code
   re-evaluated the same economics (unchanged) and picked the same
   decline branch, sending the identical paragraph again instead of
   answering the question. Fix: compare the candidate canned text
   against the last message *we* actually sent; if it's already there,
   send a follow-up/explanation variant instead of a literal repeat.
4. **A flag that only one code path can set, checked as if it means
   "already covered."** The bot's own `asked_email` flag only becomes
   true when the bot itself sends that question. A real client had
   already answered the equivalent question to the owner personally (by
   phone, unlogged) — the flag was still false, so the bot asked again,
   live, to a real prospect. The fix in incident 2 (log what's loggable)
   narrows this but doesn't close it entirely — anything genuinely
   out-of-band (a phone call) has no text to log at all. When you can't
   observe it, the fallback is: don't run the automated path on a real
   backlog thread without a human glancing at the last few messages
   first (see "Before calling it done" below).
5. **An unrelated forwarding script could have started a mail loop.** A
   separate integration (VK→email forwarder) sent mail *to itself*
   (`From` == `To` == the same inbox the reply-agent also reads). Nothing
   in the sync path excluded self-addressed mail, so the first real event
   would have collapsed every VK sender into one row and let the
   autonomous email-reply path answer the company's own mailbox — a
   loop, caught only by tracing the pipeline end-to-end before any real
   event had fired. Same root cause as the others: the reply agent only
   checks "is there a new inbound message", never "does this inbound
   message actually originate outside the system."

## The check

Before wiring (or reviewing) any autonomous or semi-autonomous send path
— a cron poller, an event-triggered auto-reply, a "continue this thread"
button — ask, for the specific client/thread:

- **What can make "this needs a reply" true or false that isn't the
  literal last inbound message?** A prior message in the same thread
  that already answers today's question. A pure acknowledgment with no
  actual ask. A human (owner, colleague, the client on another channel)
  who already resolved it.
- **Is every state flag that gates a scripted step set from *anything*
  that satisfies that step, or only from the one code path that normally
  performs it?** A flag like `asked_X` that's only true when *this
  system* asked X will misfire the moment X gets answered any other way.
  Prefer re-deriving "was X already covered" from the actual thread text
  (the classifier already reads it) over trusting a narrow boolean where
  you can.
- **Does every fixed/canned text branch (decline, holding message,
  escalation notice) check whether it's already the last thing sent,**
  before sending it again? If yes on repeat, branch to an explanation/
  follow-up variant instead of literal resend.
- **Can a human have handled this outside any channel your code reads**
  (phone, in person, handed off to a colleague)? You can't observe that
  programmatically — the mitigation is procedural, not code: don't let
  an autonomous path touch a real backlog thread for the first time
  without a human confirming per-thread first (draft, show it, get a
  yes), *especially* right after enabling autonomy on something that
  used to be manual — the backlog is exactly where out-of-band handling
  has had time to accumulate.
- **Does a completely unrelated integration write into the same inbox/
  thread-store your reply agent reads?** Check what else writes there,
  and whether any of it can be self-addressed or otherwise not a genuine
  external message.

## Fix pattern

```python
# needs_reply gate — before any pricing/escalation logic:
if not info.get("needs_reply", True) and not is_first_contact:
    return info, "", "", "skip"

# owner (or colleague) intervened out-of-band but on a loggable channel —
# log it into the same thread text the reply-generator reads, don't drop it:
if sender.id == get_owner_id():
    log_owner_reply(chat_id, msg.text)   # NOT classified as a new lead
    return

# scripted one-time step — gate on "has anything already covered this",
# not only on "did I personally ask this":
if not conn.get("asked_email") and not conn.get("owner_engaged"):
    ask_email_question()

# canned text — compare against what we actually last sent, not against
# our own re-derived decision:
def decline_or_followup(decline_text, followup_text, last_our_message):
    return followup_text if decline_text in last_our_message else decline_text
```

## Before calling it done

For any new automated reply path: simulate a thread where a human already
intervened out-of-band (inject a message as if from the owner/a
colleague, or manually mark the equivalent flag) and verify the automated
path continues coherently instead of restarting or repeating. Then —
separately — before flipping the switch from manual to autonomous on an
existing backlog of real threads, don't let the poller touch the backlog
cold: draft each one, show it, and get a specific go-ahead per thread the
first time. The backlog is where every prior out-of-band interaction is
concentrated; that's exactly where this class of bug fires.
