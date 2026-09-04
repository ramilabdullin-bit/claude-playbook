---
name: verify-api-returned-object
description: Use when writing or reviewing code that fetches ONE object from an external API by identifier — a marketplace card by nmID/product_id, a PIM product by id, an order, a customer. Also use for "почему пришёл не тот товар", "the API returned the wrong record", "фильтр по id не работает", or when building a resolve map between two id spaces. The failure is silent: you get 200 and a plausible object that belongs to someone else.
---

# The API answered — but about which object?

Three live cases on this server, three different mechanisms, one class of
bug. All of them return HTTP 200 with a well-formed body.

| Case | Mechanism | Found |
|---|---|---|
| WB `/content/v2/get/cards/list` | filter by `nmID` is IGNORED — returns the cabinet's FIRST card | 2026-09-03, nearly produced a false report of portal/WB divergence |
| PIM `/pim/products/wb/product/{id}` | body's own `id` is a DIFFERENT number than the addressable one (asked 4901663, body says 4901636, GET on 4901636 → 404) | 2026-09-04, would have built a dead resolve map |
| Ozon `product_id` vs WB `nmID` | separate number spaces, ranges overlap — one shared `id` field routes a WB number into the Ozon branch | 2026-09-04, would have generated content from a stranger's card |

None of these throw. You notice months later, from a customer.

## The three rules

**1. Verify the response is about what you asked for.** Never trust a
filter. After fetching, compare the identifying field and raise if it
differs:

```python
for card in resp.get("cards") or []:
    if str(card.get("nmID")) == str(nm_id):
        return card
raise LookupError(f"карточка {nm_id} не найдена: пришли "
                  f"{[c.get('nmID') for c in resp['cards']][:5]}")
```

**2. Store the address, not the body's self-report.** The id you can GET by
and the `id` field inside the payload are not necessarily the same value.
Keep them in separate, differently named fields (`portal_product_id` vs
`portal_record_id`) so nobody can confuse them later.

**3. One field per id space, never a shared `id`.** Name them
`product_id` / `nm_id` / `goods_id` — different names make the collision
impossible instead of merely unlikely. A shared field eventually carries
the wrong space's number, and there is no exception, only a wrong object.

## Cheap probe that proves which mechanism you face

Ask for an id that cannot exist:

```bash
GET /.../product/999999999   →  404  # honest: it refuses
                             →  200  # DANGER: it substitutes
```

Do the same for a filter: request an id you know, check what comes back.
Both probes are read-only and free, and settle in one minute whether you
need rule 1 or can rely on the endpoint.

## When to skip

List/search endpoints returning many objects, and idempotent writes where
you supply the key. This is about single-object reads by identifier.
