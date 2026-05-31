/**
 * ai-search — Cmandili AI Search Edge Function (v2)
 *
 * Handles two search modes in one function:
 *
 *   Mode 1: "text" — Conversational assistant in Darija / French / English.
 *     Body: { mode: "text", query: "bonsoir" | "n7eb pizza" | "je veux pizza thon" }
 *     → Gemini returns a rich JSON with intent, conversational message, and
 *       search filters → query food_items with filters (skipped for greetings).
 *     → Response includes { mode, intent, message, results }
 *
 *   Mode 2: "image" — Visual search (order by photo).
 *     Body: { mode: "image", imageBase64: "<base64 string>", mimeType: "image/jpeg" }
 *     → Gemini identifies the dish → FTS search on food_items.name + restaurants.
 *
 * Required env vars (set via `supabase secrets set`):
 *   GEMINI_API_KEY   — Google AI Studio API key
 *   SERVICE_ROLE_KEY — Supabase service-role JWT (bypasses RLS)
 *   SUPABASE_URL     — injected automatically by the Supabase runtime
 *
 * Deploy: supabase functions deploy ai-search
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ── Types ──────────────────────────────────────────────────────────────────────

/**
 * The full structured response Gemini returns for a text query.
 * Includes both the conversational reply AND the search filters.
 */
interface GeminiTextResponse {
  // Conversational reply in the user's detected language (Derja / French / English)
  message: string;
  // High-level intent: "greeting" skips the DB query entirely
  intent: 'greeting' | 'search_food' | 'general';
  // Search filters (null = not applicable / not mentioned)
  category: string | null;
  spicy: boolean | null;
  vegetarian: boolean | null;
  max_price: number | null;
  min_price: number | null;
  delivery_time: 'fast' | 'any' | null;
  keyword: string | null;
}

// ── Gemini helpers ─────────────────────────────────────────────────────────────

const GEMINI_URL = (key: string) =>
  `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=${key}`;

/**
 * System prompt for TEXT mode.
 *
 * Instructs Gemini to act as a friendly bilingual/trilingual assistant AND
 * as a structured search-intent extractor — all in a single JSON response.
 */
function buildTextSystemPrompt(): string {
  return `You are "Cmandili Assistant", a friendly AI for a Tunisian food-delivery app.
Your job is to understand the user's message, reply naturally in their language, and extract any food search intent.

━━━ LANGUAGE RULES ━━━
- Detect the language automatically from the user's message.
- If the user writes in Tunisian Darija (e.g. "aaslema", "n7eb", "besh", "7aja"), reply ENTIRELY in Tunisian Darija.
- If the user writes in French (e.g. "bonsoir", "je veux", "pizza thon"), reply ENTIRELY in French.
- If the user writes in English, reply ENTIRELY in English.
- NEVER mix languages in the "message" field.

━━━ DARIJA GLOSSARY ━━━
- "aaslema / salam / bonsoir / bonne nuit" → greeting
- "n7eb nekel / nbghi nakol / nheb / je veux / I want" → I want to eat
- "7arra / harr / épicé / spicy" → spicy: true
- "bila la7em / végétarien / vegetarian" → vegetarian: true
- "fissa3 / sari3 / rapide / fast" → delivery_time: "fast"
- "ma tfoutch X dinar / moins de X / under X" → max_price: X
- "pizza / burger / couscous / sandwich / kafteji / lablabi / fricassee / thon / viande" → category or keyword

━━━ OUTPUT RULES — CRITICAL ━━━
- Respond with RAW JSON ONLY. No explanation, no markdown, no backticks.
- The JSON MUST strictly conform to this schema:
{
  "message": string,
  "intent": "greeting" | "search_food" | "general",
  "category": string | null,
  "spicy": boolean | null,
  "vegetarian": boolean | null,
  "max_price": number | null,
  "min_price": number | null,
  "delivery_time": "fast" | "any" | null,
  "keyword": string | null
}

━━━ FIELD RULES ━━━
"message":
  - For greetings: a warm, friendly greeting reply in the user's language.
    Examples: "Bonsoir ! Comment puis-je vous aider ? 😊" / "Aaslema ! Chnowa t7eb takol ? 🍽️"
  - For food searches: a short, enthusiastic confirmation of what you're searching for.
    Examples: "Voilà les pizzas au thon disponibles ! 🍕" / "N7eb nlqilek pizza thon ! 🍕"
  - For general questions: answer helpfully in the user's language.
  - ALWAYS add 1 emoji at the end of the message. Keep it under 120 characters.

"intent":
  - "greeting"    → user is ONLY greeting, no food request (e.g. "bonsoir", "aaslema", "hello", "merci")
  - "search_food" → user wants to find or order food
  - "general"     → other (complaint, question about delivery, etc.)

"category": main food category in English (e.g. "pizza", "burger", "couscous") or null.
"keyword": specific dish name or key ingredient (e.g. "thon", "fromage", "merguez") or null.
"spicy", "vegetarian": true only if explicitly mentioned, otherwise null.
"delivery_time": "fast" only if user wants quick delivery, otherwise null.
"max_price", "min_price": price in TND as a number, or null.

━━━ EXAMPLES ━━━
User: "bonsoir"
→ {"message":"Bonsoir ! Comment puis-je vous aider ce soir ? 😊","intent":"greeting","category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

User: "aaslema"
→ {"message":"Aaslema ! Chnowa t7eb takol elloum ? 🍽️","intent":"greeting","category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

User: "je veux un pizza thon"
→ {"message":"Voilà les pizzas au thon disponibles près de chez vous ! 🍕","intent":"search_food","category":"pizza","spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":"thon"}

User: "n7eb 7aja 7arra w ma tfoutch 15 dinar"
→ {"message":"Nlqilek 7aja 7arra w rkhisa ! 🌶️","intent":"search_food","category":null,"spicy":true,"vegetarian":null,"max_price":15,"min_price":null,"delivery_time":null,"keyword":null}`;
}

/**
 * System prompt for IMAGE mode.
 * Returns ONLY a JSON object with dish_name and confidence.
 */
function buildImageSystemPrompt(): string {
  return `You are a food recognition engine for a Tunisian food-delivery app.
Analyse the provided food image and identify the dish shown.

OUTPUT RULES — CRITICAL:
- Respond with RAW JSON only. No explanation, no markdown, no backticks.
- The JSON must strictly conform to this schema:
{
  "dish_name": string,
  "confidence": "high" | "medium" | "low"
}

If you cannot identify any food in the image, return:
{ "dish_name": null, "confidence": "low" }`;
}

async function callGeminiText(
  apiKey: string,
  systemPrompt: string,
  userText: string,
): Promise<string> {
  const body = {
    contents: [
      {
        role: 'user',
        parts: [
          { text: systemPrompt + '\n\n---\n\nUser message: ' + userText },
        ],
      },
    ],
    generationConfig: {
      temperature: 0.4,
      topP: 0.9,
      maxOutputTokens: 512,
    },
  };

  const resp = await fetch(GEMINI_URL(apiKey), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  if (!resp.ok) {
    const errText = await resp.text();
    throw new Error(`Gemini API error ${resp.status}: ${errText}`);
  }

  const data = await resp.json();
  const rawText: string = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
  return rawText.trim();
}

async function callGeminiVision(
  apiKey: string,
  systemPrompt: string,
  imageBase64: string,
  mimeType: string,
): Promise<string> {
  const body = {
    contents: [
      {
        role: 'user',
        parts: [
          {
            text:
              systemPrompt +
              '\n\nNow identify the food dish shown in the image below and return ONLY the JSON.',
          },
          {
            inline_data: {
              mime_type: mimeType,
              data: imageBase64,
            },
          },
        ],
      },
    ],
    generationConfig: {
      temperature: 0.1,
      topP: 0.8,
      maxOutputTokens: 256,
    },
  };

  const resp = await fetch(GEMINI_URL(apiKey), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  if (!resp.ok) {
    const errText = await resp.text();
    throw new Error(`Gemini Vision API error ${resp.status}: ${errText}`);
  }

  const data = await resp.json();
  const rawText: string = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
  return rawText.trim();
}

/**
 * Robustly parses JSON from Gemini's output.
 * Handles cases where the model wraps JSON in markdown code fences despite instructions.
 */
function parseGeminiJson(raw: string): Record<string, unknown> {
  const cleaned = raw
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/```\s*$/, '')
    .trim();

  return JSON.parse(cleaned);
}

// ── Database query helpers ─────────────────────────────────────────────────────

async function searchByIntent(
  supabase: ReturnType<typeof createClient>,
  intent: GeminiTextResponse,
): Promise<unknown[]> {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let query = (supabase as any)
    .from('food_items')
    .select(`
      id,
      name,
      description,
      price,
      discount_price,
      image_url,
      category,
      is_spicy,
      is_vegetarian,
      preparation_time,
      restaurant_id,
      restaurants (
        id,
        name,
        image_url,
        rating,
        delivery_time_min,
        delivery_fee,
        is_open
      )
    `)
    .eq('is_available', true)
    .eq('restaurants.is_open', true);

  if (intent.spicy === true)      query = query.eq('is_spicy', true);
  if (intent.vegetarian === true) query = query.eq('is_vegetarian', true);
  if (intent.max_price != null)   query = query.lte('price', intent.max_price);
  if (intent.min_price != null)   query = query.gte('price', intent.min_price);
  if (intent.delivery_time === 'fast') query = query.lte('preparation_time', 20);

  if (intent.category && intent.category !== 'general') {
    query = query.ilike('category', `%${intent.category}%`);
  }
  if (intent.keyword) {
    query = query.or(
      `name.ilike.%${intent.keyword}%,description.ilike.%${intent.keyword}%`,
    );
  }

  query = query.order('price', { ascending: true }).limit(20);

  const { data, error } = await query;
  if (error) throw new Error(`DB query error: ${error.message}`);
  return data ?? [];
}

async function searchByDishName(
  supabase: ReturnType<typeof createClient>,
  dishName: string,
): Promise<unknown[]> {
  const keywords = dishName.split(/\s+/).filter(Boolean);

  const { data, error } = await (supabase as any)
    .from('food_items')
    .select(`
      id,
      name,
      description,
      price,
      discount_price,
      image_url,
      category,
      is_spicy,
      is_vegetarian,
      preparation_time,
      restaurant_id,
      restaurants (
        id,
        name,
        image_url,
        rating,
        delivery_time_min,
        delivery_fee,
        is_open
      )
    `)
    .eq('is_available', true)
    .or(
      keywords
        .map((kw: string) => `name.ilike.%${kw}%,description.ilike.%${kw}%`)
        .join(','),
    )
    .order('name')
    .limit(20);

  if (error) throw new Error(`DB FTS error: ${error.message}`);
  return data ?? [];
}

// ── CORS headers ───────────────────────────────────────────────────────────────

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// ── Main handler ───────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  // Read env vars
  const geminiKey  = Deno.env.get('GEMINI_API_KEY');
  const serviceKey = Deno.env.get('SERVICE_ROLE_KEY');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');

  if (!geminiKey || !serviceKey || !supabaseUrl) {
    console.error('Missing env vars:', {
      geminiKey: !!geminiKey,
      serviceKey: !!serviceKey,
      supabaseUrl: !!supabaseUrl,
    });
    return jsonResponse(
      { error: 'Server misconfiguration: missing environment variables.' },
      500,
    );
  }

  // Parse request body
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }

  const mode = body['mode'] as string | undefined;
  if (!mode || !['text', 'image'].includes(mode)) {
    return jsonResponse({ error: 'Invalid mode. Must be "text" or "image".' }, 400);
  }

  const supabase = createClient(supabaseUrl, serviceKey);

  // ── MODE 1: Conversational Text Search ──────────────────────────────────────
  if (mode === 'text') {
    const query = body['query'] as string | undefined;
    if (!query || query.trim().length === 0) {
      return jsonResponse({ error: 'Missing or empty "query" field.' }, 400);
    }

    // ── Step 1: Call Gemini — get conversational reply + search intent ──────
    let geminiResponse: GeminiTextResponse;
    let rawGeminiOutput = '';

    try {
      rawGeminiOutput = await callGeminiText(
        geminiKey,
        buildTextSystemPrompt(),
        query,
      );
      const parsed = parseGeminiJson(rawGeminiOutput);
      geminiResponse = parsed as GeminiTextResponse;

      // Defensive: ensure required fields exist
      if (!geminiResponse.message) {
        geminiResponse.message = "Je suis là pour vous aider ! 😊";
      }
      if (!geminiResponse.intent) {
        geminiResponse.intent = 'general';
      }
    } catch (err) {
      console.error('Gemini text parse error:', err, 'Raw output:', rawGeminiOutput);
      return jsonResponse(
        {
          error: 'Failed to parse AI response.',
          details: String(err),
          rawOutput: rawGeminiOutput,
        },
        502,
      );
    }

    // ── Step 2: Skip DB query entirely for greetings & general chat ─────────
    if (geminiResponse.intent === 'greeting' || geminiResponse.intent === 'general') {
      return jsonResponse({
        mode: 'text',
        intent: geminiResponse.intent,
        message: geminiResponse.message,
        results: [],       // ← empty: no food cards for greetings
      });
    }

    // ── Step 3: Query DB with the extracted search filters ───────────────────
    let results: unknown[];
    try {
      results = await searchByIntent(supabase, geminiResponse);
    } catch (err) {
      return jsonResponse(
        { error: 'Database query failed.', details: String(err) },
        500,
      );
    }

    // ── Step 4: Return everything — message + results ────────────────────────
    return jsonResponse({
      mode: 'text',
      intent: geminiResponse.intent,
      message: geminiResponse.message,   // ← Flutter reads this for the chat bubble
      results,
    });
  }

  // ── MODE 2: Visual Search (Image) ───────────────────────────────────────────
  if (mode === 'image') {
    const imageBase64 = body['imageBase64'] as string | undefined;
    const mimeType = (body['mimeType'] as string | undefined) ?? 'image/jpeg';

    if (!imageBase64 || imageBase64.trim().length === 0) {
      return jsonResponse({ error: 'Missing or empty "imageBase64" field.' }, 400);
    }

    let dishName: string | null = null;
    let confidence = 'low';
    let rawGeminiOutput = '';

    try {
      rawGeminiOutput = await callGeminiVision(
        geminiKey,
        buildImageSystemPrompt(),
        imageBase64,
        mimeType,
      );
      const parsed = parseGeminiJson(rawGeminiOutput);
      dishName   = (parsed['dish_name'] as string | null) ?? null;
      confidence = (parsed['confidence'] as string) ?? 'low';
    } catch (err) {
      console.error('Gemini vision parse error:', err, 'Raw output:', rawGeminiOutput);
      return jsonResponse(
        {
          error: 'Failed to parse AI vision response.',
          details: String(err),
          rawOutput: rawGeminiOutput,
        },
        502,
      );
    }

    if (!dishName) {
      return jsonResponse({
        mode: 'image',
        dish_name: null,
        confidence,
        results: [],
        message: 'No food dish detected in the image.',
      });
    }

    let results: unknown[];
    try {
      results = await searchByDishName(supabase, dishName);
    } catch (err) {
      return jsonResponse(
        { error: 'Database FTS query failed.', details: String(err) },
        500,
      );
    }

    return jsonResponse({
      mode: 'image',
      dish_name: dishName,
      confidence,
      message: `Voilà ce que j'ai trouvé pour "${dishName}" 🍽️`,
      results,
    });
  }

  return jsonResponse({ error: 'Unknown mode' }, 400);
});