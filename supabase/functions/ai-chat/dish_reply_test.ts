// deno test supabase/functions/ai-chat/dish_reply_test.ts
import { assertEquals } from "jsr:@std/assert@1";
import type { DishOutcome, DishRow } from "../_shared/dish_search.ts";
import { chatMessageFor, dishLines, legacyKeyword, venuesPhrase } from "./dish_reply.ts";

function row(name: string, shop: string): DishRow {
  return {
    id: `${shop}/${name}`,
    name,
    description: null,
    price: 10,
    discount_price: null,
    image_url: null,
    category: null,
    is_spicy: null,
    is_vegetarian: null,
    preparation_time: null,
    restaurant_id: shop,
    restaurant_name: shop,
    restaurant_image_url: null,
    restaurant_rating: null,
    restaurant_delivery_time_min: null,
    restaurant_delivery_fee: null,
    restaurant_is_open: true,
    score: 1,
  };
}

const calzone: DishOutcome = { dish: "calzone", rows: [row("Calzone", "Texas food")] };
const malfoufMissing: DishOutcome = { dish: "malfouf thon", rows: [] };
const malfoufFound: DishOutcome = {
  dish: "malfouf thon",
  rows: [row("Malfouf Thon", "plan b"), row("Malfouf Thon", "Piccolo Mondo")],
};

Deno.test("the example from the brief, in French", () => {
  assertEquals(
    chatMessageFor("Voici ce que j'ai trouvé 🌯", [calzone, malfoufMissing], "fr"),
    "Calzone : trouvé chez Texas food.\nMalfouf thon : pas disponible pour le moment.",
  );
});

Deno.test("Derja stays Derja", () => {
  assertEquals(
    dishLines([calzone, malfoufMissing], "tn"),
    "Calzone: famma 3and Texas food.\nMalfouf thon: mouch disponible tw.",
  );
});

Deno.test("everything found, several dishes: model message kept, then the lines", () => {
  assertEquals(
    chatMessageFor("Behi! Nchouf lek 🌯", [malfoufFound, calzone], "tn"),
    "Behi! Nchouf lek 🌯\n\nMalfouf thon: famma 3and plan b w Piccolo Mondo.\nCalzone: famma 3and Texas food.",
  );
});

Deno.test("one dish found: the model message alone", () => {
  assertEquals(chatMessageFor("Calzone, bon choix 🍕", [calzone], "fr"), "Calzone, bon choix 🍕");
});

Deno.test("nothing found: the lines plus a hint, the model's promise dropped", () => {
  assertEquals(
    chatMessageFor("Voici les sushis disponibles 🍣", [{ dish: "sushi", rows: [] }], "fr"),
    "Sushi : pas disponible pour le moment.\nEssayez un autre plat ou un autre restaurant.",
  );
});

Deno.test("a missing dish under a budget says the budget", () => {
  assertEquals(
    dishLines([malfoufMissing], "fr", 5),
    "Malfouf thon : rien sous 5 TND pour le moment.\nEssayez un autre plat ou un autre restaurant.",
  );
});

Deno.test("venues: two, three, more", () => {
  assertEquals(venuesPhrase(["A", "B"], "fr"), "A et B");
  assertEquals(venuesPhrase(["A", "B", "C"], "en"), "A, B and C");
  assertEquals(venuesPhrase(["A", "B", "C", "D", "E"], "fr"), "A, B, C et 2 autres");
});

Deno.test("legacyKeyword: unique names, no PostgREST-breaking characters", () => {
  assertEquals(
    legacyKeyword([row("Malfouf Thon", "plan b"), row("Malfouf Thon", "x"), row("Calzone", "t")]),
    "Malfouf Thon, Calzone",
  );
  assertEquals(legacyKeyword([row("Malfouf Cordon Bleu (S)", "t")]), null);
});
