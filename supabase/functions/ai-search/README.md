# ai-search Edge Function

Powers the **AI Search** screen in the app: conversational text search (Darija /
French / Arabic) and visual search (photo of a dish).

## Why this exists

The previous version called Google's Gemini `v1` endpoint directly, which began
returning `404 — models/gemini-1.5-flash is not found for API version v1`.
This version routes **all** AI calls through **OpenRouter** instead, so the
model can be swapped without touching code (just change the `OPENROUTER_MODEL`
secret).

## One-time setup

From the project root (`cmandili_client-main/`):

```sh
# 1. Log in and link the project (only once per machine)
supabase login
supabase link --project-ref hoqlxxtphskgxktqjpfu

# 2. Set the secrets the function needs.
#    SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically by
#    the platform — do NOT set those yourself.
supabase secrets set OPENROUTER_API_KEY=<your-openrouter-api-key>
supabase secrets set OPENROUTER_MODEL=google/gemini-2.0-flash-001
```

## Deploy

```sh
supabase functions deploy ai-search
```

That's it — the app already calls `supabase.functions.invoke('ai-search', ...)`,
so no app rebuild is needed for the fix to take effect (only a rebuild if you
changed Dart code).

## Test from the terminal

```sh
# Text mode
curl -i -X POST \
  https://hoqlxxtphskgxktqjpfu.supabase.co/functions/v1/ai-search \
  -H "Authorization: Bearer <SUPABASE_ANON_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"mode":"text","query":"3andi 20d w n7eb pizza"}'
```

Expected: `{ "intent": {...}, "results": [ ... ] }`.

## Request / response contract

| mode    | request body                                  | success response                                  |
| ------- | ---------------------------------------------- | -------------------------------------------------- |
| `text`  | `{ mode, query }`                              | `{ intent: {...}, results: [food_item + restaurants] }` |
| `image` | `{ mode, imageBase64, mimeType }`              | `{ dish_name, confidence, results: [...] }`        |
| error   | —                                              | `{ error: string, details?: string }` with 4xx/5xx |

`results[]` items match `lib/features/ai_search/data/models/search_result.dart`
(`AiSearchFoodResult.fromJson`): each row carries the `food_items` columns plus
an embedded `restaurants: { ... }` object from the `!inner` join.

## Swapping the model

Any OpenRouter model that supports **vision** + **JSON output** works for both
modes. To change it:

```sh
supabase secrets set OPENROUTER_MODEL=openai/gpt-4o-mini
supabase functions deploy ai-search   # redeploy to pick up the new secret
```

## Notes

- The function uses the **service-role key** server-side, so it can read
  `food_items` / `restaurants` even with RLS enabled. The key never leaves
  Supabase.
- The model does the fine ranking ("AI picks best matches"). If the ranking
  call fails, the function falls back to cheapest-first so the user still gets
  a usable list.
