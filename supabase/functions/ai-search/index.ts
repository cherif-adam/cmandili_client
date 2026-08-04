// Supabase Edge Function: ai-search
//
// Two modes, driven by an LLM — OpenRouter primary, direct Gemini fallback on
// ANY OpenRouter failure (invalid key, no credits, outage). Same fallback
// pattern as `ai-chat`, ported here 2026-08-04 after OPENROUTER_API_KEY was
// found to be a dead truncated key (401 "User not found" on every call),
// which 502'd every ai-search request with no way to recover except a new
// OpenRouter key. Gemini covers that gap so the feature stays up regardless.
//
//   mode: "text"   — Conversational query in Darija / French / Arabic.
//                    The model extracts a structured intent (category, budget,
//                    spicy, vegetarian, keyword...) then we fetch candidate
//                    dishes from Postgres and ask the model to pick + rank the
//                    best matches for the user's request and budget.
//
//   mode: "image"  — A base64 photo of a dish. The vision model names the dish,
//                    we full-text match it against food_items, then the model
//                    re-ranks the candidates by visual/semantic fit.
//
// Secrets required (set with `supabase secrets set ...`):
//   OPENROUTER_API_KEY   sk-or-v1-...   primary provider
//   OPENROUTER_MODEL     e.g. google/gemini-2.0-flash-001  (optional, has default)
//   GEMINI_API_KEY       AIza...        fallback: direct Google Gemini API.
//                        Same model family as the OpenRouter default, so a
//                        fallback is invisible to the app. At least ONE of
//                        OPENROUTER_API_KEY / GEMINI_API_KEY must be set.
//   SUPABASE_URL         auto-provided by the platform
//   SUPABASE_SERVICE_ROLE_KEY  auto-provided by the platform
//
// Response shapes (consumed by lib/features/ai_search/data/models/search_result.dart):
//   text  -> { intent: {...}, results: [ {food_item + restaurants:{...}} ], fallback: bool }
//   image -> { dish_name, confidence, results: [ ... ] }
//   error -> { error: string, details?: string }   (always HTTP 200 or 4xx/5xx)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// .trim() defends against secrets pasted with stray whitespace/newlines.
const OPENROUTER_API_KEY = (Deno.env.get("OPENROUTER_API_KEY") ?? "").trim();
const OPENROUTER_MODEL =
  (Deno.env.get("OPENROUTER_MODEL") ?? "google/gemini-2.0-flash-001").trim();
const GEMINI_API_KEY = (Deno.env.get("GEMINI_API_KEY") ?? "").trim();
const GEMINI_MODEL = (Deno.env.get("GEMINI_SEARCH_MODEL") ?? "gemini-2.5-flash").trim();
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

// Columns we select from food_items + the joined restaurant. Kept in one place
// so the text and image paths stay in sync with the Flutter model.
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

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function errorResponse(message: string, details: string, status = 502): Response {
  return json({ error: message, details }, status);
}

// ── OpenRouter helpers ────────────────────────────────────────────────────────

/**
 * Calls OpenRouter chat completions and returns the assistant message content.
 * `messages` follows the OpenAI chat format; for vision, a message's content
 * can be an array with image_url parts.
 */
async function callOpenRouter(messages: unknown[]): Promise<string> {
  const res = await fetch(OPENROUTER_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${OPENROUTER_API_KEY}`,
      "Content-Type": "application/json",
      // OpenRouter asks for these for attribution; harmless if generic.
      "HTTP-Referer": "https://cmandili.com",
      "X-Title": "Cmandili AI Search",
    },
    body: JSON.stringify({
      model: OPENROUTER_MODEL,
      messages,
      temperature: 0.2,
      // Ask the model to return strict JSON. Most OpenRouter models honor this.
      response_format: { type: "json_object" },
    }),
  });

  const raw = await res.text();
  if (!res.ok) {
    throw new Error(`OpenRouter API error ${res.status}: ${raw}`);
  }

  let parsed: { choices?: { message?: { content?: string } }[] };
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new Error(`OpenRouter returned non-JSON envelope: ${raw.slice(0, 500)}`);
  }

  const content = parsed.choices?.[0]?.message?.content;
  if (!content) {
    throw new Error(`OpenRouter returned no content: ${raw.slice(0, 500)}`);
  }
  return content;
}

// ── Gemini helpers (fallback provider) ──────────────────────────────────────
// Speaks the native Generative Language API directly. Same JSON-object output
// contract as the OpenRouter path, so callers don't need to know which
// provider actually answered.

/**
 * Calls Gemini directly with a single system + user turn. `userParts`
 * mirrors `messages`' user content in Gemini's part shape: `{text}` for text,
 * `{inline_data: {mime_type, data}}` for images (raw base64, no data: prefix).
 */
async function callGemini(systemPrompt: string, userParts: unknown[]): Promise<string> {
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
    {
      method: "POST",
      headers: {
        "x-goog-api-key": GEMINI_API_KEY,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        system_instruction: { parts: [{ text: systemPrompt }] },
        contents: [{ role: "user", parts: userParts }],
        generationConfig: {
          temperature: 0.2,
          maxOutputTokens: 2048,
          responseMimeType: "application/json",
          // gemini-2.5-flash is a thinking model — spend the budget on the
          // JSON answer, not on reasoning tokens (same rationale as ai-chat).
          thinkingConfig: { thinkingBudget: 0 },
        },
      }),
    },
  );

  const raw = await res.text();
  if (!res.ok) {
    throw new Error(`Gemini API error ${res.status}: ${raw.slice(0, 500)}`);
  }

  let parsed: {
    candidates?: { content?: { parts?: { text?: string }[] }; finishReason?: string }[];
    promptFeedback?: { blockReason?: string };
  };
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new Error(`Gemini returned non-JSON envelope: ${raw.slice(0, 500)}`);
  }

  const text = (parsed.candidates?.[0]?.content?.parts ?? [])
    .map((p) => p.text ?? "")
    .join("");
  if (!text) {
    const why = parsed.promptFeedback?.blockReason ??
      parsed.candidates?.[0]?.finishReason ?? "unknown";
    throw new Error(`Gemini returned no content (${why}): ${raw.slice(0, 500)}`);
  }
  return text;
}

/**
 * Single entry point for every LLM call in this file: tries OpenRouter first,
 * falls back to direct Gemini on ANY OpenRouter failure (bad key, no credits,
 * outage) as long as GEMINI_API_KEY is set. Every call site in this file is a
 * single system+user turn (no conversation history), so callers only need to
 * supply the same turn in both providers' shapes.
 *
 * `openRouterUserContent` — OpenAI-style `content` (string, or an array with
 *   `image_url` parts for vision).
 * `geminiUserParts` — the same user turn in Gemini's part shape (`{text}` /
 *   `{inline_data}`).
 */
async function callLLM(
  systemPrompt: string,
  openRouterUserContent: unknown,
  geminiUserParts: unknown[],
): Promise<string> {
  if (!OPENROUTER_API_KEY) {
    if (!GEMINI_API_KEY) {
      throw new Error("Neither OPENROUTER_API_KEY nor GEMINI_API_KEY is set.");
    }
    console.warn("[ai-search] no OPENROUTER_API_KEY — using direct Gemini");
    return await callGemini(systemPrompt, geminiUserParts);
  }
  try {
    return await callOpenRouter([
      { role: "system", content: systemPrompt },
      { role: "user", content: openRouterUserContent },
    ]);
  } catch (e) {
    if (!GEMINI_API_KEY) throw e;
    console.warn(
      `[ai-search] OpenRouter failed, falling back to direct Gemini: ${String(e).slice(0, 200)}`,
    );
    return await callGemini(systemPrompt, geminiUserParts);
  }
}

/**
 * Extracts a JSON object/array from a model response. Models sometimes wrap
 * JSON in ```json fences or add prose despite response_format — strip both.
 */
function extractJson<T>(text: string): T {
  let s = text.trim();
  // Strip code fences if present.
  const fence = s.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fence) s = fence[1].trim();
  // Otherwise grab the first {...} or [...] block.
  if (!s.startsWith("{") && !s.startsWith("[")) {
    const obj = s.match(/[{[][\s\S]*[}\]]/);
    if (obj) s = obj[0];
  }
  return JSON.parse(s) as T;
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
  "keyword": string | null        // a specific dish name they mentioned, e.g. "lablabi","makloub","chapati"; null otherwise
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

// Progressive relaxation ladder. Each tier is tried in order and the first one
// that returns rows wins, so an over-constrained query degrades into something
// useful instead of dead-ending on an empty list.
//
//   1. everything the user asked for
//   2. drop is_spicy / is_vegetarian — these columns are sparsely populated, so
//      they are the most likely reason a reasonable query returns nothing
//   3. drop category / keyword, keep the budget — respect what they can spend
//   4. no filters at all — guarantees we never hand back zero results
//
// Any tier past the first means we did NOT match what was asked for, so the
// response is flagged and the client says so rather than passing these off as
// genuine matches.
interface RelaxTier {
  attributes: boolean; // is_spicy / is_vegetarian
  taxonomy: boolean; // category / keyword
  price: boolean; // min_price / max_price
}

const RELAX_TIERS: RelaxTier[] = [
  { attributes: true, taxonomy: true, price: true },
  { attributes: false, taxonomy: true, price: true },
  { attributes: false, taxonomy: false, price: true },
  { attributes: false, taxonomy: false, price: false },
];

function buildCandidateQuery(
  supabase: ReturnType<typeof createClient>,
  intent: TextIntent,
  tier: RelaxTier,
) {
  let q = supabase.from("food_items").select(FOOD_SELECT).eq("is_available", true);

  if (tier.taxonomy && intent.category) {
    q = q.ilike("category", `%${intent.category}%`);
  }
  if (tier.attributes && intent.spicy === true) q = q.eq("is_spicy", true);
  if (tier.attributes && intent.vegetarian === true) q = q.eq("is_vegetarian", true);
  if (tier.price && intent.max_price != null) q = q.lte("price", intent.max_price);
  if (tier.price && intent.min_price != null) q = q.gte("price", intent.min_price);
  if (tier.taxonomy && intent.keyword) {
    q = q.or(`name.ilike.%${intent.keyword}%,description.ilike.%${intent.keyword}%`);
  }

  // The widest tier has no user signal to sort by, so lead with the cheapest
  // dishes. We deliberately do NOT filter on restaurants.is_open here — that
  // could re-introduce the empty result this tier exists to prevent.
  if (!tier.attributes && !tier.taxonomy && !tier.price) {
    q = q.order("price", { ascending: true });
  }

  return q.limit(60);
}

async function handleTextSearch(query: string, supabase: ReturnType<typeof createClient>) {
  if (!query || query.trim().length === 0) {
    return json({ error: "Empty query." }, 400);
  }

  // 1. Parse intent.
  let intent: TextIntent;
  try {
    const content = await callLLM(INTENT_SYSTEM_PROMPT, query, [{ text: query }]);
    const parsed = extractJson<Partial<TextIntent>>(content);
    intent = {
      category: parsed.category ?? null,
      spicy: parsed.spicy ?? null,
      vegetarian: parsed.vegetarian ?? null,
      max_price: typeof parsed.max_price === "number" ? parsed.max_price : null,
      min_price: typeof parsed.min_price === "number" ? parsed.min_price : null,
      delivery_time: parsed.delivery_time === "fast" ? "fast" : null,
      keyword: parsed.keyword ?? null,
    };
  } catch (e) {
    return errorResponse("Failed to parse AI response.", String(e));
  }

  // 2. Walk the relaxation ladder until a tier returns rows. The model does the
  //    fine ranking afterwards, so each tier stays deliberately broad.
  let candidates: Record<string, unknown>[] | null = null;
  let tierUsed = 0;

  for (let i = 0; i < RELAX_TIERS.length; i++) {
    const { data, error } = await buildCandidateQuery(supabase, intent, RELAX_TIERS[i]);
    if (error) {
      return errorResponse("Database query failed.", error.message, 500);
    }
    if (data && data.length > 0) {
      candidates = data as Record<string, unknown>[];
      tierUsed = i;
      break;
    }
  }

  // Only reachable if the catalogue itself is empty.
  if (!candidates || candidates.length === 0) {
    return json({ intent, results: [], fallback: false });
  }

  // Past the first tier we dropped something the user asked for, so the client
  // must present these as suggestions rather than matches.
  const fallback = tierUsed > 0;

  // 3. Ask the model to pick + rank the best matches.
  let results = candidates;
  try {
    const slim = candidates.map((c: Record<string, unknown>) => ({
      id: c.id,
      name: c.name,
      description: c.description,
      price: c.price,
      category: c.category,
      is_spicy: c.is_spicy,
      is_vegetarian: c.is_vegetarian,
    }));
    const rankUserContent = `User request: "${query}"\nBudget max_price: ${
      intent.max_price ?? "none"
    }\nCandidates:\n${JSON.stringify(slim)}`;
    const content = await callLLM(RANK_SYSTEM_PROMPT, rankUserContent, [
      { text: rankUserContent },
    ]);
    const ranked = extractJson<{ ids?: string[] }>(content);
    if (Array.isArray(ranked.ids) && ranked.ids.length > 0) {
      const byId = new Map(candidates.map((c: Record<string, unknown>) => [c.id, c]));
      const ordered = ranked.ids
        .map((id) => byId.get(id))
        .filter((c): c is Record<string, unknown> => c != null);
      // Append any candidate the model dropped, so we never lose results.
      const seen = new Set(ranked.ids);
      for (const c of candidates) {
        if (!seen.has((c as Record<string, unknown>).id as string)) ordered.push(c);
      }
      if (ordered.length > 0) results = ordered;
    }
  } catch (_) {
    // Ranking is best-effort — if the model fails, fall back to DB order
    // sorted cheapest-first so the list is still useful.
    results = [...candidates].sort(
      (a: Record<string, unknown>, b: Record<string, unknown>) =>
        ((a.price as number) ?? 0) - ((b.price as number) ?? 0),
    );
  }

  return json({ intent, results, fallback });
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

async function handleImageSearch(
  imageBase64: string,
  mimeType: string,
  supabase: ReturnType<typeof createClient>,
) {
  if (!imageBase64 || imageBase64.length === 0) {
    return json({ error: "Empty image." }, 400);
  }

  // 1. Vision: identify the dish.
  let dishName: string | null;
  let keywords: string[];
  let confidence: string;
  try {
    const prompt = "What dish is in this photo?";
    const content = await callLLM(
      VISION_SYSTEM_PROMPT,
      [
        { type: "text", text: prompt },
        { type: "image_url", image_url: { url: `data:${mimeType};base64,${imageBase64}` } },
      ],
      [
        { text: prompt },
        { inline_data: { mime_type: mimeType, data: imageBase64 } },
      ],
    );
    const parsed = extractJson<{
      dish_name?: string | null;
      keywords?: string[];
      confidence?: string;
    }>(content);
    dishName = parsed.dish_name ?? null;
    keywords = Array.isArray(parsed.keywords) ? parsed.keywords : [];
    confidence = ["high", "medium", "low"].includes(parsed.confidence ?? "")
      ? (parsed.confidence as string)
      : "low";
  } catch (e) {
    return errorResponse("Failed to parse AI response.", String(e));
  }

  if (!dishName) {
    return json({ error: "No food dish detected." }, 422);
  }

  // 2. Match against the menu. Try the dish name and each keyword.
  const terms = [dishName, ...keywords].filter(Boolean);
  const orFilter = terms
    .flatMap((t) => [`name.ilike.%${t}%`, `description.ilike.%${t}%`])
    .join(",");

  const { data: candidates, error } = await supabase
    .from("food_items")
    .select(FOOD_SELECT)
    .eq("is_available", true)
    .or(orFilter)
    .limit(60);

  if (error) {
    return errorResponse("Database query failed.", error.message, 500);
  }
  if (!candidates || candidates.length === 0) {
    return json({ dish_name: dishName, confidence, results: [] });
  }

  // 3. Re-rank candidates by fit to the identified dish.
  let results = candidates;
  try {
    const slim = candidates.map((c: Record<string, unknown>) => ({
      id: c.id,
      name: c.name,
      description: c.description,
      price: c.price,
      category: c.category,
    }));
    const rankUserContent = `User uploaded a photo of: "${dishName}" (keywords: ${
      keywords.join(", ")
    }). Pick the menu dishes that best match this dish.\nCandidates:\n${
      JSON.stringify(slim)
    }`;
    const content = await callLLM(RANK_SYSTEM_PROMPT, rankUserContent, [
      { text: rankUserContent },
    ]);
    const ranked = extractJson<{ ids?: string[] }>(content);
    if (Array.isArray(ranked.ids) && ranked.ids.length > 0) {
      const byId = new Map(candidates.map((c: Record<string, unknown>) => [c.id, c]));
      const ordered = ranked.ids
        .map((id) => byId.get(id))
        .filter((c): c is Record<string, unknown> => c != null);
      const seen = new Set(ranked.ids);
      for (const c of candidates) {
        if (!seen.has((c as Record<string, unknown>).id as string)) ordered.push(c);
      }
      if (ordered.length > 0) results = ordered;
    }
  } catch (_) {
    // best-effort ranking — keep DB order on failure
  }

  return json({ dish_name: dishName, confidence, results });
}

// ── Entry point ───────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  // Fail fast on misconfiguration so the app shows a clear message.
  if (!OPENROUTER_API_KEY && !GEMINI_API_KEY) {
    return errorResponse(
      "Server misconfiguration.",
      "Neither OPENROUTER_API_KEY nor GEMINI_API_KEY secret is set on the Edge Function.",
      500,
    );
  }
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    return errorResponse(
      "Server misconfiguration.",
      "SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are not available.",
      500,
    );
  }

  let body: { mode?: string; query?: string; imageBase64?: string; mimeType?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body." }, 400);
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  try {
    if (body.mode === "text") {
      return await handleTextSearch(body.query ?? "", supabase);
    }
    if (body.mode === "image") {
      return await handleImageSearch(
        body.imageBase64 ?? "",
        body.mimeType ?? "image/jpeg",
        supabase,
      );
    }
    return json({ error: "Unknown mode. Use 'text' or 'image'." }, 400);
  } catch (e) {
    return errorResponse("Unexpected server error.", String(e), 500);
  }
});
