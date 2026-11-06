// deno test supabase/functions/_shared/dish_search_test.ts
import { assertEquals } from "jsr:@std/assert@1";
import {
  containsAllWords,
  type DishRow,
  findDishes,
  normalizeText,
  parseBudget,
  type RpcClient,
  splitHard,
  splitSoft,
  toFoodItemRow,
  uniqueRows,
} from "./dish_search.ts";

function row(id: string, name: string, shop = "Texas food"): DishRow {
  return {
    id,
    name,
    description: null,
    price: 10,
    discount_price: null,
    image_url: null,
    category: "Sandwiches",
    is_spicy: false,
    is_vegetarian: false,
    preparation_time: 15,
    restaurant_id: `r-${shop}`,
    restaurant_name: shop,
    restaurant_image_url: null,
    restaurant_rating: 0,
    restaurant_delivery_time_min: 30,
    restaurant_delivery_fee: 2,
    restaurant_is_open: true,
    score: 1,
  };
}

/** A fake search_dishes: answers from a menu, records every query. */
function fakeDb(menu: Record<string, DishRow[]>) {
  const queries: string[] = [];
  const db: RpcClient = {
    rpc(_fn, args) {
      const q = normalizeText(String(args.p_query));
      queries.push(q);
      return Promise.resolve(menu[q] ?? []);
    },
  };
  return { db, queries };
}

Deno.test("splitHard: commas, plus, semicolons; numbers stay whole", () => {
  assertEquals(splitHard("malfouf thon, calzone"), ["malfouf thon", "calzone"]);
  assertEquals(splitHard("pizza + coca ; frites"), ["pizza", "coca", "frites"]);
  assertEquals(splitHard("Coca 1,5L"), ["Coca 1,5L"]);
  assertEquals(splitHard("1/2 poulet"), ["1/2 poulet"]);
  assertEquals(splitHard("pizza/calzone"), ["pizza", "calzone"]);
  assertEquals(splitHard("calzone, Calzone"), ["calzone"]);
  assertEquals(splitHard(null), []);
});

Deno.test("splitSoft: et / w / and / ou, never inside a word", () => {
  assertEquals(splitSoft("malfouf thon et calzone"), ["malfouf thon", "calzone"]);
  assertEquals(splitSoft("malfouf thon w calzone"), ["malfouf thon", "calzone"]);
  assertEquals(splitSoft("pizza and burger"), ["pizza", "burger"]);
  assertEquals(splitSoft("omelette"), ["omelette"]);
  assertEquals(splitSoft("chawarma"), ["chawarma"]);
});

Deno.test("findDishes: a glued request is split only because the whole found nothing", async () => {
  const { db, queries } = fakeDb({
    "malfouf thon": [row("1", "Malfouf Thon", "plan b"), row("2", "Malfouf Thon", "Piccolo Mondo")],
    "calzone": [row("3", "Calzone")],
  });
  const out = await findDishes(db, "malfouf thon et calzone", null, { openOnly: true });
  assertEquals(out.map((o) => [o.dish, o.rows.length]), [["malfouf thon", 2], ["calzone", 1]]);
  assertEquals(queries, ["malfouf thon et calzone", "malfouf thon", "calzone"]);
});

Deno.test("findDishes: 'thon et fromage' that exists stays ONE dish", async () => {
  const { db, queries } = fakeDb({ "malfouf thon et fromage": [row("1", "Malfouf Thon Fromage")] });
  const out = await findDishes(db, "malfouf thon et fromage", null, { openOnly: true });
  assertEquals(out.map((o) => o.dish), ["malfouf thon et fromage"]);
  assertEquals(queries.length, 1);
});

Deno.test("findDishes: a missing dish is reported, never filled", async () => {
  const { db } = fakeDb({ "calzone": [row("3", "Calzone")] });
  const out = await findDishes(db, "sushi, calzone", null, { openOnly: true });
  assertEquals(out.map((o) => [o.dish, o.rows.length]), [["sushi", 0], ["calzone", 1]]);
});

Deno.test("findDishes: a lone dish is first tried with the category in front", async () => {
  const { db, queries } = fakeDb({ "pizza thon": [row("9", "Pizza Thon")] });
  const out = await findDishes(db, "thon", "pizza", { openOnly: true });
  assertEquals(out.map((o) => o.dish), ["pizza thon"]);
  assertEquals(queries, ["pizza thon"]);
});

Deno.test("findDishes: the category is dropped when it finds nothing", async () => {
  const { db, queries } = fakeDb({ "calzone": [row("3", "Calzone")] });
  const out = await findDishes(db, "calzone", "pizza", { openOnly: true });
  assertEquals(out.map((o) => o.dish), ["calzone"]);
  assertEquals(queries, ["pizza calzone", "calzone"]);
});

Deno.test("findDishes: no refinement when the dish already names the category", async () => {
  const { db, queries } = fakeDb({ "burger": [row("4", "Burger")] });
  await findDishes(db, "burger", "burger", { openOnly: true });
  assertEquals(queries, ["burger"]);
});

Deno.test("uniqueRows: each dish once, per-dish and total caps", () => {
  const a = row("1", "A");
  const b = row("2", "B");
  const c = row("3", "C");
  const rows = uniqueRows([{ dish: "x", rows: [a, b, c] }, { dish: "y", rows: [b, c] }], 2, 3);
  assertEquals(rows.map((r) => r.id), ["1", "2", "3"]);
});

Deno.test("toFoodItemRow: the shape both apps parse", () => {
  const r = toFoodItemRow(row("1", "Calzone"));
  assertEquals(r.restaurant_id, "r-Texas food");
  assertEquals((r.restaurants as Record<string, unknown>).name, "Texas food");
  assertEquals((r.restaurants as Record<string, unknown>).is_open, true);
});

Deno.test("parseBudget: units and phrases; the amount leaves the search text", () => {
  assertEquals(parseBudget("n7eb pizza b 20d"), { maxPrice: 20, rest: "n7eb pizza b" });
  assertEquals(parseBudget("chapati moins de 10"), { maxPrice: 10, rest: "chapati" });
  assertEquals(parseBudget("makloub a9al mn 12 dt"), { maxPrice: 12, rest: "makloub" });
  assertEquals(parseBudget("pizza 4 fromages").maxPrice, null);
  assertEquals(parseBudget("calzone").maxPrice, null);
});

Deno.test("normalizeText / containsAllWords", () => {
  assertEquals(normalizeText("  Bœuf Épicé (XL) — l'harissa "), "boeuf epice xl l harissa");
  assertEquals(containsAllWords("Pizza Thon", "pizza"), true);
  assertEquals(containsAllWords("thon", "pizza"), false);
  assertEquals(containsAllWords("pizzas thon", "pizza"), true);
});
