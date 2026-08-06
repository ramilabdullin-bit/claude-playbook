---
name: marketplace-integration-pattern
description: Use when adding a new marketplace/e-commerce platform client (a third marketplace beyond Wildberries/Ozon, or any new seller-API integration) to marketplace-agents, or building a similar price/stock-polling integration elsewhere on this server. Also use when asked "how do we add a new marketplace" or "add Ozon feedbacks support".
---

# Adding a marketplace client (WB/Ozon pattern)

`/root/marketplace-agents/api.py` already implements this pattern twice
(`WildberriesClient`, `OzonClient`) behind `MarketplaceClient`, which picks
a client at startup by which API keys are present. Read
`/root/marketplace-agents/CLAUDE.md` first — it has the current routes,
model, and known limitations (no auth on the API itself, Ozon is read-only
so far). Don't re-derive that from `api.py` from scratch; the CLAUDE.md
already distills it.

## Steps to add a new marketplace

1. **New client class**, same shape as `WildberriesClient`/`OzonClient`:
   - `fetch_price_and_stock(sku) -> (price, stock)` — required.
   - `update_price(sku, new_price)` — optional; omit if the platform's API
     doesn't support it yet, `MarketplaceClient.update_price` already
     raises `NotImplementedError` for clients missing the method (checked
     via `hasattr`), no need to add error handling for that in the new
     class.
   - `fetch_unanswered_feedbacks(limit)` / `answer_feedback(id, text)` —
     optional, same pattern.
2. **Auth**: put the header/token scheme in `__init__`, matching whatever
   the platform's docs specify — don't assume Bearer-prefix; WB uses a raw
   token, Ozon uses two headers. Verify against official docs before
   trusting the response shape (both existing clients have a docstring
   linking the official API reference — do the same for the new one, and
   flag anything inferred rather than doc-confirmed, as those two do).
3. **Rate limits**: if the platform rate-limits (WB's price endpoint is
   ~1 req/2min), do NOT add ad-hoc sleep/retry logic in the route handler —
   the existing `PriceSnapshot` cache in `get_current_price`
   (`PRICE_CACHE_TTL`, 5 min) already exists for this; a new client just
   needs `_request_with_retry` (already generic, handles 429/5xx with
   `Retry-After`/backoff) — reuse it, don't reimplement.
4. **Register in `MarketplaceClient.__init__`**: add a branch keyed on the
   new settings fields (add `<platform>_api_key` etc. to `config.py`
   `Settings`, and matching `.env` keys — document them, don't leave them
   undiscoverable). Keep the existing WB → Ozon → generic priority order
   unless the user says otherwise; a service picks ONE active client from
   whichever keys are present, it does not run multiple marketplaces at
   once currently — if the user wants multi-marketplace simultaneously,
   that's an architecture change beyond this pattern, flag it rather than
   silently bolting it on.
5. **No route/model changes needed** — `api.py`'s routes and the
   `Product`/`PriceSnapshot` models are already marketplace-agnostic
   through `MarketplaceClient`; adding a platform should not touch them.
6. **Unofficial/undocumented endpoints** (like WB's competitor-price
   search): if the new platform has no official way to get competitor
   pricing, it's acceptable to use an unofficial endpoint the platform's
   own frontend uses (as `fetch_wb_competitor_average` does) — but say so
   explicitly in a docstring, swallow errors to `(None, 0)` rather than
   raising, and update `marketplace-agents/CLAUDE.md` to note it can break
   without notice.
7. **Update `/root/marketplace-agents/CLAUDE.md`** — new platform, new
   `.env` keys, any new NotImplementedError gaps — the CLAUDE.md is the
   source of truth for the next session, not just this diff.
