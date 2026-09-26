/**
 * push-happy-hour
 *
 * Supabase Edge Function: tells customers a happy hour just started.
 *
 * Called by the notify_happy_hour_started trigger on vendor_items the moment
 * an item's discount_price goes from NULL to a value (a partner tapped
 * "Activer Happy Hour"). Body: { item_id }.
 *
 * Sends ONE message per language to the FCM topics happy_hour_fr /
 * happy_hour_ar / happy_hour_en. Each client app is subscribed to exactly one
 * of them, matching its language (PushService.setPromoLanguage), so every
 * customer gets the offer once, in their language, with no per-user fan-out.
 *
 * The trigger calls this with the app's public key, so anyone holding that
 * key could call it too. It therefore trusts nothing in the request except
 * the item id:
 *   - the deal is re-read from the database and must really be live;
 *   - happy_hour_notified_at is claimed atomically, so each item can push at
 *     most once per hour however often this is called.
 *
 * Environment (same secrets as push-on-order-status):
 *   SUPABASE_URL, SERVICE_ROLE_KEY, FCM_SERVICE_ACCOUNT_JSON (base64)
 *
 * Invoke URL: POST /functions/v1/push-happy-hour
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

/** Must match kPlatformMarkupRate in the client app: customers see and pay
 *  base price + 10%, so the notification quotes the same numbers. */
const PLATFORM_MARKUP = 0.10;

/** One push per item per hour at most (stop/restart, repeated calls). */
const RENOTIFY_AFTER_MS = 60 * 60 * 1000;

// Firebase OAuth — sign a JWT with the service account's RSA key.
async function getAccessToken(sa: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = btoa(JSON.stringify({
    iss: sa.client_email,
    sub: sa.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  }));
  const unsigned = `${header}.${payload}`;
  const pemKey = sa.private_key
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\n/g, '');
  const binaryKey = Uint8Array.from(atob(pemKey), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryKey,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${btoa(String.fromCharCode(...new Uint8Array(signature)))}`;
  const resp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  const data = await resp.json();
  return data.access_token as string;
}

type Copy = { title: string; body: string };

/** "7.70" — two decimals, as the client shows prices. */
const money = (n: number) => n.toFixed(2);

/** "22:30" in Tunisia time, whatever timezone the function runs in. */
function tunisTime(iso: string): string {
  return new Date(iso).toLocaleTimeString('fr-FR', {
    timeZone: 'Africa/Tunis',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function buildCopy(
  lang: 'fr' | 'ar' | 'en',
  shop: string,
  item: string,
  deal: string,
  old: string,
  quantity: number | null,
  endsAt: string | null,
): Copy {
  const until = endsAt ? tunisTime(endsAt) : null;
  switch (lang) {
    case 'fr':
      return {
        title: `🔥 Happy Hour chez ${shop}`,
        body: `${item} à ${deal} DT au lieu de ${old} DT, dès maintenant !` +
          (quantity ? ` Seulement ${quantity} disponibles.` : '') +
          (until ? ` Jusqu'à ${until}.` : ''),
      };
    case 'ar':
      return {
        title: `🔥 ساعة سعيدة في ${shop}`,
        body: `${item} بـ ${deal} د.ت بدلاً من ${old} د.ت، ابتداءً من الآن!` +
          (quantity ? ` ${quantity} فقط متوفرة.` : '') +
          (until ? ` حتى ${until}.` : ''),
      };
    default:
      return {
        title: `🔥 Happy Hour at ${shop}`,
        body: `${item} for ${deal} DT instead of ${old} DT, starting now!` +
          (quantity ? ` Only ${quantity} available.` : '') +
          (until ? ` Until ${until}.` : ''),
      };
  }
}

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  let itemId: string | undefined;
  try {
    itemId = (await req.json())?.item_id;
  } catch (_) { /* fall through */ }
  if (!itemId || !/^[0-9a-f-]{36}$/i.test(itemId)) {
    return new Response(JSON.stringify({ error: 'item_id required' }), { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SERVICE_ROLE_KEY')!,
  );

  // 1. Re-read the deal: never trust the caller about what is on offer.
  const { data: item, error: itemErr } = await supabase
    .from('vendor_items')
    .select('id, name, price, discount_price, discount_end_time, discount_quantity, is_available, vendor_id')
    .eq('id', itemId)
    .maybeSingle();
  if (itemErr || !item) {
    return new Response(JSON.stringify({ skipped: 'item not found' }), { status: 200 });
  }
  const price = Number(item.price);
  const discount = item.discount_price == null ? null : Number(item.discount_price);
  const live = item.is_available !== false &&
    (item.discount_end_time == null || new Date(item.discount_end_time) > new Date());
  if (discount == null || discount >= price || !live) {
    return new Response(JSON.stringify({ skipped: 'no live deal' }), { status: 200 });
  }

  // 2. Claim the notification slot atomically: only one caller per hour wins.
  const cutoff = new Date(Date.now() - RENOTIFY_AFTER_MS).toISOString();
  const { data: claimed } = await supabase
    .from('vendor_items')
    .update({ happy_hour_notified_at: new Date().toISOString() })
    .eq('id', itemId)
    .or(`happy_hour_notified_at.is.null,happy_hour_notified_at.lt.${cutoff}`)
    .select('id');
  if (!claimed || claimed.length === 0) {
    return new Response(JSON.stringify({ skipped: 'already notified recently' }), { status: 200 });
  }

  // 3. Shop name + which Happy Hour tab lists it (0 food, 1 grocery, 2 other).
  const { data: vendor } = await supabase
    .from('vendors')
    .select('name, category')
    .eq('id', item.vendor_id)
    .maybeSingle();
  const shop = vendor?.name ?? 'Cmandili';
  const tab = vendor?.category === 'food' ? '0' : vendor?.category === 'grocery' ? '1' : '2';

  const deal = money(discount * (1 + PLATFORM_MARKUP));
  const old = money(price * (1 + PLATFORM_MARKUP));
  const quantity = item.discount_quantity == null ? null : Number(item.discount_quantity);

  // 4. One message per language topic.
  const sa = JSON.parse(atob(Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')!));
  const accessToken = await getAccessToken(sa);
  const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

  const results: Record<string, number> = {};
  for (const lang of ['fr', 'ar', 'en'] as const) {
    const copy = buildCopy(lang, shop, item.name, deal, old, quantity, item.discount_end_time);
    const resp = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          topic: `happy_hour_${lang}`,
          notification: copy,
          // Read by PushService to open the Happy Hour screen on the right tab.
          data: { type: 'happy_hour', item_id: item.id, tab },
          android: {
            priority: 'high',
            notification: { channel_id: 'cmandili_promos_v1', sound: 'default' },
          },
          apns: { payload: { aps: { sound: 'default' } } },
        },
      }),
    });
    results[lang] = resp.status;
  }

  return new Response(JSON.stringify({ sent: results }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
});
