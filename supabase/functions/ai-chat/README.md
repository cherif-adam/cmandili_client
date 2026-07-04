# ai-chat Edge Function

Server-side brain for the in-app **Cmandili Assistant** (the purple chat FAB).

## Why it exists

The mobile app previously called OpenRouter **directly from the client**, with
`OPENROUTER_API_KEY` bundled in its `.env` Flutter asset. `.env` ships inside the
released APK/IPA, so the secret key was extractable and the paid OpenRouter
account was open to abuse. This function moves that LLM call server-side — the
key now lives only as a Supabase secret. It mirrors the existing `ai-search`
function.

The app still runs the `food_items` / `grocery_items` queries itself (plain
RLS-guarded reads — no secret needed) and builds the product cards. Only the
OpenRouter call moved here.

## Request

`POST` JSON:

```jsonc
{
  "text": "n7eb nrégim",                 // user message (may be "")
  "history": [                            // Gemini-style chat history (optional)
    { "role": "user",  "parts": [{ "text": "aaslema" }] },
    { "role": "model", "parts": [{ "text": "Aaslema bik! ..." }] }
  ],
  "imageBase64": "<base64>",              // optional — enables vision
  "mimeType": "image/jpeg"                // optional
}
```

## Response

The structured intent the app's `_AiIntent` parses:

```jsonc
{
  "message": "Bravo 3lik! Lel régime ...",
  "intent": "search_food",
  "health_goal": "diet",
  "category": null,
  "spicy": null,
  "vegetarian": null,
  "max_price": null,
  "min_price": null,
  "delivery_time": null,
  "keyword": "poulet grillé"
}
```

Errors: `{ "error": string, "details"?: string }` with a 4xx/5xx status.

## Providers & secrets

OpenRouter is the **primary** provider; the function falls back to the
**direct Google Gemini API** (same `gemini-2.5-flash` model, so behaviour is
identical) whenever the OpenRouter call fails — bad key, no credits, outage.
At least ONE of the two keys must be set:

```bash
supabase secrets set OPENROUTER_API_KEY=sk-or-v1-...   # primary
supabase secrets set GEMINI_API_KEY=AIza...            # fallback (direct Gemini)
# optional — defaults to google/gemini-2.5-flash (vision-capable)
supabase secrets set OPENROUTER_CHAT_MODEL=google/gemini-2.5-flash
# optional — defaults to gemini-2.5-flash
supabase secrets set GEMINI_CHAT_MODEL=gemini-2.5-flash
```

### Setting the OpenRouter key without mangling it

A real OpenRouter key is `sk-or-v1-` + 64 hex chars = **73 characters**. The
dashboard key list only shows a TRUNCATED display (`sk-or-v1-…abcd`) — the full
key is visible **once, at creation**. If you lost it, create a new key at
<https://openrouter.ai/settings/keys>, then:

```bash
# 1. Prove the key is valid + funded BEFORE storing it (expect HTTP 200 with
#    label/usage/limit JSON; 401 "User not found" = key doesn't exist):
curl -s https://openrouter.ai/api/v1/key -H "Authorization: Bearer sk-or-v1-THEKEY"

# 2. Store it (no quotes needed; CLI strips nothing):
supabase secrets set OPENROUTER_API_KEY=sk-or-v1-THEKEY

# 3. Verify byte-for-byte what got stored — the digest shown by
#    `supabase secrets list` is the SHA-256 of the value:
printf '%s' 'sk-or-v1-THEKEY' | sha256sum   # must equal the listed digest
```

## Deploy

```bash
supabase functions deploy ai-chat
```

`verify_jwt = true` is pinned in `supabase/config.toml`, so the app's
`functions.invoke('ai-chat')` (which attaches the user's JWT / anon key) is
accepted while anonymous callers are rejected.
