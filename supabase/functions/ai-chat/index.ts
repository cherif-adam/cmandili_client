// Supabase Edge Function: ai-chat
//
// Server-side brain for the in-app "Cmandili Assistant" (the purple chat FAB).
// It exists so the OpenRouter API key NEVER ships inside the mobile app — the
// app used to call OpenRouter directly with the key bundled in its .env asset,
// which is extractable from the released APK/IPA. This mirrors the existing
// `ai-search` function: the secret lives only as a Supabase secret here.
//
// Request body (POST, JSON):
//   {
//     "text":        string,                       // user message (may be "")
//     "history":     [{role, parts:[{text}]}] | [] // Gemini-style chat history
//     "imageBase64": string | undefined,           // optional photo (vision)
//     "mimeType":    string | undefined            // e.g. "image/jpeg"
//   }
//
// Response (HTTP 200) — the structured intent the app's `_AiIntent` expects:
//   {
//     "message": string,
//     "intent": "greeting" | "search_food" | "delivery_request" | "shop_search" | "general",
//     "health_goal": "diet" | "sport" | "diabetes" | "cholesterol" | "vegetarian" | "iftar" | null,
//     "category": string | null,
//     "spicy": boolean | null,
//     "vegetarian": boolean | null,
//     "max_price": number | null,
//     "min_price": number | null,
//     "delivery_time": "fast" | "any" | null,
//     "keyword": string | null
//   }
//   error -> { error: string, details?: string }
//
// The app still runs the food_items / grocery_items queries itself (plain
// RLS-guarded reads, no secret needed) and builds the product cards — so card
// images, navigation and persistence are unchanged. Only the LLM call moved.
//
// Secrets required (set with `supabase secrets set ...`):
//   OPENROUTER_API_KEY     sk-or-v1-...   the OpenRouter key (SERVER-ONLY)
//   OPENROUTER_CHAT_MODEL  e.g. google/gemini-2.5-flash  (optional, has default)
//   GEMINI_API_KEY         AIza...        fallback: direct Google Gemini API.
//                          Used whenever the OpenRouter call fails (bad key,
//                          no credits, outage) — same model family, so the
//                          assistant behaves identically. At least ONE of the
//                          two keys must be set.

// .trim() defends against secrets pasted with stray whitespace/newlines.
const OPENROUTER_API_KEY = (Deno.env.get("OPENROUTER_API_KEY") ?? "").trim();
// Vision-capable default — matches the model the client used before the move.
const OPENROUTER_MODEL =
  (Deno.env.get("OPENROUTER_CHAT_MODEL") ?? "google/gemini-2.5-flash").trim();

const GEMINI_API_KEY = (Deno.env.get("GEMINI_API_KEY") ?? "").trim();
// Same model as the OpenRouter default, minus the "google/" route prefix.
const GEMINI_MODEL = (Deno.env.get("GEMINI_CHAT_MODEL") ?? "gemini-2.5-flash").trim();

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

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

// ── System prompt ───────────────────────────────────────────────────────────
// Ported VERBATIM from the old client-side AiChatService._buildSystemPrompt so
// the assistant's behaviour (language matching, nutrition advice, dish-search
// intent extraction, vision) is preserved exactly.
const SYSTEM_PROMPT =
  `You are "Cmandili Assistant" — a warm, knowledgeable nutrition expert AND food discovery guide for the Cmandili platform in Kairouan, Tunisia.
The platform has 3 services: Food (restaurants & pastry shops), P2P Logistics (courier delivery), Shops (retail stores).

━━━ RULE 1 — LANGUAGE (ABSOLUTE) ━━━
Detect the user's language from their FIRST message and stay in it for the ENTIRE conversation.
• Tunisian Derja (aaslema, n7eb, chnoua, besh, 7lew...) → authentic warm Derja, Franco-Arab mix is fine.
• French (bonjour, je veux...) → fluent, friendly French.
• Arabic (مرحبا، أريد...) → Modern Standard Arabic, warm tone.
• English (hello, I want...) → professional English.
NEVER default to English. NEVER switch languages mid-conversation. NEVER use Fusha if user speaks Derja.

━━━ RULE 2 — CONTEXT BOUNDARY (STRICT) ━━━
You ONLY discuss: food, nutrition, health related to food, the platform's restaurants/dishes, delivery questions.
If the user asks about ANYTHING else (politics, weather, love, tech, news, etc.):
• FR: "Je suis spécialisé en nutrition et découverte culinaire à Kairouan ! Puis-je vous aider à trouver un plat sain ? 🍽️"
• TN: "Ana mta3 el makla w el sa77a bil akl! Yji n3awnek tlqa 7aja zina? 🍽️"
• AR: "أنا متخصص في التغذية واكتشاف المطاعم! هل يمكنني مساعدتك في إيجاد طبق صحي؟ 🍽️"
Never break character or act as a general AI assistant.

━━━ RULE 3 — DUAL ROLE: NUTRITION ADVISOR + FOOD DISCOVERY ━━━
You have TWO roles you MUST balance in every health-related response:

ROLE A — Nutrition Advisor:
When user mentions a health goal (régime, diet, weight loss, sport, musculation, diabète, cholestérol, végétarien, etc.):
1. Give SPECIFIC, scientifically-grounded advice (not generic "eat vegetables").
2. Explain WHY: mention proteins, calories, fiber, glycemic index, etc. briefly.
3. If context is missing, ask ONE clarifying question (e.g., budget? allergies? schedule?).
Keep advice concise — max 2-3 sentences before transitioning to food suggestions.

ROLE B — Smart Food Discovery:
After any health advice, ALWAYS end with a food search by setting intent:"search_food" + health_goal.
Explain in "message" WHY the suggested dishes fit their goal.
Example: "Le poulet grillé est riche en protéines et pauvre en graisses — parfait pour ta musculation 💪"

━━━ RULE 4 — HEALTH GOAL → FOOD MATCHING ━━━
Map user's health goal to the best food search strategy using health_goal field:
• "régime" / "diet" / "maigrir" / "perte de poids" → health_goal:"diet" → search: grillé, salade, poulet, poisson, légumes, light
• "sport" / "musculation" / "protéines" → health_goal:"sport" → search: poulet, viande, œufs, légumineuses, thon
• "diabète" / "sucre" → health_goal:"diabetes" → search: grillé, légumes, poisson, salade, fibres (avoid: sucré, pâtisserie)
• "cholestérol" / "cœur" → health_goal:"cholesterol" → search: poisson, légumes, salade (avoid: friterie, gras)
• "végétarien" / "vegan" → health_goal:"vegetarian" → vegetarian:true, exclude meat
• "ramadan" / "iftar" → health_goal:"iftar" → search: harissa, chorba, brik, dattes
• null if no health goal mentioned

━━━ RULE 5 — CONVERSATION MEMORY ━━━
The conversation history is passed to you. USE IT.
• Remember the user's stated goal, restrictions, allergies, budget from earlier messages.
• Reference context naturally: "Comme tu m'as dit que tu fais un régime..." / "Mabrouk 3lik el régime!"
• Never ask for information the user already gave you.

━━━ VISION / IMAGE RULE ━━━
If the user provides an IMAGE:
1. Identify the food shown (pizza, salade, burger, etc.).
2. Set intent:"search_food" and keyword:"<identified_food>".
3. Confirm in message what you saw: "Je vois une pizza 🍕 Je vous cherche les meilleures disponibles !"
4. If NOT food → intent:"general", explain you only handle food/delivery/shops.

━━━ PHOTO REQUEST RULE ━━━
"voir les photos / show images / أعطيني الصور" → They want food cards with images.
Set intent:"search_food" and search for the last mentioned item.

━━━ OUTPUT FORMAT — RAW JSON ONLY. NO MARKDOWN. NO BACKTICKS. ━━━
{
  "message": string,
  "intent": "greeting" | "search_food" | "delivery_request" | "shop_search" | "general",
  "health_goal": "diet" | "sport" | "diabetes" | "cholesterol" | "vegetarian" | "iftar" | null,
  "category": string | null,
  "spicy": boolean | null,
  "vegetarian": boolean | null,
  "max_price": number | null,
  "min_price": number | null,
  "delivery_time": "fast" | "any" | null,
  "keyword": string | null
}

"message": Same language as user. Max 200 chars. End with 1 relevant emoji. For health responses: include the WHY (nutrition benefit).
"health_goal": set whenever user mentions health/diet/sport context.
"category": pizza/burger/patisserie/couscous/salade/sandwich/poulet/poisson/pharmacie/supermarche or null.
"keyword": specific food name (from image or text) or null.
"vegetarian": true only if user explicitly said they are vegetarian.
"spicy": true only if explicitly mentioned.
"delivery_time": "fast" only if user wants quick delivery.

━━━ EXAMPLES ━━━

[TN] "aaslema"
→ {"message":"Aaslema bik! Ana mta3 el makla w el sa77a. Chnoua t7eb elloum? 🍽️","intent":"greeting","health_goal":null,"category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[TN] "n7eb nrégim"
→ {"message":"Bravo 3lik! Lel régime, el poulet el mchwi w el salades a7sen khyar: qalil calories w ycha33b. Hani njiblek el a7sen disponibles! 🥗","intent":"search_food","health_goal":"diet","category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":"poulet grillé"}

[FR] "je fais de la musculation, qu'est-ce que tu me conseilles ?"
→ {"message":"Pour la musculation, priorise les protéines : poulet grillé, thon, légumineuses. Voici les plats riches en protéines disponibles 💪","intent":"search_food","health_goal":"sport","category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":"poulet"}

[FR] "je veux une pizza thon"
→ {"message":"Voici les pizzas au thon disponibles ! 🍕","intent":"search_food","health_goal":null,"category":"pizza","spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":"thon"}

[FR] "bonjour"
→ {"message":"Bonjour ! Je suis votre conseiller nutrition et découverte culinaire à Kairouan. Comment puis-je vous aider ? 😊","intent":"greeting","health_goal":null,"category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[AR] "أريد طعاماً صحياً لمريض السكري"
→ {"message":"لمريض السكري، أنصح بالأسماك المشوية والخضروات الغنية بالألياف لأنها تُحافظ على استقرار السكر. إليك أفضل الأطباق المتوفرة 🐟","intent":"search_food","health_goal":"diabetes","category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":"poisson"}

[TN] "chnoua el a7sen lel cholestérol ?"
→ {"message":"Lel cholestérol, el 7out el mchwi w el khodhra a7sen khyar: ynaqqso el cholestérol el khi w yzi3o el galb. Njiblek disponibles! 🐟","intent":"search_food","health_goal":"cholesterol","category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":"poisson"}

[FR] "quel temps fait-il à Kairouan ?"
→ {"message":"Je suis spécialisé en nutrition et découverte culinaire à Kairouan ! Puis-je vous aider à trouver un plat sain ? 🍽️","intent":"general","health_goal":null,"category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[IMAGE - pizza photo]
→ {"message":"Je vois une pizza dans votre photo ! 🍕 Voici les meilleures pizzas disponibles !","intent":"search_food","health_goal":null,"category":"pizza","spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":"pizza"}`;

// ── OpenRouter call ───────────────────────────────────────────────────────────

async function callOpenRouter(messages: unknown[]): Promise<string> {
  console.log(`[ai-chat] calling OpenRouter model="${OPENROUTER_MODEL}"`);
  const res = await fetch(OPENROUTER_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${OPENROUTER_API_KEY}`,
      "Content-Type": "application/json",
      "HTTP-Referer": "https://cmandili.com",
      "X-Title": "Cmandili Mobile",
    },
    body: JSON.stringify({
      model: OPENROUTER_MODEL,
      response_format: { type: "json_object" },
      messages,
      temperature: 0.4,
      // gemini-2.5-flash is a THINKING model: with a tight max_tokens the
      // reasoning tokens can eat the whole budget and the visible content
      // comes back EMPTY (finish_reason: "length"), which used to throw
      // "OpenRouter returned no content" -> 502 on every message. Disable
      // reasoning so the budget is spent on the JSON answer, and give it
      // generous headroom.
      reasoning: { enabled: false },
      max_tokens: 1024,
    }),
  });

  const raw = await res.text();
  // TEMP DIAGNOSTIC: log status + a slice of the body so the real failure is
  // visible in `supabase functions logs ai-chat` / the dashboard Logs tab.
  console.log(`[ai-chat] OpenRouter status=${res.status} body=${raw.slice(0, 800)}`);
  if (!res.ok) {
    throw new Error(`OpenRouter API error ${res.status}: ${raw}`);
  }

  let parsed: {
    choices?: { message?: { content?: string }; finish_reason?: string }[];
  };
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new Error(`OpenRouter returned non-JSON envelope: ${raw.slice(0, 500)}`);
  }

  const content = parsed.choices?.[0]?.message?.content;
  if (!content) {
    const finish = parsed.choices?.[0]?.finish_reason ?? "unknown";
    throw new Error(
      `OpenRouter returned no content (finish_reason=${finish}): ${raw.slice(0, 500)}`,
    );
  }
  return content;
}

// ── Direct Gemini call (fallback provider) ───────────────────────────────────
// Speaks the native Generative Language API. Same system prompt, same JSON
// output contract, same vision support — so a fallback is invisible to the app.

async function callGemini(
  contents: { role: string; parts: unknown[] }[],
): Promise<string> {
  console.log(`[ai-chat] calling Gemini directly model="${GEMINI_MODEL}"`);
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
    {
      method: "POST",
      headers: {
        "x-goog-api-key": GEMINI_API_KEY,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        system_instruction: { parts: [{ text: SYSTEM_PROMPT }] },
        contents,
        generationConfig: {
          temperature: 0.4,
          maxOutputTokens: 2048,
          responseMimeType: "application/json",
          // gemini-2.5-flash is a thinking model — spend the budget on the
          // JSON answer, not on reasoning (same rationale as the OpenRouter
          // path's `reasoning: { enabled: false }`).
          thinkingConfig: { thinkingBudget: 0 },
        },
      }),
    },
  );

  const raw = await res.text();
  console.log(`[ai-chat] Gemini status=${res.status} body=${raw.slice(0, 400)}`);
  if (!res.ok) {
    throw new Error(`Gemini API error ${res.status}: ${raw.slice(0, 500)}`);
  }

  let parsed: {
    candidates?: {
      content?: { parts?: { text?: string }[] };
      finishReason?: string;
    }[];
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

// Models sometimes wrap JSON in ```json fences despite response_format — strip.
function extractJson<T>(text: string): T {
  let s = text.trim();
  const fence = s.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fence) s = fence[1].trim();
  if (!s.startsWith("{") && !s.startsWith("[")) {
    const obj = s.match(/[{[][\s\S]*[}\]]/);
    if (obj) s = obj[0];
  }
  return JSON.parse(s) as T;
}

// ── Intent shaping ──────────────────────────────────────────────────────────

interface ChatIntent {
  message: string;
  intent: string;
  health_goal: string | null;
  category: string | null;
  spicy: boolean | null;
  vegetarian: boolean | null;
  max_price: number | null;
  min_price: number | null;
  delivery_time: string | null;
  keyword: string | null;
}

function shapeIntent(parsed: Record<string, unknown>): ChatIntent {
  const message = typeof parsed.message === "string" && parsed.message.trim()
    ? (parsed.message as string)
    : "Comment puis-je vous aider ? 😊";
  return {
    message,
    intent: typeof parsed.intent === "string" ? (parsed.intent as string) : "general",
    health_goal: typeof parsed.health_goal === "string" ? (parsed.health_goal as string) : null,
    category: typeof parsed.category === "string" ? (parsed.category as string) : null,
    spicy: typeof parsed.spicy === "boolean" ? (parsed.spicy as boolean) : null,
    vegetarian: typeof parsed.vegetarian === "boolean" ? (parsed.vegetarian as boolean) : null,
    max_price: typeof parsed.max_price === "number" ? (parsed.max_price as number) : null,
    min_price: typeof parsed.min_price === "number" ? (parsed.min_price as number) : null,
    delivery_time: typeof parsed.delivery_time === "string" ? (parsed.delivery_time as string) : null,
    keyword: typeof parsed.keyword === "string" ? (parsed.keyword as string) : null,
  };
}

// Convert the app's Gemini-style history ({role:"user"|"model", parts:[{text}]})
// into OpenAI chat messages. "model" maps to "assistant". This is what makes
// RULE 5 (conversation memory) actually work server-side.
function historyToMessages(history: unknown): { role: string; content: string }[] {
  if (!Array.isArray(history)) return [];
  const out: { role: string; content: string }[] = [];
  for (const turn of history) {
    if (!turn || typeof turn !== "object") continue;
    const t = turn as Record<string, unknown>;
    const role = t.role === "model" || t.role === "assistant" ? "assistant" : "user";
    let text = "";
    const parts = t.parts;
    if (Array.isArray(parts)) {
      for (const p of parts) {
        if (p && typeof p === "object" && typeof (p as Record<string, unknown>).text === "string") {
          text += (p as Record<string, unknown>).text as string;
        }
      }
    } else if (typeof t.content === "string") {
      text = t.content;
    }
    text = text.trim();
    if (text.length > 0) out.push({ role, content: text });
  }
  return out;
}

// ── Entry point ───────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  if (!OPENROUTER_API_KEY && !GEMINI_API_KEY) {
    return errorResponse(
      "Server misconfiguration.",
      "Neither OPENROUTER_API_KEY nor GEMINI_API_KEY secret is set on the Edge Function.",
      500,
    );
  }

  let body: {
    text?: string;
    history?: unknown;
    imageBase64?: string;
    mimeType?: string;
  };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body." }, 400);
  }

  const text = (body.text ?? "").trim();
  const hasImage = typeof body.imageBase64 === "string" && body.imageBase64.length > 0;
  if (text.length === 0 && !hasImage) {
    return json({ error: "Empty message." }, 400);
  }

  // Build the current user turn: text only, or text + image for Vision.
  let userContent: unknown;
  if (hasImage) {
    const mimeType = body.mimeType && body.mimeType.length > 0
      ? body.mimeType
      : "image/jpeg";
    userContent = [
      ...(text.length > 0 ? [{ type: "text", text }] : []),
      {
        type: "image_url",
        image_url: { url: `data:${mimeType};base64,${body.imageBase64}` },
      },
    ];
  } else {
    userContent = text;
  }

  const history = historyToMessages(body.history);

  const messages = [
    { role: "system", content: SYSTEM_PROMPT },
    ...history,
    { role: "user", content: userContent },
  ];

  // Same conversation in native Gemini shape (history + current turn).
  const geminiContents: { role: string; parts: unknown[] }[] = [
    ...history.map((m) => ({
      role: m.role === "assistant" ? "model" : "user",
      parts: [{ text: m.content }],
    })),
    {
      role: "user",
      parts: [
        ...(text.length > 0 ? [{ text }] : []),
        ...(hasImage
          ? [{
            inline_data: {
              mime_type: body.mimeType && body.mimeType.length > 0
                ? body.mimeType
                : "image/jpeg",
              data: body.imageBase64,
            },
          }]
          : []),
      ],
    },
  ];

  try {
    // OpenRouter is the primary provider; direct Gemini covers ANY OpenRouter
    // failure (invalid key, 402 no credits, outage) so the assistant stays up.
    let content: string;
    if (!OPENROUTER_API_KEY) {
      console.warn("[ai-chat] no OPENROUTER_API_KEY — using direct Gemini");
      content = await callGemini(geminiContents);
    } else {
      try {
        content = await callOpenRouter(messages);
      } catch (e) {
        if (!GEMINI_API_KEY) throw e;
        console.warn(
          `[ai-chat] OpenRouter failed, falling back to direct Gemini: ${
            String(e).slice(0, 200)
          }`,
        );
        content = await callGemini(geminiContents);
      }
    }
    const parsed = extractJson<Record<string, unknown>>(content);
    return json(shapeIntent(parsed));
  } catch (e) {
    // Surface the real cause in the Edge Function logs (dashboard Logs tab /
    // `supabase functions logs ai-chat`), not just to the client.
    console.error("[ai-chat] request failed:", e);
    return errorResponse("Failed to get AI response.", String(e), 502);
  }
});
