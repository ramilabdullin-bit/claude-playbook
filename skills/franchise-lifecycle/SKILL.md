---
name: franchise-lifecycle
description: Use when advising on or executing a franchise/partner-licensing rollout — granting a brand, proprietary software, and operating procedures to partners in new locations (e.g. "франшиза склада", "лицензировать бренд партнёрам", "открыть филиал по франшизе", "franchise our software"). Covers the full cycle: prerequisites, deal structure, term sheet, Russian legal structure (коммерческая концессия), technical readiness audit, onboarding, launch, ongoing royalty/support.
---

# Franchise / partner-licensing lifecycle

Established 2026-08-23 while building out e-comportal's warehouse franchise
(ВМС+PIM software + brand licensed to partners running fulfillment
warehouses in other cities). Reusable for any future "license our
brand+tech+process to a partner in a new location" deal — not specific to
warehouses. Checked GitHub first (per this repo's own playbook-first
policy) before writing this: no existing Claude Skill covers franchise
operations (checked `anthropics/skills` and the two most relevant
community repos, `claude-office-skills/skills` and `borghei/Claude-Skills`
— generic CRM/deal-approval tooling, nothing franchise-specific). This
skill is original, not adapted from anywhere.

## Stage checklist (skip stages already satisfied, don't redo)

1. **Prerequisites** — before drafting anything:
   - Trademark registered with Роспатент? Required for a valid
     коммерческая концессия (the Russian legal form of a franchise, ГК РФ
     гл. 54) granting brand rights — without it, the brand-use half of the
     deal has no legal footing. The software/SOP-only half doesn't need
     this.
   - Reference unit economics for the thing being franchised (revenue
     driver, fixed costs, tax regime of the unit) — needed to size the
     upfront fee and royalty so the deal is credible to a first-time
     partner.
2. **Deal structure** — split into separate contracts by what's actually
   granted, not one bundled "franchise agreement":
   - Software/IP license (лицензионный договор) — no Роспатент
     registration needed. If the licensor is an accredited IT company on
     reduced profit tax, this is also the revenue stream that keeps it
     under the qualifying-revenue threshold (ст. 284 НК РФ, ≥70% profile
     IT revenue) — brand/training/support revenue doesn't count toward
     that threshold.
   - Brand + know-how (SOP, training, quality control) — договор
     коммерческой концессии, registered with Роспатент.
3. **Financial terms** — паушальный взнос (upfront, split across the two
   contracts by what it actually pays for) + роялти (recurring, tied to a
   unit the licensor's own system already counts automatically — avoids
   revenue self-reporting disputes with the partner). Add a ramp-period
   minimum royalty floor if the metered unit takes months to reach target
   volume, rather than a discounted rate — keeps the formula simple and
   protects the licensor's support cost from day one.
4. **Territory & exclusivity** — define the radius/area and the
   non-compete term after termination explicitly. Leave the "revoke
   exclusivity if the partner systematically misses volume targets" clause
   explicit in the open-questions list rather than silently absent — it's
   easy to skip and expensive to discover missing later.
5. **Candidate qualification** — before pitching, screen each inbound
   request for: financial capacity to cover the upfront fee plus a few
   months of ramp-period runway, a suitable physical site, no conflict
   with an existing partner's exclusive territory.
6. **Term sheet** — negotiate structure and numbers with the candidate
   before a lawyer drafts binding contracts. State explicitly that it is
   not itself binding.
7. **Technical readiness audit** — walk the *live* software the partner
   will actually operate, don't just read the internal manual (internal
   docs assume tribal knowledge an external partner doesn't have). Check
   specifically:
   - **Data isolation between this partner and every other
     partner/unit.** The single most likely blocker when the software was
     originally internal-only — access control usually scopes by
     client/company, not by physical location/unit, so an operator at one
     site can often switch a filter and see another site's data. This is
     a security blocker, not a UX nit — resolve or explicitly choose a
     workaround (e.g. one deployed instance per partner instead of shared
     multi-tenancy) before granting access.
   - Whether the operational manual covers the modules the partner's
     floor staff will use day to day (warehouse ops, scanning, fulfillment
     tasks), not only the office-facing modules (catalog, pricing,
     reporting) that internal teams historically documented first.
8. **Contract signing** — both contracts; the concession contract
   registered with Роспатент.
9. **Onboarding** — SOP handoff, staff training/certification, technical
   setup per the architecture decision from stage 7.
10. **Launch** — soft-launch one partner alone before templating to the
    rest of a batch of simultaneous inbound requests. Fix the SOP based on
    what actually broke in the pilot before replicating it.
11. **Ongoing** — royalty billing off the system's own counted units (no
    manual reconciliation), periodic quality audits, and a defined process
    for a partner missing volume targets (the ramp-period floor from stage
    3 covers early revenue risk; a later underperformance/exclusivity
    process still needs to exist explicitly, see stage 4).

## Working-artifact pattern

Two documents per deal, both drafted as term-sheet-style — never as final
signable contracts, say so explicitly and recommend lawyer/accountant
review before signing:
- a financial/legal term sheet (stage 6),
- a technical-readiness audit (stage 7), if the partner will operate
  existing internal software.

Publish both as Artifacts for shareability. If the owner also wants them
in Telegram, send directly via the Telegram Bot API (bot token + the
owner's chat_id from the admin bot's `data/owner.json`) rather than
routing through the bot's own file-send mechanism — that mechanism only
fires for replies generated by the bot's own `claude` subprocess, not for
another Claude Code session acting on the same server.

## Don't

- Don't bundle brand + software + services revenue into one contract if
  the licensor's IT-accreditation tax status matters — see stage 2.
- Don't assume internal admin/ops software's access-control model already
  isolates external partners from each other — verify explicitly, live,
  stage 7.
- Don't sign multiple partner deals off one unvalidated template — pilot
  one first, stage 10.
