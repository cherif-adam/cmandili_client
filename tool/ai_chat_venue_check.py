"""Venue search — does a KIND OF PLACE reach the restaurants that sell it?

Replays, against the live database, the query `_fetchRestaurantsSelling`
builds and the fold `restaurantCardsFromItemRows` performs, then asserts the
things the unit tests cannot: that the real catalogue really does answer these
concepts, and that the venues whose NAME says "pizza" are not the only ones
found.

Read-only: SELECTs on food_items/restaurants, no writes, no LLM calls.

Usage (via the probe): bash tool/ai_chat_category_probe.sh venues
"""
import collections
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

# Mirrors AiChatService._kFoodConcepts for the concepts under test. Kept short
# on purpose: this script checks the DATA answers, the Dart tests check the
# map itself.
CONCEPTS = {
    "pizzeria": ["pizza"],
    "fast food": ["burger", "sandwich", "chapati", "makloub", "malfouf",
                  "mlewi", "mlawi", "tabouna", "cornet", "baguette farcie",
                  "tacos"],
    "resto tunisien": ["makloub", "malfouf", "mlewi", "mlawi", "tabouna",
                       "chapati", "baguette farcie", "cornet", "lablabi"],
}

# A venue search for "pizzeria" must reach these, and must NOT be limited to
# the two whose name contains "pizza" — that was the bug.
MUST_INCLUDE = {
    "pizzeria": ["Seven pizza Kairouan", "mecano pizza Kairouan"],
}

SELECT = ("name,category,price,restaurant_id,"
          "restaurants!inner(id,name,rating,is_open)")


def get(url, key, path, params):
    qs = urllib.parse.urlencode(params)
    req = urllib.request.Request(
        f"{url}/rest/v1/{path}?{qs}",
        headers={"apikey": key, "Authorization": f"Bearer {key}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        print(f"  HTTP {e.code}: {e.read().decode()[:160]}")
        return None


def venues_selling(url, key, patterns):
    ors = ",".join(f"category.ilike.%{p}%,name.ilike.%{p}%" for p in patterns)
    return get(url, key, "food_items", {
        "select": SELECT,
        "is_available": "eq.true",
        "restaurants.is_open": "eq.true",
        "or": f"({ors})",
        "limit": "400",
    })


def fold(rows, patterns, max_cards=15, max_hint=3):
    """Mirror of AiChatService.restaurantCardsFromItemRows."""
    def hits(value):
        return bool(value) and any(p.lower() in value.lower() for p in patterns)

    def covered(hints, cand):
        return any(h.lower() == cand.lower() or cand.lower() in h.lower()
                   or h.lower() in cand.lower() for h in hints)

    by_id = {}
    for r in rows:
        v = r.get("restaurants") or {}
        vid = str(v.get("id") or "")
        if not vid:
            continue
        cat, dish = (r.get("category") or "").strip(), (r.get("name") or "").strip()
        label = cat if hits(cat) else (dish if hits(dish) else (cat or dish))
        label = label or None
        e = by_id.get(vid)
        if e is None:
            by_id[vid] = {"v": v, "hints": [label] if label else [], "n": 1}
        else:
            if label and len(e["hints"]) < max_hint and not covered(e["hints"], label):
                e["hints"].append(label)
            e["n"] += 1
    ranked = sorted(by_id.values(),
                    key=lambda e: (-e["n"], -(e["v"].get("rating") or 0)))
    return ranked[:max_cards]


def main():
    url, key = sys.argv[1], sys.argv[2]
    failures = []

    total_open = get(url, key, "restaurants", {"select": "name", "is_open": "eq.true"})
    print(f"open restaurants right now: "
          f"{len(total_open) if total_open is not None else '?'}\n")

    for label, patterns in CONCEPTS.items():
        rows = venues_selling(url, key, patterns)
        if rows is None:
            failures.append(f'"{label}": query failed')
            continue
        cards = fold(rows, patterns)
        names = [c["v"]["name"] for c in cards]
        print(f'=== "{label}" -> {len(rows)} items, {len(cards)} restaurants')
        for c in cards:
            print(f'    {c["v"]["name"]:<24} {c["n"]:>3} items   '
                  f'hint="{", ".join(c["hints"])}"')

        if not cards:
            failures.append(f'"{label}": no venue at all, but the catalogue '
                            f'has items for it')
        for expected in MUST_INCLUDE.get(label, []):
            if expected not in names:
                failures.append(f'"{label}": expected {expected!r} among the '
                                f'venues, got {names}')
        # Every card must say why it is there.
        for c in cards:
            if not c["hints"]:
                failures.append(f'"{label}": {c["v"]["name"]} has no match hint')
        # The point of the change: not just the name matches.
        by_name_only = [n for n in names
                        if any(p.lower() in n.lower() for p in patterns)]
        if names and len(by_name_only) == len(names):
            failures.append(f'"{label}": every venue found also has the word '
                            f'in its NAME — the menu match is not working')
        print()

    print("-" * 60)
    if failures:
        print("FAILED:")
        for f in failures:
            print(f"  - {f}")
        sys.exit(1)
    print("venue search OK — concepts reach the restaurants that sell them")


if __name__ == "__main__":
    main()
