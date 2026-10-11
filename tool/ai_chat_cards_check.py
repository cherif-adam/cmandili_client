"""Amana Assistant — does a category question actually produce cards?

Asks the DEPLOYED ai-chat function one question per catalogue, then replays
the client's tiered catalogue query exactly as AiChatService._queryShopItems
does it:

    tier 1   category + keyword + price     (what the model asked for)
    tier 2   category + price               (keyword dropped)
    tier 3   price only                     (sub-category dropped too)

Price bounds are never dropped. A catalogue that has stock must never end up
with zero cards; if it does, that is a regression.

Usage:  python tool/ai_chat_cards_check.py <SUPABASE_URL> <ANON_KEY>
Exit status is non-zero if any catalogue with stock yields no cards.
Read-only: GETs on PostgREST plus one POST per question. No writes.
"""
import json
import sys
import time
import urllib.parse
import urllib.request

URL = sys.argv[1].rstrip("/")
KEY = sys.argv[2]

QUESTIONS = [
    ("flowers", "Je peux commander un bouquet de fleur"),
    ("pets", "je peux acheter des produits d'animalerie ?"),
    ("electronics", "je cherche un chargeur de telephone"),
    ("gifts", "un cadeau pour ma mère"),
    ("bakery", "je veux un gâteau d'anniversaire"),
    ("grocery", "il me faut du lait et du shampoing"),
]


def post_fn(text, tries=4):
    """The function 502s when the upstream LLM hiccups; retry before failing."""
    last = None
    for attempt in range(tries):
        req = urllib.request.Request(
            f"{URL}/functions/v1/ai-chat",
            data=json.dumps({"text": text, "history": []}).encode(),
            headers={"Authorization": f"Bearer {KEY}",
                     "Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                return json.load(r)
        except Exception as e:  # noqa: BLE001 - probe: report, don't crash
            last = e
            time.sleep(2 + 3 * attempt)
    return {"_error": str(last)[:70]}


def rows(slug, keyword=None, category=None):
    params = [
        ("select", "id,name,vendors!inner(name,is_open,category)"),
        ("is_available", "eq.true"),
        ("vendors.category", f"eq.{slug}"),
        ("order", "price.asc"),
        ("limit", "20"),
    ]
    if category:
        params.append(("category", f"ilike.*{category}*"))
    if keyword:
        params.append(
            ("or", f"(name.ilike.*{keyword}*,description.ilike.*{keyword}*)"))
    q = urllib.parse.urlencode(params, safe="*(),.")
    req = urllib.request.Request(
        f"{URL}/rest/v1/vendor_items?{q}",
        headers={"apikey": KEY, "Authorization": f"Bearer {KEY}"},
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        got = json.load(r)
    return [x for x in got if x.get("vendors", {}).get("is_open")]


def tiered(slug, keyword, category):
    """Mirror of _queryShopItems: returns (cards, tier_index)."""
    attempts = [(keyword, category)]
    if keyword:
        attempts.append((None, category))
    if category:
        attempts.append((None, None))
    for i, (kw, cat) in enumerate(attempts):
        got = rows(slug, kw, cat)
        if got:
            return got, i
    return [], -1


def main():
    print(f"{'slug':12} {'keyword':<20} {'cat':<10} {'tier':>4} {'cards':>6} "
          f"{'stock':>6}  verdict")
    print("-" * 88)
    failures = []
    for expected, q in QUESTIONS:
        d = post_fn(q)
        if "_error" in d:
            print(f"{expected:12} {'FUNCTION ERROR':<20} {'-':<10} {'-':>4} "
                  f"{'-':>6} {'-':>6}  {d['_error']}")
            failures.append(f"{expected}: function error")
            continue
        slug = d.get("service_category") or expected
        kw, cat = d.get("keyword"), d.get("category")
        cards, tier = tiered(slug, kw, cat)
        stock = len(rows(slug))
        if not cards and stock:
            verdict = "REGRESSION: stock but no cards"
            failures.append(f"{slug}: {stock} items, 0 cards")
        elif not cards:
            verdict = "catalogue genuinely empty"
        else:
            verdict = "exact match" if tier == 0 else f"relaxed (tier {tier + 1})"
        print(f"{slug:12} {str(kw)[:20]:<20} {str(cat)[:10]:<10} "
              f"{tier + 1:>4} {len(cards):>6} {stock:>6}  {verdict}")

    print()
    if failures:
        print("FAILED:")
        for f in failures:
            print(f"  - {f}")
        return 1
    print("Every catalogue with stock produced cards.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
