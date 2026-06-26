/**
 * push-on-order-status
 *
 * Supabase Edge Function — fans out FCM pushes for order lifecycle events.
 *
 * Two invocation modes:
 *
 *   1. Status change (default) — from the notify_fcm_on_order_status trigger.
 *      Body: { order_id, status }
 *      Routes the notification to:
 *        - the customer (orders.user_id)
 *        - the partner (owner of orders.restaurant_id / supermarket_id
 *          looked up via partners.entity_id)
 *        - the assigned driver, if any (orders.driver_id -> drivers.user_id)
 *
 *   2. Driver fan-out — from the notify_fcm_fanout_ready_order trigger.
 *      Body: { event: 'driver_fanout', order_id, status: 'ready' }
 *      Looks up the pickup lat/lng (from restaurants or supermarkets) and
 *      calls the `nearby_online_drivers` RPC to find online drivers within
 *      a radius, then pushes to each of them.
 *
 * Required environment variables (set with `supabase secrets set`):
 *   SUPABASE_URL               — automatically provided by Supabase
 *   SERVICE_ROLE_KEY           — service role JWT (bypasses RLS).
 *                                Cannot be named SUPABASE_*; that prefix is
 *                                reserved by Supabase.
 *   FCM_SERVICE_ACCOUNT_JSON   — Firebase service account JSON, base64-encoded
 *   DRIVER_FANOUT_RADIUS_KM    — optional, default 7
 *
 * Invoke URL: POST /functions/v1/push-on-order-status
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ── helpers ──────────────────────────────────────────────────────────────────

const CUSTOMER_COPY: Record<string, { title: string; body: string }> = {
  confirmed: { title: '✅ Order Confirmed', body: 'Order confirmed — we\'re preparing your food!' },
  preparing: { title: '👨‍🍳 Preparing', body: 'Your order is being prepared.' },
  ready:     { title: '📦 Ready for Pickup', body: 'Your order is ready and waiting for a driver.' },
  pickedUp:  { title: '🛵 Driver Picked Up', body: 'A driver has picked up your order.' },
  onTheWay:  { title: '🚀 On the Way', body: 'Your order is on the way!' },
  delivered: { title: '🎉 Delivered!', body: 'Your order has been delivered. Enjoy!' },
  cancelled: { title: '❌ Cancelled', body: 'Your order has been cancelled.' },
};

const PARTNER_COPY: Record<string, { title: string; body: string }> = {
  pending:   { title: '🔔 New Order', body: 'A new order is waiting for confirmation.' },
  confirmed: { title: '✅ Order Confirmed', body: 'You confirmed a new order.' },
  ready:     { title: '📦 Order Ready', body: 'Order marked ready — driver notified.' },
  pickedUp:  { title: '🛵 Picked Up', body: 'A driver picked up the order.' },
  delivered: { title: '🎉 Delivered', body: 'Order delivered.' },
  cancelled: { title: '❌ Cancelled', body: 'Order cancelled.' },
};

const DRIVER_COPY: Record<string, { title: string; body: string }> = {
  pickedUp:  { title: '🛵 Pickup Confirmed', body: 'Pickup confirmed — drive safe!' },
  onTheWay:  { title: '🚗 On the Way', body: 'Heading to the customer.' },
  delivered: { title: '✅ Delivered', body: 'Delivery complete. Payment collected if cash.' },
  cancelled: { title: '❌ Order Cancelled', body: 'This order was cancelled.' },
};

function copyFor(role: 'customer' | 'partner' | 'driver', status: string) {
  const src = role === 'customer' ? CUSTOMER_COPY
            : role === 'partner'  ? PARTNER_COPY
            : DRIVER_COPY;
  return src[status] ?? { title: 'Order Update', body: `Status: ${status}` };
}

// Firebase OAuth — sign JWT with RSA key from service account JSON.
async function getAccessToken(serviceAccountJson: string): Promise<string> {
  const sa = JSON.parse(serviceAccountJson);
  const now = Math.floor(Date.now() / 1000);

  const header  = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
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

  const binaryKey = Uint8Array.from(atob(pemKey), c => c.charCodeAt(0));
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

  const tokenResp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  const tokenData = await tokenResp.json();
  return tokenData.access_token as string;
}

/** Standard push: system renders the notification (title + body visible in shade). */
async function sendFcm(
  accessToken: string,
  projectId: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
  channelId = 'cmandili_orders',
) {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: {
        token,
        notification: { title, body },
        data,
        android: {
          priority: 'high',
          notification: {
            // Ensures Android routes to the correct channel even when the app
            // has never been opened (before Flutter creates channels at runtime).
            channel_id: channelId,
            sound: 'default',
          },
        },
        apns: {
          headers: { 'apns-priority': '10' },
          payload: {
            aps: {
              sound: 'default',
              'interruption-level': 'time-sensitive',
            },
          },
        },
      },
    }),
  });
}

/**
 * Data-only push: NO `notification` block, so FCM delivers it silently to
 * the app process and the Flutter firebaseMessagingBackgroundHandler fires.
 * The Flutter code is responsible for displaying the notification (with
 * custom sound / full-screen intent / alarm channel).
 *
 * Used for:
 *   - partner new_order  → alarm sound + FLAG_INSISTENT
 *   - driver offer       → alarm sound + fullScreenIntent (call-style)
 */
async function sendDataOnlyFcm(
  accessToken: string,
  projectId: string,
  token: string,
  data: Record<string, string>,
) {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: {
        token,
        data,          // ← data ONLY, no notification block
        android: {
          priority: 'high',
          // Wake the device CPU even when Doze is active.
          direct_boot_ok: true,
        },
        apns: {
          headers: { 'apns-priority': '10' },
          payload: {
            aps: {
              'content-available': 1,  // silent background wake on iOS
            },
          },
        },
      },
    }),
  });
  if (!resp.ok) {
    console.error(`sendDataOnlyFcm error for token ${token.slice(-8)}:`, await resp.text());
  }
}

async function tokensForUser(supabase: SupabaseClient, userId: string): Promise<string[]> {
  const { data } = await supabase
    .from('device_tokens')
    .select('token')
    .eq('user_id', userId);
  return (data ?? []).map((r: { token: string }) => r.token);
}

/** Fan-out a standard (system-rendered) notification to multiple users. */
async function pushToUsers(
  supabase: SupabaseClient,
  accessToken: string,
  projectId: string,
  userIds: string[],
  title: string,
  body: string,
  data: Record<string, string>,
  channelId = 'cmandili_orders',
): Promise<number> {
  const all = await Promise.all(userIds.map(id => tokensForUser(supabase, id)));
  const tokens = Array.from(new Set(all.flat()));
  if (tokens.length === 0) return 0;
  await Promise.allSettled(
    tokens.map(t => sendFcm(accessToken, projectId, t, title, body, data, channelId)),
  );
  return tokens.length;
}

/**
 * Fan-out a DATA-ONLY push to multiple users.
 * Used for alarm-style events (partner new_order, driver offer) so the
 * Flutter background handler takes over display with custom sounds.
 */
async function pushDataOnlyToUsers(
  supabase: SupabaseClient,
  accessToken: string,
  projectId: string,
  userIds: string[],
  data: Record<string, string>,
): Promise<number> {
  const all = await Promise.all(userIds.map(id => tokensForUser(supabase, id)));
  const tokens = Array.from(new Set(all.flat()));
  if (tokens.length === 0) return 0;
  await Promise.allSettled(
    tokens.map(t => sendDataOnlyFcm(accessToken, projectId, t, data)),
  );
  return tokens.length;
}

// ── handler ──────────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  // SERVICE_ROLE_KEY (NOT SUPABASE_SERVICE_KEY): Supabase reserves the
  // SUPABASE_* prefix and rejects setting secrets with that prefix.
  const serviceKey  = Deno.env.get('SERVICE_ROLE_KEY')!;
  const saJsonB64   = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')!;
  const fanoutRadius = Number(Deno.env.get('DRIVER_FANOUT_RADIUS_KM') ?? '7');

  if (!supabaseUrl || !serviceKey || !saJsonB64) {
    return new Response('Missing env vars', { status: 500 });
  }

  const { event, order_id, status } = await req.json();
  if (!order_id || !status) {
    return new Response('Missing order_id or status', { status: 400 });
  }

  const supabase = createClient(supabaseUrl, serviceKey);
  const saJson   = atob(saJsonB64);
  const sa       = JSON.parse(saJson);
  const projectId = sa.project_id as string;
  const accessToken = await getAccessToken(saJson);

  const data = { order_id, status, event: event ?? 'status' };

  // ── Mode C: offer an order to a single driver (10s window) ─────────────────
  // Triggered by the offer_order_to_driver RPC. The order's
  // assigned_driver_id has already been updated; we just need to push.
  if (event === 'offer_to_driver') {
    const { driver_id } = await (async () => {
      // The body was already parsed at the top of serve(); re-read driver_id
      // from there. We can't reuse the destructured `event/order_id/status`
      // bag because driver_id wasn't pulled out — so look it up via DB.
      const { data: row } = await supabase
        .from('orders')
        .select('assigned_driver_id')
        .eq('id', order_id)
        .maybeSingle();
      return { driver_id: row?.assigned_driver_id as string | null };
    })();

    if (!driver_id) {
      return new Response('No assigned driver', { status: 200 });
    }

    const { data: drow } = await supabase
      .from('drivers')
      .select('user_id')
      .eq('id', driver_id)
      .maybeSingle();
    const driverUserId = drow?.user_id as string | undefined;
    if (!driverUserId) {
      return new Response('Driver has no auth user', { status: 200 });
    }

    // Data-only so the Flutter background handler shows the alarm notification
    // (custom sound + fullScreenIntent). A standard push with a `notification`
    // block would be rendered by the system as a plain banner, bypassing our
    // alarm channel entirely.
    const sent = await pushDataOnlyToUsers(
      supabase, accessToken, projectId, [driverUserId],
      {
        event: 'offer_to_driver',
        order_id,
        status,
        urgent: '1',
        title: '🔔 Nouvelle livraison',
        body: 'Acceptez dans les 15 secondes.',
      },
    );
    return new Response(JSON.stringify({ mode: 'offer', sent }), {
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // ── Mode B: fan out to nearby online drivers (legacy / fallback) ───────────
  if (event === 'driver_fanout') {
    // Look up the order to get pickup coords via its restaurant/supermarket.
    const { data: order } = await supabase
      .from('orders')
      .select('restaurant_id, supermarket_id, pickup_address')
      .eq('id', order_id)
      .maybeSingle();

    if (!order) return new Response('Order not found', { status: 404 });

    let lat: number | null = null;
    let lng: number | null = null;

    if (order.restaurant_id) {
      const { data: r } = await supabase
        .from('restaurants')
        .select('latitude, longitude')
        .eq('id', order.restaurant_id)
        .maybeSingle();
      lat = r?.latitude ?? null;
      lng = r?.longitude ?? null;
    } else if (order.supermarket_id) {
      const { data: s } = await supabase
        .from('supermarkets')
        .select('latitude, longitude')
        .eq('id', order.supermarket_id)
        .maybeSingle();
      lat = s?.latitude ?? null;
      lng = s?.longitude ?? null;
    } else if (order.pickup_address) {
      // Courier orders: pickup_address is JSONB with {lat, lng}
      const p = order.pickup_address as { lat?: number; lng?: number };
      lat = p?.lat ?? null;
      lng = p?.lng ?? null;
    }

    if (lat === null || lng === null || (lat === 0 && lng === 0)) {
      return new Response('No pickup coords on order', { status: 200 });
    }

    const { data: drivers } = await supabase.rpc('nearby_online_drivers', {
      p_lat: lat,
      p_lng: lng,
      p_radius_km: fanoutRadius,
    });

    if (!drivers || drivers.length === 0) {
      return new Response('No nearby drivers', { status: 200 });
    }

    const userIds = (drivers as { user_id: string }[]).map(d => d.user_id);
    
    // Waterfall Dispatch: Offer to one driver at a time, wait 15 seconds
    const runWaterfall = async () => {
      for (let i = 0; i < userIds.length; i++) {
        const userId = userIds[i];
        
        // Check if the order is still available (no driver assigned, and status is preparing or ready)
        const { data: currentOrder } = await supabase
          .from('orders')
          .select('driver_id, status')
          .eq('id', order_id)
          .maybeSingle();
          
        if (!currentOrder || currentOrder.driver_id || (currentOrder.status !== 'preparing' && currentOrder.status !== 'ready')) {
          console.log(`Waterfall stopped for order ${order_id}: driver assigned or status changed.`);
          break;
        }

        console.log(`Offering order ${order_id} to driver ${userId} (Attempt ${i + 1}/${userIds.length})`);
        
        await pushDataOnlyToUsers(
          supabase, accessToken, projectId, [userId],
          {
            event: 'offer_to_driver',
            order_id,
            status,
            urgent: '1',
            title: '🔔 Nouvelle livraison',
            body: 'Une nouvelle commande est prête. Vous avez 15 secondes pour accepter.',
          },
        );
        
        // Wait 15 seconds before offering to the next driver
        await new Promise(resolve => setTimeout(resolve, 15000));
      }
    };

    // Start waterfall in background
    runWaterfall().catch(console.error);

    return new Response(JSON.stringify({ mode: 'waterfall_started', drivers_count: userIds.length }), {
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // ── Mode A: status change → customer + partner + assigned driver ───────────

  const { data: order } = await supabase
    .from('orders')
    .select('user_id, restaurant_id, supermarket_id, driver_id')
    .eq('id', order_id)
    .maybeSingle();

  if (!order) return new Response('Order not found', { status: 404 });

  // ── Resolve venue is_open flag ─────────────────────────────────────────────
  // The partner alarm must only fire when their venue is open. This guards
  // against edge-cases where an order slips through while the venue is closed
  // (e.g. the partner closed it mid-operation).
  let venueIsOpen = true; // courier orders (no restaurant/supermarket) are always OK
  if (order.restaurant_id) {
    const { data: venue } = await supabase
      .from('restaurants')
      .select('is_open')
      .eq('id', order.restaurant_id)
      .maybeSingle();
    venueIsOpen = venue?.is_open ?? true;
  } else if (order.supermarket_id) {
    const { data: venue } = await supabase
      .from('supermarkets')
      .select('is_open')
      .eq('id', order.supermarket_id)
      .maybeSingle();
    venueIsOpen = venue?.is_open ?? true;
  }

  // ── Resolve partner user_id ────────────────────────────────────────────────
  let partnerUserId: string | null = null;
  if (order.restaurant_id) {
    const { data: p } = await supabase
      .from('partners')
      .select('user_id')
      .eq('partner_type', 'restaurant')
      .eq('entity_id', order.restaurant_id)
      .maybeSingle();
    partnerUserId = p?.user_id ?? null;
  } else if (order.supermarket_id) {
    const { data: p } = await supabase
      .from('partners')
      .select('user_id')
      .eq('partner_type', 'supermarket')
      .eq('entity_id', order.supermarket_id)
      .maybeSingle();
    partnerUserId = p?.user_id ?? null;
  }

  // ── Resolve existing assigned driver user_id ───────────────────────────────
  let driverUserId: string | null = null;
  if (order.driver_id) {
    const { data: d } = await supabase
      .from('drivers')
      .select('user_id')
      .eq('id', order.driver_id)
      .maybeSingle();
    driverUserId = d?.user_id ?? null;
  }

  const results: Record<string, number | string> = {};

  // ── Customer ───────────────────────────────────────────────────────────────
  if (order.user_id) {
    const c = copyFor('customer', status);
    results.customer = await pushToUsers(
      supabase, accessToken, projectId, [order.user_id], c.title, c.body, data,
    );
  }

  // ── Partner ────────────────────────────────────────────────────────────────
  if (partnerUserId) {
    if (status === 'pending' && venueIsOpen) {
      // INSERT trigger fires with 'pending' — this is the new-order alarm.
      // Data-only so the Flutter background handler (and the native Kotlin
      // CmandiliMessagingService) take over display with alarm sound + FLAG_INSISTENT.
      // A notification-block message would be rendered by the OS, bypassing both.
      // is_open guard: never alarm a closed venue.
      const c = copyFor('partner', 'pending');
      results.partner = await pushDataOnlyToUsers(
        supabase, accessToken, projectId, [partnerUserId],
        {
          type: 'new_order',
          order_id,
          status,
          title: c.title,
          body:  c.body,
        },
      );
    } else if (status === 'pending' && !venueIsOpen) {
      console.log(`Partner alarm skipped — venue is closed (order ${order_id})`);
    } else if (status !== 'pending') {
      // All other status changes: standard banner to partner (they are already
      // aware of the order; no alarm needed).
      const c = copyFor('partner', status);
      if (c.title) {
        results.partner = await pushToUsers(
          supabase, accessToken, projectId, [partnerUserId], c.title, c.body, data,
          'cmandili_orders',
        );
      }
    }
  }

  // ── Auto-dispatch: find nearest available driver when order is confirmed ───
  // Triggered when the partner taps "Accepter" (status: pending → confirmed).
  // dispatch_driver_for_order atomically assigns the driver and returns their
  // IDs so we can send the alarm FCM in-process (no second HTTP round-trip).
  if (status === 'confirmed') {
    const { data: dispatch } = await supabase
      .rpc('dispatch_driver_for_order', {
        p_order_id:    order_id,
        p_radius_km:   fanoutRadius,
        p_window_secs: 30,
      });

    if (dispatch && dispatch.length > 0) {
      const { driver_id, user_id: dispatchedUserId, distance_km } = dispatch[0] as {
        driver_id: string;
        user_id:   string;
        distance_km: number;
      };

      await pushDataOnlyToUsers(
        supabase, accessToken, projectId, [dispatchedUserId],
        {
          event:       'offer_to_driver',
          order_id,
          status:      'confirmed',
          urgent:      '1',
          distance_km: distance_km?.toFixed(1) ?? '',
          title:       '🔔 Nouvelle livraison',
          body:        'Acceptez dans les 30 secondes.',
        },
      );

      results.driver_dispatched = driver_id;
      console.log(`Dispatched driver ${driver_id} (${distance_km?.toFixed(1)} km) for order ${order_id}`);
    } else {
      console.log(`No available driver for order ${order_id} at confirmed — cron will retry`);
    }
  }

  // ── Existing assigned driver: status-update banner ─────────────────────────
  // Only for statuses after assignment (pickedUp, onTheWay, delivered, cancelled).
  // Skip 'confirmed' — we just dispatched a new driver above; the assigned driver
  // hasn't accepted yet and doesn't need a status-update banner.
  if (driverUserId && status !== 'confirmed') {
    const c = copyFor('driver', status);
    if (c.title) {
      results.driver = await pushToUsers(
        supabase, accessToken, projectId, [driverUserId], c.title, c.body, data,
      );
    }
  }

  return new Response(JSON.stringify({ mode: 'status', ...results }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
