---
name: skill-rules-nudge
description: Use when adding a new skill to the playbook that has clear, distinctive trigger phrases and real consequence if missed — to decide whether it's worth adding a keyword entry to skill-rules.json. Also use for "why didn't you use the X skill", "skill triggering isn't reliable", "поставь детерминированный триггер для skill". This is the mechanism itself (a global UserPromptSubmit hook) — read this before adding, removing, or debugging an entry in skill-rules.json.
---

# Deterministic keyword nudge toward high-value skills

With enough skills in the playbook (18 as of 2026-08-28), relying purely
on the model matching a skill's `description` field mid-conversation
starts to have real failure cases — a relevant skill can simply not come
to mind on a given turn, especially deep into a long conversation with a
lot of other context competing for attention. This is a second, cheap,
deterministic layer underneath that: a global `UserPromptSubmit` hook
(`/root/.claude/settings.json` → `hooks.UserPromptSubmit`, script at
`skills/skill-rules-nudge/check-skill-rules.sh`) that greps the raw
prompt text against keyword/regex patterns in `skill-rules.json` and, on
a match, injects a short reminder via `additionalContext` — **never
blocks anything**, purely additive, exit 0 always.

Confirmed against official docs before building (not assumed):
`UserPromptSubmit` hooks return `{hookSpecificOutput:{hookEventName:
"UserPromptSubmit", additionalContext: "..."}}` to add context, have no
`permissionDecision`-style block option (only exit code 2 blocks, not
used here), and need no `matcher` key in `settings.json` (unlike
`PreToolUse`/`PostToolUse` — the event isn't tied to a tool, so there's
nothing to filter by).

## Why this is deliberately partial, not exhaustive

`skill-rules.json` currently covers about a dozen of the 18 skills —
specifically the ones with (a) real consequence if missed and (b)
distinctive enough trigger phrasing that keyword matching won't be noisy.
Left out on purpose:
- Skills already enforced by a hard technical hook regardless of whether
  they're "invoked" (`secret-file-guard`, `destructive-command-gate`) —
  the protection doesn't depend on the model remembering to call the
  skill, so a nudge adds little.
- Mindset/discipline skills with no natural keyword trigger
  (`verification-before-completion` would fire on nearly every "done"/
  "fixed" message — too noisy to be useful, the whole value of that skill
  is being a standing habit, not something triggered by a specific
  phrase).
- Content-specific tool skills (`mpstats`, `photo-editor`) whose
  descriptions are already narrow and reliable triggers on their own.

When adding a new skill, only add a `skill-rules.json` entry if it has
both properties above — most won't, and that's fine; this mechanism is a
supplement to description-matching, not a replacement for it.

## Format

```json
{
  "skill-name": {
    "keywords": ["regex pattern one", "another pattern"]
  }
}
```

Each entry in `keywords` is tested case-insensitively against the
lowercased prompt text via `jq`'s `test()` (Oniguruma regex, same engine
as [[destructive-command-gate]] and [[secret-file-guard]]) — plain
substrings work as literal matches, but regex metacharacters are live
(escape them if a keyword needs a literal `.`/`(`/etc. that isn't meant
as regex — none of the current entries need this, but it's not
sanitized). Multiple matched skills all get listed in one
`additionalContext` message, not one hook firing per skill.

## Testing a change (do this, not just "looks right")

**Never test by simulating a real prompt through the live session** — you
can't fire `UserPromptSubmit` from inside an already-running session
(hooks load at session start; see the playbook README's note that hook
changes need a session restart or `/hooks` to take effect). Instead pipe
fabricated input straight into the script, the same isolation principle
as [[destructive-command-gate]]'s test harness:

```bash
echo '{"user_prompt":"some test prompt text"}' | \
  /root/claude-playbook/skills/skill-rules-nudge/check-skill-rules.sh
```

Test at least: a prompt that should match (confirm the right skill name
appears), a prompt that shouldn't (confirm `{}`), an empty prompt, and
malformed input missing the `user_prompt` key entirely (confirm no crash
— the script must degrade to `{}` on anything unexpected, since a hook
erroring out is worse than a hook doing nothing).

## Known gaps

- **Not yet verified against a real live `UserPromptSubmit` firing** —
  built and unit-tested (the script's own logic, piped fake input) the
  same session it was added, but the actual end-to-end hook firing on a
  real prompt hasn't been observed yet, since that requires a fresh
  session (this one already had hooks loaded before the edit). Confirm
  this actually shows up as intended the first time a matching prompt is
  typed in a new session, and update this note with what was found.
- A reminder that's wrong often enough gets ignored — if a keyword set
  turns out noisy in practice (fires on unrelated prompts regularly),
  tighten or remove it rather than leaving a nudge nobody trusts anymore.
- Only reacts to the literal prompt text — a task that becomes relevant
  to a skill only after several turns of back-and-forth (not present in
  the original prompt) won't get nudged; this only fires once, on
  submission, per prompt.
