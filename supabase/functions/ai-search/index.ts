// Supabase Edge Function: ai-search
//
// Two modes, both driven by an LLM through OpenRouter (so we are not tied to
// the Gemini "v1" endpoint that started returning 404 for gemini-1.5-flash):
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
//   OPENROUTER_API_KEY   sk-or-v1-...   the OpenRouter key
//   OPENROUTER_MODEL     e.g. google/gemini-2.0-flash-001  (optional, has default)
//   SUPABASE_URL         auto-provided by the platform
//   SUPABASE_SERVICE_ROLE_KEY  auto-provided by the platform
//
// Response shapes (consumed by lib/features/ai_search/data/models/search_result.dart):
//   text  -> { intent: {...}, results: [ {food_item + restaurants:{...}} ] }
//   image -> { dish_name, confidence, results: [ ... ] }
//   error -> { error: string, details?: string }   (always HTTP 200 or 4xx/5xx)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const OPENROUTER_API_KEY = Deno.env.get("OPENROUTER_API_KEY") ?? "";
const OPENROUTER_MODEL =
  Deno.env.get("OPENROUTER_MODEL") ?? "google/gemini-2.0-flash-001";
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

async function handleTextSearch(query: string, supabase: ReturnType<typeof createClient>) {
  if (!query || query.trim().length === 0) {
    return json({ error: "Empty query." }, 400);
  }

  // 1. Parse intent.
  let intent: TextIntent;
  try {
    const content = await callOpenRouter([
      { role: "system", content: INTENT_SYSTEM_PROMPT },
      { role: "user", content: query },
    ]);
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

  // 2. Build a candidate query from the structured intent. We keep this broad
  //    (the model does the fine ranking) but apply the hard filters.
  let q = supabase.from("food_items").select(FOOD_SELECT).eq("is_available", true);

  if (intent.category) q = q.ilike("category", `%${intent.category}%`);
  if (intent.spicy === true) q = q.eq("is_spicy", true);
  if (intent.vegetarian === true) q = q.eq("is_vegetarian", true);
  if (intent.max_price != null) q = q.lte("price", intent.max_price);
  if (intent.min_price != null) q = q.gte("price", intent.min_price);
  if (intent.keyword) {
    q = q.or(`name.ilike.%${intent.keyword}%,description.ilike.%${intent.keyword}%`);
  }

  let { data: candidates, error } = await q.limit(60);

  // Fallback: if strict filters returned nothing, retry with just category or
  // keyword so the user still sees something relevant.
  if (!error && (!candidates || candidates.length === 0)) {
    let relaxed = supabase
      .from("food_items")
      .select(FOOD_SELECT)
      .eq("is_available", true);
    if (intent.keyword) {
      relaxed = relaxed.or(
        `name.ilike.%${intent.keyword}%,description.ilike.%${intent.keyword}%`,
      );
    } else if (intent.category) {
      relaxed = relaxed.ilike("category", `%${intent.category}%`);
    }
    const r = await relaxed.limit(60);
    candidates = r.data;
    error = r.error;
  }

  if (error) {
    return errorResponse("Database query failed.", error.message, 500);
  }
  if (!candidates || candidates.length === 0) {
    return json({ intent, results: [] });
  }

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
    const content = await callOpenRouter([
      { role: "system", content: RANK_SYSTEM_PROMPT },
      {
        role: "user",
        content: `User request: "${query}"\nBudget max_price: ${
          intent.max_price ?? "none"
        }\nCandidates:\n${JSON.stringify(slim)}`,
      },
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

  return json({ intent, results });
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
    const content = await callOpenRouter([
      { role: "system", content: VISION_SYSTEM_PROMPT },
      {
        role: "user",
        content: [
          { type: "text", text: "What dish is in this photo?" },
          {
            type: "image_url",
            image_url: { url: `data:${mimeType};base64,${imageBase64}` },
          },
        ],
      },
    ]);
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
    const content = await callOpenRouter([
      { role: "system", content: RANK_SYSTEM_PROMPT },
      {
        role: "user",
        content: `User uploaded a photo of: "${dishName}" (keywords: ${keywords.join(
          ", ",
        )}). Pick the menu dishes that best match this dish.\nCandidates:\n${JSON.stringify(
          slim,
        )}`,
      },
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
  if (!OPENROUTER_API_KEY) {
    return errorResponse(
      "Server misconfiguration.",
      "OPENROUTER_API_KEY secret is not set on the Edge Function.",
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
