// Dish retrieval shared by ai-chat and ai-search, on top of the SQL function
// public.search_dishes (migration 20261106120000_recherche_plats_floue.sql):
// fuzzy, word-by-word, accent- and case-insensitive.
//
// What this file adds on top of the SQL:
//   - splitting a request into dishes ("malfouf thon et calzone" -> two
//     searches), carefully, because "thon et fromage" is ONE dish;
//   - refining a lone dish with the category the model guessed ("thon" +
//     "pizza" -> "pizza thon" first, then "thon" alone);
//   - the row shape the apps already read (food_items + embedded restaurants);
//   - a small budget parser for the mode without AI.

/** Minimal PostgREST RPC caller, so neither function needs supabase-js for it. */
export interface RpcClient {
  rpc(fn: string, args: Record<string, unknown>): Promise<unknown>;
}

/** The database answered with an error: the caller must not report "no match". */
export class DishSearchError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "DishSearchError";
  }
}

/** POST /rest/v1/rpc/<fn> with the service-role key. */
export function postgrestRpc(supabaseUrl: string, serviceRoleKey: string, fetchImpl = fetch): RpcClient {
  return {
    async rpc(fn, args) {
      let res: Response;
      try {
        res = await fetchImpl(`${supabaseUrl}/rest/v1/rpc/${fn}`, {
          method: "POST",
          headers: {
            apikey: serviceRoleKey,
            Authorization: `Bearer ${serviceRoleKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(args),
          signal: AbortSignal.timeout(15_000),
        });
      } catch (e) {
        throw new DishSearchError(`rpc ${fn} unreachable: ${e instanceof Error ? e.message : String(e)}`);
      }
      const raw = await res.text();
      if (!res.ok) throw new DishSearchError(`rpc ${fn} HTTP ${res.status}: ${raw.slice(0, 300)}`);
      try {
        return JSON.parse(raw);
      } catch {
        throw new DishSearchError(`rpc ${fn} returned non-JSON: ${raw.slice(0, 200)}`);
      }
    },
  };
}

/** One row of public.search_dishes. */
export interface DishRow {
  id: string;
  name: string;
  description: string | null;
  price: number;
  discount_price: number | null;
  image_url: string | null;
  category: string | null;
  is_spicy: boolean | null;
  is_vegetarian: boolean | null;
  preparation_time: number | null;
  restaurant_id: string;
  restaurant_name: string;
  restaurant_image_url: string | null;
  restaurant_rating: number | null;
  restaurant_delivery_time_min: number | null;
  restaurant_delivery_fee: number | null;
  restaurant_is_open: boolean;
  score: number;
}

export interface DishSearchOptions {
  maxPrice?: number | null;
  minPrice?: number | null;
  spicy?: boolean | null;
  vegetarian?: boolean | null;
  openOnly: boolean;
  matchDescription?: boolean;
  ignoreUnknownWords?: boolean;
  limit?: number;
}

/** What one requested dish found. [rows] is empty when nothing matched. */
export interface DishOutcome {
  /** The dish as the user (or the model) named it, for the reply text. */
  dish: string;
  rows: DishRow[];
}

/** Calls public.search_dishes for ONE dish. */
export async function searchDish(db: RpcClient, dish: string, opts: DishSearchOptions): Promise<DishRow[]> {
  const data = await db.rpc("search_dishes", {
    p_query: dish,
    p_max_price: opts.maxPrice ?? null,
    p_min_price: opts.minPrice ?? null,
    p_spicy: opts.spicy ?? null,
    p_vegetarian: opts.vegetarian ?? null,
    p_open_only: opts.openOnly,
    p_match_description: opts.matchDescription ?? false,
    p_ignore_unknown_words: opts.ignoreUnknownWords ?? false,
    p_limit: opts.limit ?? 20,
  });
  if (!Array.isArray(data)) throw new DishSearchError("search_dishes did not return a list");
  return data as DishRow[];
}

// ── Splitting ─────────────────────────────────────────────────────────────

/**
 * Never part of a dish name: always splits. A comma or slash between digits
 * is a number ("1,5L", "1/2 poulet"), not a separator.
 */
const HARD_SEPARATOR = /\s*(?:(?<!\d),|,(?!\d)|(?<!\d)\/|\/(?!\d)|[;+\n|]|\s-\s)\s*/u;

/**
 * Splits only when the whole phrase matched nothing: "malfouf thon et fromage"
 * is one dish on Tunisian menus, "malfouf thon et calzone" is two. Latin forms
 * of "and"/"or" in French, Derja and English, plus a standalone Arabic "و".
 */
const SOFT_SEPARATOR = /\s+(?:et|w|and|ou|or|&|و)\s+/iu;

const MAX_DISHES = 5;

function cleanSegments(parts: string[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const raw of parts) {
    const s = raw.replace(/\s+/gu, " ").trim().replace(/^[\s.!?،؟]+|[\s.!?،؟]+$/gu, "");
    if (s.length === 0) continue;
    const key = normalizeText(s);
    if (key.length === 0 || seen.has(key)) continue;
    seen.add(key);
    out.push(s);
  }
  return out;
}

export function splitHard(text: string | null | undefined): string[] {
  if (!text) return [];
  return cleanSegments(text.split(HARD_SEPARATOR)).slice(0, MAX_DISHES);
}

export function splitSoft(text: string): string[] {
  return cleanSegments(text.split(SOFT_SEPARATOR)).slice(0, MAX_DISHES);
}

/** Lower case, accents removed, punctuation -> space. Mirrors public.search_normalize. */
export function normalizeText(s: string): string {
  return s
    .normalize("NFD")
    .replace(/\p{M}+/gu, "")
    .replace(/œ/giu, "oe")
    .replace(/æ/giu, "ae")
    .toLowerCase()
    .replace(/[\s\p{P}\p{S}]+/gu, " ")
    .trim();
}

/** True when every word of [needle] already appears in [haystack]. */
export function containsAllWords(haystack: string, needle: string): boolean {
  const have = new Set(normalizeText(haystack).split(" "));
  const want = normalizeText(needle).split(" ").filter((w) => w.length > 0);
  return want.length > 0 && want.every((w) => have.has(w) || [...have].some((h) => h.startsWith(w)));
}

/**
 * Finds every dish named in [request]:
 *   1. hard split (commas...) — each part is a dish;
 *   2. a lone dish is first tried with the model's [category] in front
 *      ("thon" + "pizza" -> "pizza thon"); if that finds nothing, alone;
 *   3. a part that finds nothing whole is split on "et / w / and / ou" and
 *      each piece searched on its own.
 * A database error throws DishSearchError (never reported as "not found").
 */
export async function findDishes(
  db: RpcClient,
  request: string | null | undefined,
  category: string | null | undefined,
  opts: DishSearchOptions,
): Promise<DishOutcome[]> {
  const parts = splitHard(request);
  const out: DishOutcome[] = [];
  for (const part of parts) {
    if (out.length >= MAX_DISHES) break;
    if (parts.length === 1 && category && category.trim() && !containsAllWords(part, category)) {
      const refined = `${category.trim()} ${part}`;
      const rows = await searchDish(db, refined, opts);
      if (rows.length > 0) {
        out.push({ dish: refined, rows });
        continue;
      }
    }
    const whole = await searchDish(db, part, opts);
    if (whole.length > 0) {
      out.push({ dish: part, rows: whole });
      continue;
    }
    const pieces = splitSoft(part);
    if (pieces.length <= 1) {
      out.push({ dish: part, rows: [] });
      continue;
    }
    for (const piece of pieces) {
      if (out.length >= MAX_DISHES) break;
      out.push({ dish: piece, rows: await searchDish(db, piece, opts) });
    }
  }
  return out;
}

// ── Row shape the apps read ───────────────────────────────────────────────

/**
 * The `food_items` row with its embedded `restaurants`, exactly as both apps
 * already parse it (AiSearchFoodResult.fromJson, CatalogueSearch._foodCard).
 */
export function toFoodItemRow(r: DishRow): Record<string, unknown> {
  return {
    id: r.id,
    name: r.name,
    description: r.description,
    price: r.price,
    discount_price: r.discount_price,
    image_url: r.image_url,
    category: r.category,
    is_spicy: r.is_spicy,
    is_vegetarian: r.is_vegetarian,
    preparation_time: r.preparation_time,
    restaurant_id: r.restaurant_id,
    restaurants: {
      id: r.restaurant_id,
      name: r.restaurant_name,
      image_url: r.restaurant_image_url,
      rating: r.restaurant_rating,
      delivery_time_min: r.restaurant_delivery_time_min,
      delivery_fee: r.restaurant_delivery_fee,
      is_open: r.restaurant_is_open,
    },
  };
}

/** Rows of several outcomes, each dish once, in request order. */
export function uniqueRows(outcomes: DishOutcome[], perDish = Infinity, total = Infinity): DishRow[] {
  const seen = new Set<string>();
  const rows: DishRow[] = [];
  for (const o of outcomes) {
    let taken = 0;
    for (const r of o.rows) {
      if (rows.length >= total || taken >= perDish) break;
      if (seen.has(r.id)) continue;
      seen.add(r.id);
      rows.push(r);
      taken++;
    }
  }
  return rows;
}

// ── Budget, for the mode without AI ───────────────────────────────────────

/**
 * "20d", "20 dt", "moins de 20", "a9al mn 20", "taht 20", "max 20",
 * "under 20", "أقل من 20" -> max 20. The matched words are removed from
 * [rest] so the number does not take part in the dish search.
 */
export function parseBudget(text: string): { maxPrice: number | null; rest: string } {
  const unit = String.raw`(?:d|dt|dinars?|tnd|د|دينار)`;
  const before = String.raw`(?:moins\s+de|max(?:imum)?|jusqu'?\s*[aà]|a9al\s+(?:mn|men|min)|ta[h7]t|under|below|أقل\s+من|تحت)`;
  const num = String.raw`(\d+(?:[.,]\d+)?)`;
  const patterns = [
    new RegExp(String.raw`${before}\s*${num}\s*${unit}?(?=\s|$|[.,!?])`, "iu"),
    new RegExp(String.raw`${num}\s*${unit}(?=\s|$|[.,!?])`, "iu"),
  ];
  for (const re of patterns) {
    const m = text.match(re);
    if (m) {
      const value = Number(m[1].replace(",", "."));
      if (Number.isFinite(value) && value > 0) {
        return { maxPrice: value, rest: text.replace(m[0], " ").replace(/\s+/gu, " ").trim() };
      }
    }
  }
  return { maxPrice: null, rest: text };
}
