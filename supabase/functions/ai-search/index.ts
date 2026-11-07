// Supabase Edge Function: ai-search
//
// Two modes, driven by an LLM — OpenRouter first, direct Gemini second
// (../_shared/llm.ts: any failure of one provider, including a 429, a timeout
// or an unparseable answer, moves on to the other).
//
//   mode: "text"   — Conversational query in Darija / French / Arabic.
//                    The model extracts a structured intent (category, budget,
//                    spicy, vegetarian, keyword...) then we fetch candidate
//                    dishes from Postgres and ask the model to pick + rank the
//                    best matches for the user's request and budget.
//
//   mode: "image"  — A base64 photo of a dish. The vision model names the dish,
//                    we match it against the menu, then the model re-ranks the
//                    candidates by visual/semantic fit.
//
// Dishes the user NAMED are found with public.search_dishes (migration
// 20261106120000): fuzzy, word by word, accents and case ignored, one search
// per dish ("calzone et malfouf" is two). See ../_shared/dish_search.ts.
//
// WITHOUT A MODEL (both providers failing — on 2026-11-06 OpenRouter answered
// 402 and Gemini's free tier 429 after 20 requests a day): the text search
// falls back to a plain database search on the user's own words, ignoring the
// words that match no dish ("n7eb", "bghit"), with a budget read from the
// text ("20d", "moins de 15"). status "degraded". A photo cannot be searched
// without the vision model: status "degraded" with no results.
//
// Responses are ALWAYS HTTP 200 with a status, except a broken request (4xx)
// or a database failure (5xx):
//   text  -> { intent: {...}, results: [...], fallback: bool, status }
//   image -> { dish_name, confidence, results: [...], status, reason? }
//   status: "ok"        results understood by the model
//           "no_match"  the named dish is not on any menu (results: [])
//           "degraded"  results from the search without a model (maybe [])
//   error -> { error: <French sentence an older app may print as is>,
//              code, status: "error" }
// Provider and database error details are logged here, never returned: the
// app used to print Gemini's whole 429 JSON on the Recherche IA screen.
//
// Secrets (set with `supabase secrets set ...`):
//   OPENROUTER_API_KEY   sk-or-v1-...   first provider (optional)
//   OPENROUTER_MODEL     e.g. google/gemini-2.5-flash  (optional, has default)
//   GEMINI_API_KEY       AIza...        second provider (optional)
//   GEMINI_SEARCH_MODEL  (optional, default gemini-2.5-flash)
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY  auto-provided by the platform
// With no provider key at all, every text search runs in degraded mode.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { CANDIDATE_LIMIT, openShopsFirst, taxonomyFilter } from "./search_filters.ts";
import { callLlmJson, extractJsonObject, type LlmCall, LlmUnavailableError } from "../_shared/llm.ts";
import { simulatedLlmStatus } from "../_shared/simulate.ts";
import {
  type DishRow,
  DishSearchError,
  findDishes,
  parseBudget,
  postgrestRpc,
  type RpcClient,
  searchDish,
  toFoodItemRow,
  uniqueRows,
} from "../_shared/dish_search.ts";

// The client type, derived from an actual CALL rather than from
// `ReturnType<typeof createClient>`.
//
// Those two are not the same thing. Without explicit type arguments the
// generics fall back to their declared defaults, which in this version of
// supabase-js include `never` for the schema parameters — so
// `ReturnType<typeof createClient>` is a client over a schema with no tables,
// every query's `data` infers as `never[]`, and passing the real client into a
// function annotated that way is a type error. `deno check` reported exactly
// that three times. Inferring from `createClient(url, key)` gives whatever the
// installed version really returns, and keeps doing so after an upgrade.
type Db = ReturnType<typeof makeClient>;
const makeClient = (url: string, key: string) => createClient(url, key);

// .trim() defends against secrets pasted with stray whitespace/newlines.
const OPENROUTER_API_KEY = (Deno.env.get("OPENROUTER_API_KEY") ?? "").trim();
const OPENROUTER_MODEL = (Deno.env.get("OPENROUTER_MODEL") ?? "google/gemini-2.5-flash").trim();
// OpenRouter ONLY (decision 2026-11-07): the direct Gemini fallback is
// switched off, so every model call goes through OPENROUTER_API_KEY
// (google/gemini-2.5-flash). An empty key makes _shared/llm.ts skip Gemini.
// To bring the fallback back: (Deno.env.get("GEMINI_API_KEY") ?? "").trim().
const GEMINI_API_KEY = "";
const GEMINI_MODEL = (Deno.env.get("GEMINI_SEARCH_MODEL") ?? "gemini-2.5-flash").trim();
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// Per provider. Text calls are short JSON answers; a photo takes longer.
const TEXT_TIMEOUT_MS = 15_000;
const VISION_TIMEOUT_MS = 25_000;

// Columns we select from food_items + the joined restaurant. Kept in one place
// so the text and image paths stay in sync with the Flutter model, and with
// toFoodItemRow in ../_shared/dish_search.ts.
const FOOD_SELECT = `
  id, name, description, price, discount_price, image_url, category,
  is_spicy, is_vegetarian, preparation_time, restaurant_id,
  restaurants!inner (
    id, name, image_url, rating, delivery_time_min, delivery_fee, is_open
  )
`;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// The shop a result belongs to, and whether it is open, for openShopsFirst.
const shopOf = (row: Record<string, unknown>) => row.restaurant_id;
const isOpenShop = (row: Record<string, unknown>) =>
  (row.restaurants as { is_open?: boolean } | null)?.is_open === true;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

// What an older app build prints as is (it shows the `error` field), so it is
// worded for the customer. The current app shows its own sentences.
const UNAVAILABLE_SENTENCE =
  "La recherche intelligente est momentanément indisponible. Réessayez dans quelques instants.";

function errorResponse(code: string, status: number): Response {
  return json({ error: UNAVAILABLE_SENTENCE, code, status: "error" }, status);
}

/** The database failed: the only case that answers 5xx. */
class DatabaseError extends Error {}

// ── LLM calls ─────────────────────────────────────────────────────────────────

/**
 * One system + user turn, in both providers' shapes. `openRouterUserContent`
 * is OpenAI-style content (string, or parts with `image_url` for vision);
 * `geminiUserParts` the same turn as Gemini parts (`{text}` / `{inline_data}`).
 */
function llmCall(
  label: string,
  systemPrompt: string,
  openRouterUserContent: unknown,
  geminiUserParts: unknown[],
  simulate: number | null,
  timeoutMs = TEXT_TIMEOUT_MS,
): LlmCall {
  return {
    label: `ai-search:${label}`,
    timeoutMs,
    simulateStatus: simulate,
    openRouter: {
      apiKey: OPENROUTER_API_KEY,
      model: OPENROUTER_MODEL,
      title: "Cmandili AI Search",
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: openRouterUserContent },
      ],
      temperature: 0.2,
      maxTokens: 2048,
    },
    gemini: {
      apiKey: GEMINI_API_KEY,
      model: GEMINI_MODEL,
      systemPrompt,
      contents: [{ role: "user", parts: geminiUserParts }],
      temperature: 0.2,
      maxOutputTokens: 2048,
    },
  };
}

/** Accepts `{ ids: [...] }` only: anything else is a failed answer. */
function parseRanking(text: string): string[] {
  const parsed = extractJsonObject(text);
  if (!Array.isArray(parsed.ids)) throw new Error("ranking answer has no ids array");
  return parsed.ids.filter((id): id is string => typeof id === "string");
}

/**
 * Asks the model to order [candidates] for [request]. Best effort: when no
 * model answers, the database order stands (closest match first). Any
 * candidate the model leaves out is appended, so none is ever lost.
 */
async function rankCandidates(
  candidates: Record<string, unknown>[],
  request: string,
  label: string,
  simulate: number | null,
): Promise<Record<string, unknown>[]> {
  try {
    const { value: ids } = await callLlmJson(
      llmCall(label, RANK_SYSTEM_PROMPT, request, [{ text: request }], simulate),
      parseRanking,
    );
    if (ids.length === 0) return candidates;
    const byId = new Map(candidates.map((c) => [c.id, c]));
    const ordered = ids.map((id) => byId.get(id)).filter((c): c is Record<string, unknown> => c != null);
    const seen = new Set(ids);
    for (const c of candidates) {
      if (!seen.has(c.id as string)) ordered.push(c);
    }
    return ordered.length > 0 ? ordered : candidates;
  } catch (e) {
    if (!(e instanceof LlmUnavailableError)) throw e;
    console.warn(`[ai-search] ranking skipped: ${e.message}`);
    return candidates;
  }
}

// ── Mode: text ────────────────────────────────────────────────────────────────

interface TextIntent {
  category: string | null;
  spicy: boolean | null;
  vegetarian: boolean | null;
  max_price: number | null;
  min_price: number | null;
  delivery_time: string | null; // "fast" | null
  keyword: string | null;
}

const NO_INTENT: TextIntent = {
  category: null,
  spicy: null,
  vegetarian: null,
  max_price: null,
  min_price: null,
  delivery_time: null,
  keyword: null,
};

const INTENT_SYSTEM_PROMPT = `You are the intent parser for a Tunisian food delivery app (city: Kairouan).
Users write in Tunisian Darija, French, Arabic, or a mix. They describe what
they want to eat and often a budget in dinars (written "d", "dt", "dinar",
"tnd"). Examples: "n7eb pizza", "3andi 20d w n7eb 7aja 7arra", "quelque chose
de rapide pas cher", "nekel hakka, sandwich".

Return ONLY a JSON object with EXACTLY these keys:
{
  "category": string | null,      // best guess: "pizza","burger","sandwich","pasta","grill","salad","dessert","drink","tacos","crepe","seafood", or null if unclear
  "spicy": boolean | null,        // true if they want spicy ("7arr","7arra","épicé","حار"); null if not mentioned
  "vegetarian": boolean | null,   // true if they want vegetarian; null if not mentioned
  "max_price": number | null,     // budget upper bound in TND, e.g. "20d" -> 20; null if no budget
  "min_price": number | null,     // usually null
  "delivery_time": "fast" | null, // "fast" if they want it quick ("fissa3","rapide","vite","سريع")
  "keyword": string | null        // the dish(es) they named, e.g. "lablabi","makloub","chapati"; several dishes separated by commas ("malfouf thon, calzone"); null otherwise
}
Do not add comments or any text outside the JSON object.`;

const RANK_SYSTEM_PROMPT = `You help a Tunisian food delivery user pick dishes.
You receive the user's original request and a JSON list of candidate dishes
(each with id, name, description, price, category, is_spicy, is_vegetarian).
Pick the dishes that BEST satisfy the user's request and budget, ordered from
best match to worst. Respect their budget (max_price) when given — never put an
over-budget dish first. Prefer the requested category/keyword. If nothing fits
well, return the closest few anyway.

Return ONLY a JSON object: { "ids": [ "id1", "id2", ... ] }
List at most 20 ids, best first. Do not add text outside the JSON.`;

function parseIntent(text: string): TextIntent {
  const parsed = extractJsonObject(text);
  const str = (v: unknown) => (typeof v === "string" && v.trim() ? v.trim() : null);
  return {
    category: str(parsed.category),
    spicy: typeof parsed.spicy === "boolean" ? parsed.spicy : null,
    vegetarian: typeof parsed.vegetarian === "boolean" ? parsed.vegetarian : null,
    max_price: typeof parsed.max_price === "number" ? parsed.max_price : null,
    min_price: typeof parsed.min_price === "number" ? parsed.min_price : null,
    delivery_time: parsed.delivery_time === "fast" ? "fast" : null,
    keyword: str(parsed.keyword),
  };
}

// Progressive relaxation ladder. Each tier is tried in order and the first one
// that returns rows wins, so an over-constrained query degrades into something
// useful instead of dead-ending on an empty list.
//
//   1. everything the user asked for
//   2. drop is_spicy / is_vegetarian — these columns are sparsely populated, so
//      they are the most likely reason a reasonable query returns nothing
//   3. drop the CATEGORY the model guessed, keep the budget
//
// A dish the user NAMED is never dropped (since 2026-11-06): when "calzone"
// is on no menu the answer is status "no_match", not the cheapest dishes of
// the city presented as suggestions. Tier 3 therefore only exists for a
// request with a guessed category and no named dish.
//
// THE BUDGET IS NOT A TIER. A budget is the user's own constraint, not a
// search hint, and an empty answer is the correct answer to "nothing under
// 10 TND". The chat assistant's ladders carry the same rule.
//
// Any tier past the first means we did NOT match what was asked for, so the
// response is flagged and the client says so rather than passing these off as
// genuine matches.
interface RelaxTier {
  attributes: boolean; // is_spicy / is_vegetarian
  taxonomy: boolean; // category (or the named dish)
}

const RELAX_TIERS: RelaxTier[] = [
  { attributes: true, taxonomy: true },
  { attributes: false, taxonomy: true },
  { attributes: false, taxonomy: false },
];

function withinBudget(intent: TextIntent, price: number): boolean {
  if (intent.max_price != null && price > intent.max_price) return false;
  if (intent.min_price != null && price < intent.min_price) return false;
  return true;
}

function hasAttributes(intent: TextIntent, row: DishRow): boolean {
  if (intent.spicy === true && row.is_spicy !== true) return false;
  if (intent.vegetarian === true && row.is_vegetarian !== true) return false;
  return true;
}

/** Category-only (or no taxonomy) tier, as a database query. */
function buildCandidateQuery(supabase: Db, intent: TextIntent, tier: RelaxTier) {
  // Closed shops are kept and come after the open ones (openShopsFirst); the
  // app shows them dimmed, like the home screen. Hidden shops (deleted_at)
  // never get this far: the food_items and restaurants views leave them out.
  let q = supabase.from("food_items").select(FOOD_SELECT).eq("is_available", true);

  if (tier.taxonomy) {
    const taxonomy = taxonomyFilter({ category: intent.category, keyword: null });
    if (taxonomy?.kind === "category") q = q.ilike("category", taxonomy.pattern);
  }
  if (tier.attributes && intent.spicy === true) q = q.eq("is_spicy", true);
  if (tier.attributes && intent.vegetarian === true) q = q.eq("is_vegetarian", true);
  // Unconditional, at every tier: see RELAX_TIERS above.
  if (intent.max_price != null) q = q.lte("price", intent.max_price);
  if (intent.min_price != null) q = q.gte("price", intent.min_price);

  // Cheapest first at every tier: a fixed order, so a query that ever matches
  // more than CANDIDATE_LIMIT dishes is cut by price, not by whichever shop's
  // rows Postgres happens to read first.
  return q.order("price", { ascending: true }).limit(CANDIDATE_LIMIT);
}

/** Candidates for a request that named a dish: tiers 1-2 only, in memory. */
async function namedDishCandidates(
  rpc: RpcClient,
  intent: TextIntent,
): Promise<{ rows: Record<string, unknown>[]; tier: number }> {
  const outcomes = await findDishes(rpc, intent.keyword, intent.category, {
    openOnly: false,
    matchDescription: true,
    limit: CANDIDATE_LIMIT,
  });
  const all = uniqueRows(outcomes);
  for (let i = 0; i < 2; i++) {
    const rows = all.filter((r) =>
      withinBudget(intent, Number(r.price)) && (!RELAX_TIERS[i].attributes || hasAttributes(intent, r))
    );
    if (rows.length > 0) return { rows: rows.map(toFoodItemRow), tier: i };
  }
  return { rows: [], tier: 0 };
}

/** Candidates for a request without a named dish: the database ladder. */
async function ladderCandidates(
  supabase: Db,
  intent: TextIntent,
): Promise<{ rows: Record<string, unknown>[]; tier: number }> {
  for (let i = 0; i < RELAX_TIERS.length; i++) {
    const { data, error } = await buildCandidateQuery(supabase, intent, RELAX_TIERS[i]);
    if (error) throw new DatabaseError(error.message);
    if (data && data.length > 0) return { rows: data as Record<string, unknown>[], tier: i };
  }
  return { rows: [], tier: 0 };
}

/** No model: the user's own words, unknown words ignored. */
async function degradedTextSearch(query: string, rpc: RpcClient): Promise<Response> {
  const { maxPrice, rest } = parseBudget(query);
  const outcomes = await findDishes(rpc, rest, null, {
    openOnly: false,
    ignoreUnknownWords: true,
    maxPrice,
    limit: CANDIDATE_LIMIT,
  });
  const rows = uniqueRows(outcomes).map(toFoodItemRow);
  return json({
    intent: { ...NO_INTENT, max_price: maxPrice },
    results: openShopsFirst(rows, shopOf, isOpenShop),
    fallback: false,
    status: "degraded",
  });
}

async function handleTextSearch(
  query: string,
  supabase: Db,
  rpc: RpcClient,
  simulate: number | null,
): Promise<Response> {
  if (!query || query.trim().length === 0) {
    return json({ error: "Requête vide.", code: "empty_query", status: "error" }, 400);
  }

  // 1. Parse intent. No model -> plain database search.
  let intent: TextIntent;
  try {
    ({ value: intent } = await callLlmJson(
      llmCall("intent", INTENT_SYSTEM_PROMPT, query, [{ text: query }], simulate),
      parseIntent,
    ));
  } catch (e) {
    if (!(e instanceof LlmUnavailableError)) throw e;
    console.error(`[ai-search] no model for the intent, degraded search: ${e.message}`);
    return await degradedTextSearch(query, rpc);
  }

  // 2. Candidates: the named dish(es), else the category ladder.
  const { rows: candidates, tier } = intent.keyword
    ? await namedDishCandidates(rpc, intent)
    : await ladderCandidates(supabase, intent);

  if (candidates.length === 0) {
    return json({ intent, results: [], fallback: false, status: "no_match" });
  }

  // 3. Ask the model to pick + rank the best matches (best effort).
  const slim = candidates.map((c) => ({
    id: c.id,
    name: c.name,
    description: c.description,
    price: c.price,
    category: c.category,
    is_spicy: c.is_spicy,
    is_vegetarian: c.is_vegetarian,
  }));
  const request = `User request: "${query}"\nBudget max_price: ${intent.max_price ?? "none"}\nCandidates:\n${
    JSON.stringify(slim)
  }`;
  const results = await rankCandidates(candidates, request, "rank", simulate);

  // Past the first tier we dropped something the user asked for, so the client
  // must present these as suggestions rather than matches.
  return json({
    intent,
    results: openShopsFirst(results, shopOf, isOpenShop),
    fallback: tier > 0,
    status: "ok",
  });
}

// ── Mode: image ───────────────────────────────────────────────────────────────

const VISION_SYSTEM_PROMPT = `You are a food recognition assistant for a Tunisian
food delivery app. You receive a photo. Identify the single main food dish in it.
Return ONLY a JSON object:
{
  "dish_name": string,            // common name, prefer English or French, e.g. "pizza margherita","burger","lablabi"
  "keywords": string[],           // 2-5 search keywords for matching a menu, lowercase
  "confidence": "high" | "medium" | "low"
}
If there is no recognizable food dish, return {"dish_name": null, "keywords": [], "confidence": "low"}.
Do not add text outside the JSON object.`;

interface VisionAnswer {
  dishName: string | null;
  keywords: string[];
  confidence: string;
}

function parseVision(text: string): VisionAnswer {
  const parsed = extractJsonObject(text);
  const dishName = typeof parsed.dish_name === "string" && parsed.dish_name.trim()
    ? parsed.dish_name.trim()
    : null;
  const keywords = Array.isArray(parsed.keywords)
    ? parsed.keywords.filter((k): k is string => typeof k === "string" && k.trim().length > 0)
    : [];
  const confidence = ["high", "medium", "low"].includes(parsed.confidence as string)
    ? (parsed.confidence as string)
    : "low";
  return { dishName, keywords, confidence };
}

async function handleImageSearch(
  imageBase64: string,
  mimeType: string,
  rpc: RpcClient,
  simulate: number | null,
): Promise<Response> {
  if (!imageBase64 || imageBase64.length === 0) {
    return json({ error: "Image vide.", code: "empty_image", status: "error" }, 400);
  }

  // 1. Vision: identify the dish. Without a model a photo cannot be searched.
  let vision: VisionAnswer;
  try {
    const prompt = "What dish is in this photo?";
    ({ value: vision } = await callLlmJson(
      llmCall(
        "vision",
        VISION_SYSTEM_PROMPT,
        [
          { type: "text", text: prompt },
          { type: "image_url", image_url: { url: `data:${mimeType};base64,${imageBase64}` } },
        ],
        [{ text: prompt }, { inline_data: { mime_type: mimeType, data: imageBase64 } }],
        simulate,
        VISION_TIMEOUT_MS,
      ),
      parseVision,
    ));
  } catch (e) {
    if (!(e instanceof LlmUnavailableError)) throw e;
    console.error(`[ai-search] no model for the photo: ${e.message}`);
    return json({ dish_name: null, confidence: "low", results: [], status: "degraded" });
  }

  const { dishName, keywords, confidence } = vision;
  if (!dishName) {
    return json({ dish_name: null, confidence, results: [], status: "no_match", reason: "no_dish" });
  }

  // 2. Match against the menu: the dish name, then each keyword, each one a
  //    fuzzy search of its own. Closed shops kept, like the text search.
  const seen = new Set<string>();
  const rows: DishRow[] = [];
  for (const term of [dishName, ...keywords].slice(0, 6)) {
    for (const r of await searchDish(rpc, term, { openOnly: false, matchDescription: true, limit: 60 })) {
      if (seen.has(r.id) || rows.length >= CANDIDATE_LIMIT) continue;
      seen.add(r.id);
      rows.push(r);
    }
  }
  if (rows.length === 0) {
    return json({ dish_name: dishName, confidence, results: [], status: "no_match" });
  }

  // 3. Re-rank candidates by fit to the identified dish (best effort).
  const candidates = rows.map(toFoodItemRow);
  const slim = candidates.map((c) => ({
    id: c.id,
    name: c.name,
    description: c.description,
    price: c.price,
    category: c.category,
  }));
  const request = `User uploaded a photo of: "${dishName}" (keywords: ${
    keywords.join(", ")
  }). Pick the menu dishes that best match this dish.\nCandidates:\n${JSON.stringify(slim)}`;
  const results = await rankCandidates(candidates, request, "rank-image", simulate);

  return json({
    dish_name: dishName,
    confidence,
    results: openShopsFirst(results, shopOf, isOpenShop),
    status: "ok",
  });
}

// ── Entry point ───────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return json({ error: "Méthode non autorisée.", code: "method_not_allowed", status: "error" }, 405);
  }
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    console.error("[ai-search] SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are not available");
    return errorResponse("database_unavailable", 500);
  }
  if (!OPENROUTER_API_KEY && !GEMINI_API_KEY) {
    console.error("[ai-search] neither OPENROUTER_API_KEY nor GEMINI_API_KEY is set: degraded mode only");
  }

  let body: { mode?: string; query?: string; imageBase64?: string; mimeType?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Requête invalide.", code: "invalid_json", status: "error" }, 400);
  }

  const supabase = makeClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const rpc = postgrestRpc(SUPABASE_URL, SERVICE_ROLE_KEY);
  // Test hook, off by default: ../_shared/simulate.ts.
  const simulate = simulatedLlmStatus(req);

  try {
    if (body.mode === "text") {
      return await handleTextSearch(body.query ?? "", supabase, rpc, simulate);
    }
    if (body.mode === "image") {
      return await handleImageSearch(body.imageBase64 ?? "", body.mimeType ?? "image/jpeg", rpc, simulate);
    }
    return json({ error: "Requête invalide.", code: "unknown_mode", status: "error" }, 400);
  } catch (e) {
    // The real cause stays in the logs (dashboard Logs tab), never in the reply.
    if (e instanceof DishSearchError || e instanceof DatabaseError) {
      console.error("[ai-search] database failed:", e);
      return errorResponse("database_unavailable", 503);
    }
    console.error("[ai-search] unexpected error:", e);
    return errorResponse("unexpected", 500);
  }
});
