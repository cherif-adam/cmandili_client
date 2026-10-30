// deno test supabase/functions/ai-search/search_filters_test.ts
//
// The query that exposed the bug (phone test, 25/10/2026):
//   "N7eb chapati 7arra matfoutch 10 dt"
//   -> intent { category: "sandwich", keyword: "chapati", spicy: true, max_price: 10 }
// On the live menu: 35 chapatis, all <= 10 DT, 4 of them flagged spicy, and
// only ONE filed under a "Sandwiches" section. Requiring the guessed category
// AND the keyword returned that one dish only.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { diversifyByShop, keywordPattern, taxonomyFilter } from "./search_filters.ts";

interface Row {
  name: string;
  description: string;
  category: string;
  is_spicy: boolean;
  price: number;
}

// Shaped like the live rows: same names, menu sections, flags and prices.
const MENU: Row[] = [
  { name: "Chapati Poulet", description: "", category: "Sandwiches", is_spicy: true, price: 9 },
  { name: "Chapati omlette Merguez", description: "", category: "Chapati", is_spicy: true, price: 3.5 },
  { name: "Chapati omlette Merguez", description: "", category: "Chapati", is_spicy: true, price: 3.5 },
  { name: "Chapati omlette Merguez", description: "", category: "Chapati", is_spicy: true, price: 3.5 },
  { name: "Chapati omlette Thon", description: "", category: "Chapati", is_spicy: false, price: 2.5 },
  { name: "Chapati spécial", description: "", category: "Chapati", is_spicy: false, price: 4 },
  { name: "Chapatti Extra", description: "", category: "Chapati", is_spicy: false, price: 4.5 },
  // Not chapatis: a spicy sandwich must NOT come back for "chapati".
  { name: "Sandwich Merguez", description: "harissa", category: "Sandwiches", is_spicy: true, price: 6 },
  // A chapati over budget.
  { name: "Chapati Royal", description: "", category: "Chapati", is_spicy: true, price: 12 },
];

const INTENT = { category: "sandwich", keyword: "chapati", spicy: true, max_price: 10 };

/** What PostgREST does with the filters the function builds (tier 1). */
function newFilter(rows: Row[], intent: typeof INTENT, spicy: boolean): Row[] {
  const taxonomy = taxonomyFilter(intent);
  return rows.filter((r) => {
    if (taxonomy?.kind === "keyword") {
      const re = new RegExp(keywordPattern(intent.keyword)!, "i");
      if (![r.name, r.description, r.category].some((v) => re.test(v))) return false;
    } else if (taxonomy?.kind === "category") {
      if (!r.category.toLowerCase().includes(intent.category.toLowerCase())) return false;
    }
    if (spicy && intent.spicy && !r.is_spicy) return false;
    return r.price <= intent.max_price;
  });
}

/** The filters before the fix: guessed category AND keyword. */
function oldFilter(rows: Row[], intent: typeof INTENT): Row[] {
  return rows.filter((r) =>
    r.category.toLowerCase().includes(intent.category) &&
    (r.name + " " + r.description).toLowerCase().includes(intent.keyword) &&
    r.is_spicy && r.price <= intent.max_price
  );
}

Deno.test("the bug: the old filters kept 1 spicy chapati out of 4", () => {
  assertEquals(oldFilter(MENU, INTENT).map((r) => r.name), ["Chapati Poulet"]);
});

Deno.test("'n7eb chapati 7arra matfoutch 10 dt' returns every spicy chapati under 10 DT", () => {
  const got = newFilter(MENU, INTENT, true).map((r) => r.name).sort();
  assertEquals(got, [
    "Chapati Poulet",
    "Chapati omlette Merguez",
    "Chapati omlette Merguez",
    "Chapati omlette Merguez",
  ]);
});

Deno.test("without '7arra' every chapati under 10 DT comes back, whatever its menu section", () => {
  const got = newFilter(MENU, { ...INTENT, spicy: false }, false).map((r) => r.name);
  assertEquals(got.length, 7);
  assert(!got.includes("Sandwich Merguez"), "an unrelated sandwich came back");
  assert(!got.includes("Chapati Royal"), "an over-budget dish came back");
});

Deno.test("the named dish wins over the guessed category", () => {
  const f = taxonomyFilter({ category: "sandwich", keyword: "chapati" });
  assertEquals(f?.kind, "keyword");
  assertEquals(
    f?.kind === "keyword" ? f.or : "",
    'name.imatch."c+h+a+p+a+t+i+",description.imatch."c+h+a+p+a+t+i+",category.imatch."c+h+a+p+a+t+i+"',
  );
});

Deno.test("the guessed category is still used when no dish is named", () => {
  assertEquals(taxonomyFilter({ category: "pizza", keyword: null }), { kind: "category", pattern: "%pizza%" });
  assertEquals(taxonomyFilter({ category: null, keyword: "  " }), null);
});

Deno.test("spellings: chapati, chapatti, chappati, CHAPATI all match", () => {
  for (const kw of ["chapati", "chapatti", "chappati", "CHAPATI"]) {
    assertEquals(keywordPattern(kw), "c+h+a+p+a+t+i+", kw);
  }
  const re = new RegExp(keywordPattern("chapati")!, "i");
  for (const name of ["Chapati Poulet", "chapatti", "Chappati spécial", "Menu CHAPATI"]) {
    assert(re.test(name), name);
  }
  for (const name of ["Chocolat", "Chips", "Pizza 4 saisons"]) {
    assert(!re.test(name), name);
  }
});

Deno.test("Arabic and multi-word keywords; nothing unsafe reaches the filter", () => {
  assertEquals(keywordPattern("شباتي"), "ش+ب+ا+ت+ي+");
  assertEquals(keywordPattern("chapati poulet"), "c+h+a+p+a+t+i+.*p+o+u+l+e+t+");
  // Quotes, commas, parentheses and backslashes would break the PostgREST
  // filter string: they are dropped with the other non-letters.
  assertEquals(keywordPattern('pi"zza,(x)\\'), "p+i+.*z+a+.*x+");
  assertEquals(keywordPattern("!!!"), null);
});

// ── No shop hides the others (phone test, 30/10/2026) ────────────────────────
// "N7eb chapati w matfoutch 10 dt" came back as 10 plan b chapatis and 1 from
// Seven pizza. That was every chapati on the menu that day (the 24 others
// belonged to the two test shops hidden the same day), but nothing stopped the
// shop with the most matches from filling the screen.

interface Dish {
  id: string;
  shop: string;
}

/** The model's ranking: one shop's 30 matches first, three small shops after. */
function rankedDishes(): Dish[] {
  const dishes: Dish[] = [];
  for (let i = 1; i <= 30; i++) dishes.push({ id: `planb-${i}`, shop: "plan b" });
  dishes.push(
    { id: "seven-1", shop: "Seven pizza" },
    { id: "baguette-1", shop: "Baguette" },
    { id: "baguette-2", shop: "Baguette" },
    { id: "ali-1", shop: "Chez Ali" },
  );
  return dishes;
}

/** The first page: the 20 dishes the ranking model picks (RANK_SYSTEM_PROMPT). */
const FIRST_PAGE = 20;
const shops = (dishes: Dish[]) => new Set(dishes.map((d) => d.shop));

Deno.test("one shop with 30 matches no longer pushes the other shops off the first page", () => {
  const before = rankedDishes();
  assertEquals(shops(before.slice(0, FIRST_PAGE)), new Set(["plan b"]));

  const after = diversifyByShop(before, (d) => d.shop);
  assertEquals(shops(after.slice(0, FIRST_PAGE)), shops(before));
  // Each shop's best dish leads, in ranking order: every shop is on screen
  // before any shop shows a second dish.
  assertEquals(after.slice(0, 4).map((d) => d.id), ["planb-1", "seven-1", "baguette-1", "ali-1"]);
});

Deno.test("diversifying drops nothing, duplicates nothing and keeps each shop's order", () => {
  const before = rankedDishes();
  const after = diversifyByShop(before, (d) => d.shop);
  assertEquals(after.length, before.length);
  assertEquals(new Set(after.map((d) => d.id)).size, before.length);
  for (const shop of shops(before)) {
    assertEquals(after.filter((d) => d.shop === shop), before.filter((d) => d.shop === shop));
  }
  assertEquals(diversifyByShop([] as Dish[], (d) => d.shop), []);
});
