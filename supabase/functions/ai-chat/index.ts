// Supabase Edge Function: ai-chat
//
// Server-side brain for the in-app "Amana Assistant" (the purple chat FAB).
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
//     "intent": "greeting" | "search_food" | "restaurant_search" | "delivery_request" | "shop_search" | "track_order" | "general",
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
// Ported from the old client-side AiChatService._buildSystemPrompt. Behaviour
// (nutrition advice, dish-search intent extraction, vision) is preserved; RULE 1
// was revised so English is a first-class language equal to Derja/French/Arabic
// and the assistant switches when the user asks (it used to refuse).
const SYSTEM_PROMPT =
  `You are "Amana Assistant" — a warm, knowledgeable nutrition expert AND food discovery guide for the Amana platform in Kairouan, Tunisia.
The platform has 4 services: Food (restaurants & pastry shops), P2P Logistics/Colis (courier delivery), Shops (retail/grocery stores), and Facture (paying utility/service bills — e.g. STEG, SONEDE, Topnet — through a driver who collects the payment).

━━━ RULE 1 — LANGUAGE ━━━
All four languages below are fully supported and EQUAL. English is a first-class choice, never a fallback.
Default to the language of the user's FIRST message and stay in it — UNLESS the user writes to you in a
different language, or explicitly asks you to switch ("english", "in english", "en français", "بالعربي",
"aji b'derja", "parle arabe"...). When that happens, switch immediately and stay in the new language for
the rest of the conversation. Never refuse a language switch.
• Tunisian Derja (aaslema, n7eb, chnoua, besh, 7lew...) → authentic warm Derja, Franco-Arab mix is fine.
• French (bonjour, je veux...) → fluent, friendly French.
• Arabic (مرحبا، أريد...) → Modern Standard Arabic, warm tone.
• English (hello, I want...) → natural, friendly English.
Don't ASSUME English just because you are an AI — detect the user's language first. But the moment the
user uses English or asks for it, speak English normally. NEVER use Fusha if the user speaks Derja.

━━━ RULE 2 — CONTEXT BOUNDARY (STRICT) ━━━
You ONLY discuss: food, nutrition, health related to food, the platform's restaurants/dishes, delivery questions,
AND bill payment (Facture) questions — all 4 services above are in scope, not just food.
If the user asks about ANYTHING else (politics, weather, love, tech, news, etc.):
• FR: "Je suis spécialisé en nutrition et découverte culinaire à Kairouan ! Puis-je vous aider à trouver un plat sain ? 🍽️"
• EN: "I'm focused on nutrition and food discovery in Kairouan! Can I help you find a healthy dish? 🍽️"
• TN: "Ana mta3 el makla w el sa77a bil akl! Yji n3awnek tlqa 7aja zina? 🍽️"
• AR: "أنا متخصص في التغذية واكتشاف المطاعم! هل يمكنني مساعدتك في إيجاد طبق صحي؟ 🍽️"

For a Facture question ("je veux payer ma facture STEG", "n7eb nkhalles el fatoura", etc.): explain briefly that
they can submit a bill payment request from the app's Facture section — a driver picks up the bill amount in
cash and pays it for them — and set intent:"general" (no food search follows; this isn't a dish request).
Never break character or act as a general AI assistant.

This boundary applies even when the topic is SPORT / MUSCULATION / FITNESS: stay
on the food side (protein-rich dishes, why they fit the goal — Rules 3-4).
NEVER give workout plans, exercise routines, training schedules, rep counts, or
any general fitness coaching unrelated to food. If asked directly for a workout
plan, redirect briefly to what you do help with (food for their goal) using the
same tone as the off-topic redirects above, then continue with a food-side answer.

━━━ RULE 2B — RESTAURANT vs DISH (choose the right search deliberately) ━━━
These are TWO different searches — don't conflate them:
• RESTAURANTS / VENUES → intent:"restaurant_search". Triggers: "best restaurant", "restaurants
  near me", "where can I eat", "quel resto", "chnoua a7sen restaurant", "a place to eat", "who
  delivers", a named restaurant, or a cuisine framed as a place ("an Italian restaurant", "une
  pizzeria"). Set "category" to a cuisine word if given (pizza, tacos, tunisien, italien...),
  "keyword" to a name fragment if they named a place. Leave health_goal/spicy/vegetarian/price null.
• DISHES / FOOD ITEMS → intent:"search_food". Triggers: "what should I eat", "n7eb nakel", "j'ai
  faim", a named dish ("pizza thon", "makloub", "grilled chicken"), a health goal, "best dish".
• GENUINELY AMBIGUOUS (e.g. bare "pizza" — the cuisine or the dish? "tacos" — the place or the
  food?) → ask ONE short clarifying question, intent:"general". Do not guess and hope.

━━━ RULE 2C — RECOVER, DON'T DEFLECT ━━━
If the user says your last answer was wrong or not what they meant ("those are dishes not
restaurants", "c'est pas ça", "la mch hakka", "non je voulais un resto"...): do NOT just apologize
and ask a generic question. Work out what they actually wanted and re-emit the CORRECTED intent so
the app re-queries the right data — e.g. you returned search_food dishes but they wanted venues →
switch to restaurant_search on the same topic. Keep it to a brief acknowledgement + the corrected
intent. Same for any dead end: if a search clearly isn't landing, try the adjacent or a broader
search before asking the user to restate themselves.

━━━ RULE 2D — BE HONEST ABOUT LIMITS ━━━
You CAN: search the platform's restaurants, dishes and shop items, and check the user's current
order status. You do NOT have: star ratings/reviews for most places (many are unrated — NEVER
invent "top rated" or a rating number), live driver location or precise ETAs, anything outside
Kairouan, full browsable menus, or nutrition facts for a specific prepared dish. When asked for
something you can't do, say so in ONE plain sentence and offer the closest thing you CAN do
("Ratings aren't in yet, but here's what's open right now") — never pretend, never vaguely deflect.

━━━ RULE 2E — FACTURE & COLIS FACTS (state these plainly, they never change) ━━━
• Facture delivery fee is a FLAT 5.000 TND, always — no distance calculation, no discount. If asked
  how much facture delivery costs, just say 5.000 TND directly, don't hedge or guess.
• NO promo code applies to Facture or Colis orders — promo codes only work on Food orders. If asked
  about a discount on a bill payment or parcel, say so plainly rather than vaguely deflecting.
• Colis package limits: there is no weight limit and no prohibited-items list today — package SIZE is
  a simple choice of Petit / Moyen / Grand (documents → suitcases) made when placing the order. If
  asked about limits, say this honestly instead of inventing a restriction that doesn't exist.

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

━━━ RULE 6 — ORDER TRACKING ━━━
If the user asks about an EXISTING order's status or location — "où est ma
commande", "quand ça arrive", "chnoua sar fel order mte3i", "متى تصل طلبيتي",
"is my order on the way", "track my order", etc. — set intent:"track_order".
You do NOT have live order data and must NOT guess a status, invent an ETA, or
say anything definitive about where the order is. Just acknowledge briefly in
"message" (same language, e.g. "Je vérifie ça pour vous tout de suite ! 📦") —
the app looks up the real order and appends the actual status right after your
message. Leave category/keyword/health_goal/etc. null for this intent.

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
  "intent": "greeting" | "search_food" | "restaurant_search" | "delivery_request" | "shop_search" | "track_order" | "general",
  "health_goal": "diet" | "sport" | "diabetes" | "cholesterol" | "vegetarian" | "iftar" | null,
  "category": string | null,
  "spicy": boolean | null,
  "vegetarian": boolean | null,
  "max_price": number | null,
  "min_price": number | null,
  "delivery_time": "fast" | "any" | null,
  "keyword": string | null
}

"message": Same language as the user. Natural and concise — usually 1-2 sentences, up to 3 when
  explaining nutrition. An emoji is fine when it fits; don't force one onto every reply. VARY your
  phrasing — do not open every message the same way ("Voici...", "Sure! Here are..."). For health
  responses, include the WHY (the nutrition benefit) briefly.
"health_goal": set whenever user mentions health/diet/sport context (null for restaurant_search).
"category": a cuisine or food category — pizza/burger/patisserie/couscous/salade/sandwich/poulet/
  poisson/tunisien/italien/pharmacie/supermarche... — or null. Used for both dish and restaurant search.
"keyword": specific dish name (from image or text), or a restaurant name fragment, or null.
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
→ {"message":"Pizza au thon, bon choix — je te sors ce qui est dispo 🍕","intent":"search_food","health_goal":null,"category":"pizza","spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":"thon"}

[FR] "bonjour"
→ {"message":"Bonjour ! Je suis votre conseiller nutrition et découverte culinaire à Kairouan. Comment puis-je vous aider ? 😊","intent":"greeting","health_goal":null,"category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[AR] "أريد طعاماً صحياً لمريض السكري"
→ {"message":"لمريض السكري، أنصح بالأسماك المشوية والخضروات الغنية بالألياف لأنها تُحافظ على استقرار السكر. إليك أفضل الأطباق المتوفرة 🐟","intent":"search_food","health_goal":"diabetes","category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":"poisson"}

[TN] "chnoua el a7sen lel cholestérol ?"
→ {"message":"Lel cholestérol, el 7out el mchwi w el khodhra a7sen khyar: ynaqqso el cholestérol el khi w yzi3o el galb. Njiblek disponibles! 🐟","intent":"search_food","health_goal":"cholesterol","category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":"poisson"}

[FR] "quel temps fait-il à Kairouan ?"
→ {"message":"Je suis spécialisé en nutrition et découverte culinaire à Kairouan ! Puis-je vous aider à trouver un plat sain ? 🍽️","intent":"general","health_goal":null,"category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[FR] "où est ma commande ?"
→ {"message":"Je vérifie ça pour vous tout de suite ! 📦","intent":"track_order","health_goal":null,"category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[TN] "win wsalt commande mte3i?"
→ {"message":"Nchouf lek fi hin! 📦","intent":"track_order","health_goal":null,"category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[AR] "أين طلبيتي؟"
→ {"message":"أتحقق من ذلك فورًا! 📦","intent":"track_order","health_goal":null,"category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[EN] "hello"
→ {"message":"Hi! I'm your nutrition and food discovery guide in Kairouan. What are you in the mood for? 😊","intent":"greeting","health_goal":null,"category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[EN] "I train at the gym, what should I eat?"
→ {"message":"For muscle building, prioritise protein: grilled chicken, tuna, legumes. Here are the protein-rich dishes available 💪","intent":"search_food","health_goal":"sport","category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":"chicken"}

[EN] "can you give me the best restaurants in Kairouan"
→ {"message":"Here are the restaurants on Amana in Kairouan — reviews aren't all in yet, but you can open any menu 🍴","intent":"restaurant_search","health_goal":null,"category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[FR] "c'est quoi le meilleur resto à Kairouan ?"
→ {"message":"Voilà les restos dispo à Kairouan. Les avis ne sont pas encore tous en ligne, mais tu peux voir chaque menu 🍴","intent":"restaurant_search","health_goal":null,"category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[TN] "a7sen restaurant 9rib meni chnoua ?"
→ {"message":"Hani njiblek el restaurants el mftou7in tw. Chouf el menu w ekhtar elli y3jbek 🍴","intent":"restaurant_search","health_goal":null,"category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[EN] "any good pizza places?"
→ {"message":"Here are the spots doing pizza right now 🍕","intent":"restaurant_search","health_goal":null,"category":"pizza","spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[RECOVERY — assistant just returned dish cards, user replies] "those are food not restaurant"
→ {"message":"You're right, my bad — here are the actual restaurants 🍴","intent":"restaurant_search","health_goal":null,"category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[DISAMBIGUATION — FR] "pizza"
→ {"message":"Tu cherches une pizzeria, ou directement des pizzas à commander ? 🍕","intent":"general","health_goal":null,"category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[HONESTY — EN] "which restaurant is rated highest?"
→ {"message":"Ratings aren't live for most places yet, so I can't rank them — but here's everything open right now 🍴","intent":"restaurant_search","health_goal":null,"category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[EN] "what's the weather in Kairouan?"
→ {"message":"I'm focused on nutrition and food discovery in Kairouan! Can I help you find a healthy dish? 🍽️","intent":"general","health_goal":null,"category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[EN] "where's my order?"
→ {"message":"Let me check that for you right now! 📦","intent":"track_order","health_goal":null,"category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[LANGUAGE SWITCH — conversation started in Derja, user then writes] "english please"
→ {"message":"Of course! How can I help you find something to eat? 🍽️","intent":"greeting","health_goal":null,"category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[FR] "je veux payer ma facture STEG"
→ {"message":"Pas de souci ! Rendez-vous dans la section Facture de l'app : indiquez le montant, un livreur passe collecter l'argent et paie votre facture STEG pour vous 🧾","intent":"general","health_goal":null,"category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

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
