# CMANDILI_CONTEXT.md
> **Purpose:** AI session bootstrap. Read this file at the start of every session to understand the full project and continue immediately without reading every file.
> **Last updated:** 2026-06-28

---

## ⚠️ MIGRATION RULES — READ BEFORE WRITING ANY SQL

### PostgreSQL version
Supabase runs **PostgreSQL 15**. PG15 does **NOT** support `CREATE POLICY IF NOT EXISTS` (that's PG17+ syntax). Using it will cause the migration to fail at deploy time.

### Required pattern for all policy creation in migrations
Always guard `CREATE POLICY` statements with a `DO $$` block that checks `pg_policies` first:

```sql
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'schema_name'
      AND tablename  = 'table_name'
      AND policyname = 'policy_name'
  ) THEN
    EXECUTE $p$
      CREATE POLICY "policy_name"
      ON schema_name.table_name FOR <command>
      TO <role>
      USING/WITH CHECK (...)
    $p$;
  END IF;
END $$;
```

This applies to **all** policies — table RLS policies, storage policies, everything. Never write bare `CREATE POLICY IF NOT EXISTS`.

---

## ⚠️ ORDER STATUS RULES — READ BEFORE ADDING ANY NEW ORDER TYPE

### The driver filter
`availableOrdersProvider` in `cmandili_driver` shows ONLY orders where `status == 'ready' && driver_id == null`. Orders stuck at `'pending'` are **permanently invisible** to drivers.

### Which status to use at order creation

| Order type | Partner involved? | Create with status |
|---|---|---|
| `food` | Yes — restaurant accepts & cooks | `'pending'` ✅ |
| `supermarket` | Yes — supermarket picks & packs | `'pending'` ✅ |
| `courier` | No — goes straight to driver | `'ready'` ✅ |
| `facture` | No — goes straight to driver | `'ready'` ✅ |
| Any future direct-to-driver type | No | `'ready'` |

### Rule
> If the order has **no** `restaurant_id` or `supermarket_id`, it must be created with `status: 'ready'`. No partner = no one to transition it to ready.

---

## ⚠️ DISPATCH RULE — PERMANENT AND NON-NEGOTIABLE

**Orders MUST ALWAYS be dispatched through the automatic waterfall system.**

The automatic dispatch chain is:
1. `next_eligible_driver(order_id)` — finds nearest online, unblocked, unoccupied driver
2. `offer_order_to_driver(order_id, driver_id, window_secs)` — sets `assigned_driver_id`, triggers FCM push
3. `rotate_expired_offers()` (pg_cron every 5s) — advances offer to next driver after timeout
4. `pass_order_offer(order_id)` (driver app) — driver explicitly passes, same rotation

**The admin must NEVER manually assign a driver to an order. There is no admin dispatch feature and there must not ever be one.** If an order has no driver after the waterfall exhausts all options, the partner is notified to self-deliver (see section 4).

---

## 1. PROJECT OVERVIEW

| Field | Value |
|---|---|
| **App name** | Amena (formerly Cmandili) |
| **Type** | Food & package delivery platform |
| **Apps** | 3 Flutter apps + 1 Next.js admin |
| **Backend** | Supabase (PostgreSQL 15 + Auth + Storage + Edge Functions) |
| **Notifications** | Firebase FCM |
| **Maps** | Mapbox |

### The Apps

| Folder | Role | Git remote |
|---|---|---|
| `cmandili_mobile/` (root) | Customer app | `github.com/cherif-adam/cmandili_client` |
| `cmandili_driver/` | Driver app | same monorepo |
| `cmandili_partner/` | Restaurant/partner app | same monorepo |
| `admin/` | Admin dashboard (Next.js 16) | `github.com/cherif-adam/cmandili_admin` |

All three Flutter apps share the **same Supabase project** (same DB, Auth, Storage).

**Important git note:** `admin/` is a separate git repo inside the monorepo — push it separately to `cmandili_admin`. There is also a `cmandili_admin/` directory at the root which is a stale copy; always work in `admin/`.

---

## 2. DATABASE STRUCTURE

### `drivers` table
| Column | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key — NOT the same as auth.uid() |
| `user_id` | uuid | FK → auth.users.id (this equals auth.uid()) |
| `is_online` | bool | Driver availability toggle |
| `is_blocked` | bool | Admin can block; dispatch waterfall skips blocked drivers |
| `current_lat` | float | GPS latitude |
| `current_lng` | float | GPS longitude |
| `last_location_update` | timestamptz | Last GPS write timestamp |

> **Critical:** `drivers.id ≠ auth.uid()`. All RLS policies on this table must use `user_id = auth.uid()`, not `id = auth.uid()`.

### `partners` table
| Column | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key |
| `user_id` | uuid | FK → auth.users.id |
| `entity_id` | text | FK → restaurants.id or supermarkets.id cast to text |
| `partner_type` | text | `'restaurant'` or `'supermarket'` |
| `commission_rate` | numeric | Partner-specific commission override |
| `is_blocked` | bool | Admin can block partners |

> **Critical:** There is NO `partner_id` column on the `restaurants` table. The link is `partners.entity_id = restaurants.id::text`. Always join this way.

### `orders` table (key columns)
| Column | Notes |
|---|---|
| `status` | `pending → confirmed → ready → picked_up / on_the_way → delivered / cancelled` |
| `driver_id` | FK → drivers.id (null until driver accepts) |
| `assigned_driver_id` | Driver currently being offered the order (set by dispatch waterfall) |
| `assignment_expires_at` | When the current offer expires |
| `passed_driver_ids` | UUID[] — drivers who rejected or timed out |
| `self_delivery` | bool — partner chose to deliver themselves (no driver fee) |
| `no_driver_notified_at` | When we first notified the partner that all drivers were exhausted |
| `platform_fee` | Restaurant commission stamped at delivery |
| `driver_fee_cut` | Driver commission stamped at delivery (0 for self-delivered orders) |
| `order_type` | `food` / `courier` / `supermarket` / `billPayment` |

### `profiles` table
| Column | Notes |
|---|---|
| `id` | FK → auth.users.id |
| `full_name` | Display name |
| `is_admin` | bool — admin dashboard access |
| `is_blocked` | bool — blocked customers cannot place new orders (RLS enforced) |

### `global_settings` table
| `setting_key` | `setting_value` |
|---|---|
| `default_restaurant_commission_rate` | `0.10` (10%) |
| `default_driver_commission_rate` | `0.23` (23%) |

### `promo_codes` table (actual live schema — differs from original migration)
| Column | Notes |
|---|---|
| `type` | `'percentage'` or `'fixed_amount'` — **NOT** `discount_type` |
| `value` | discount amount — **NOT** `discount_value` |
| `expires_at` | expiry timestamp — **NOT** `valid_until` |
| `valid_from` | start date (added by fixup migration) |
| `max_uses_per_customer` | per-user cap (added by fixup migration) |
| `min_order_amount` | minimum order threshold |
| `used_count` | usage counter |

> **Critical:** The `promo_codes` table existed before the migration with different column names (`type`/`value`/`expires_at` instead of `discount_type`/`discount_value`/`valid_until`). All admin code and the `apply_promo_code` RPC use the actual live names. Never use `discount_type`, `discount_value`, or `valid_until` for this table.

---

## 3. ADMIN DASHBOARD (Next.js 16.2.9)

**Repo:** `admin/` → `github.com/cherif-adam/cmandili_admin`
**Stack:** Next.js 16 with Turbopack, TypeScript, Tailwind CSS, Supabase service_role client
**URL pattern:** `/dashboard/*` protected by middleware proxy

### Pages built

| Route | Purpose |
|---|---|
| `/login` | Email + password auth, sets `sb-token` cookie |
| `/reset-password` | Password reset flow |
| `/dashboard` | Overview stats (orders, revenue, commissions) |
| `/dashboard/livreurs` | Driver list — block/unblock |
| `/dashboard/restaurants` | Restaurant list — block/unblock |
| `/dashboard/commandes` | Order list with filters, stuck-order indicator, "Auto-livré" badge |
| `/dashboard/clients` | Customer list — block/unblock (enforced via RLS on orders table) |
| `/dashboard/finances` | Revenue and commission breakdown (delivered orders only) |
| `/dashboard/promos` | Promo code CRUD (create, toggle active, edit, delete) |
| `/dashboard/parametres` | Commission rate settings (stored in `global_settings`) |

### Key API routes

| Route | Method | Purpose |
|---|---|---|
| `/api/block` | POST | Block/unblock driver (`driver_id`), partner (`partner_id`), or customer (`customer_id`) |
| `/api/settings` | POST | Update commission rates in `global_settings` |
| `/api/promos` | POST/PATCH/DELETE | Promo code CRUD |
| `/api/logout` | POST | Clear auth cookie |

### Auth pattern
- Middleware at `proxy.ts` checks `sb-token` cookie, proxies to Next.js, blocks unauthenticated `/dashboard/*` routes
- Server components use `createSupabaseServerClient()` (anon key + cookie) for user identity
- All DB writes use `supabaseAdmin` (service_role key) for RLS bypass

### Commission rates
- Stored in `global_settings` table, configurable via `/dashboard/parametres`
- Restaurant: 10% of subtotal (`platform_fee`)
- Driver: 23% of delivery fee (`driver_fee_cut`) — 0 for self-delivered orders
- Settlement trigger `generate_settlements_on_delivery()` reads live rates at delivery time

### Stuck order indicator
- Orders with `status IN ('ready','confirmed') AND driver_id IS NULL AND created_at < now() - 5min` are highlighted red on the Commandes page
- This is **informational only** — no manual dispatch button, no admin action
- If too many stuck orders → need more drivers online in that area

---

## 4. SELF-DELIVERY FALLBACK

When the dispatch waterfall exhausts all available drivers (all nearby drivers rejected or timed out, `next_eligible_driver` returns NULL):

1. **`notify_partner_no_drivers(order_id)`** is called from both `rotate_expired_offers` and `pass_order_offer`
2. The function guards against double-notification using `no_driver_notified_at` column
3. It calls the `push-on-order-status` edge function with `{event: 'no_drivers', order_id}`
4. Edge function (Mode D) resolves the partner user_id and sends FCM push: "Aucun livreur disponible — voulez-vous livrer vous-même ?"

**Partner app flow:**
- Partner opens the order, sees a banner: "Aucun livreur disponible — Je livre cette commande"
- Partner taps the button → `confirmSelfDelivery(orderId)` → sets `self_delivery = true`, `status = 'on_the_way'`
- Partner uses the existing "Mark as delivered" flow (status → `delivered`)

**Commission for self-delivered orders:**
- `platform_fee` (restaurant commission): **unchanged** — partner still pays 10% on subtotal
- `driver_fee_cut`: **0** — no driver was involved
- Settlement trigger skips the driver settlement row (already guarded by `IF NEW.driver_id IS NOT NULL`)

**Admin view:** "Auto-livré" orange badge appears in the Commandes table status cell for `self_delivery = true` orders.

---

## 5. DISPATCH WATERFALL — DO NOT MODIFY

The automatic dispatch system is in:
- `supabase/migrations/20260510_assignment_and_distance.sql` — core functions
- `supabase/migrations/20260605_dispatch_on_confirmed.sql` — confirmed-order trigger
- `supabase/migrations/20260613_driver_is_blocked.sql` — blocked driver filter
- `supabase/migrations/20260628_self_delivery.sql` — self-delivery exhaustion hook

Key functions (treat as immutable unless fixing a bug):
- `next_eligible_driver(order_id, radius_km)` — finds nearest online/unblocked/unoccupied driver
- `offer_order_to_driver(order_id, driver_id, window_secs)` — assigns + FCM push
- `rotate_expired_offers()` — pg_cron every 5s, advances waterfall
- `pass_order_offer(order_id)` — driver explicit pass, same rotation
- `notify_partner_no_drivers(order_id)` — fires when waterfall is exhausted

---

## 6. MIGRATIONS APPLIED IN SESSION (2026-06-28)

Apply these to production in this order:

```
supabase db query --linked --file supabase/migrations/20260628_partners_is_blocked.sql
supabase db query --linked --file supabase/migrations/20260628_profiles_is_blocked.sql
supabase db query --linked --file supabase/migrations/20260628_dynamic_commission_rates.sql
supabase db query --linked --file supabase/migrations/20260628_promo_codes.sql
supabase db query --linked --file supabase/migrations/20260628_promo_codes_fixup.sql
supabase db query --linked --file supabase/migrations/20260628_admin_dispatch.sql        ← creates the RPC
supabase db query --linked --file supabase/migrations/20260628_drop_admin_dispatch.sql   ← immediately drops it
supabase db query --linked --file supabase/migrations/20260628_self_delivery.sql
```

Also redeploy the edge function:
```
supabase functions deploy push-on-order-status
```

---

## 7. COMPLETED FIXES (prior sessions)

### Fix 1 — MP3 notification sound
Moved `new_order.mp3` to correct Android raw resource path.

### Fix 2 — Java version
Updated `build.gradle.kts` to Java 17 in driver and partner apps.

### Fix 3 — GPS coordinates stuck at 0
- `setOnline()` now fetches GPS before update
- 8-second timeout with `getLastKnownPosition()` fallback
- Added missing `drivers` RLS policies (SELECT, UPDATE, INSERT on `user_id = auth.uid()`)
- Fixed `.eq('id', ...)` → `.eq('user_id', ...)` in `driver_online_provider.dart`

### Fix 4 — Push notifications (FCM)
- Added `CmandiliMessagingService.kt` + `Application.kt` to both driver and partner apps
- Edge function `push-on-order-status` sends FCM on order status changes

### Fix 5 — Windows Smart App Control blocking Flutter
Disabled Smart App Control; moved Flutter SDK to `C:\flutter`.

### Fix 6 — Flutter pub cache corrupted
`flutter clean && flutter pub cache repair && flutter pub get`

### Fix 7 — Orders table missing 4 dispatch columns
Added `assigned_driver_id`, `assignment_expires_at`, `passed_driver_ids`, `distance_km`.

### Fix 8 — Overflow UI bugs
Fixed `SliverAppBar` height in driver home screen; wrapped address text in `Expanded`.

### Fix 9 — Restaurant coordinates all 0
Set all restaurants to Sousse coordinates (35.6781, 10.0994).

### Fix 10 — Finance revenue overcounting
Changed filter from `.neq('status','cancelled')` to `.eq('status','delivered')`.

### Fix 11 — Restaurant blocking 3-bug stack
- Missing partner join (no FK from restaurants → partners; use `partners.entity_id`)
- Wrong payload (was sending `partner_id` which doesn't exist on restaurants)
- Wrong `is_blocked` source (was reading from wallet, now reads from `partners.is_blocked`)

### Fix 12 — Promo codes table schema mismatch
Live DB had `type`/`value`/`expires_at` columns; migration assumed `discount_type`/`discount_value`/`valid_until`. Fixed in `20260628_promo_codes_fixup.sql` and all admin code.

---

## 8. IMPORTANT FILE LOCATIONS

### Admin dashboard (`admin/`)
| File | Purpose |
|---|---|
| `proxy.ts` | Middleware — auth check, blocks unauthenticated dashboard access |
| `lib/supabase-admin.ts` | Service role client (bypasses RLS) |
| `lib/supabase-server.ts` | Anon client with cookie auth (for identity checks) |
| `components/Sidebar.tsx` | Navigation sidebar |
| `components/OrdersTable.tsx` | Orders table with stuck indicator + Auto-livré badge |
| `components/PromosClient.tsx` | Promo code CRUD client component |
| `app/api/block/route.ts` | Block/unblock drivers, partners, customers |
| `app/api/settings/route.ts` | Commission rate updates |
| `app/api/promos/route.ts` | Promo code CRUD API |

### Partner app (`cmandili_partner/lib/`)
| File | Purpose |
|---|---|
| `features/orders/data/models/order.dart` | Order model — includes `selfDelivery`, `noDriverNotifiedAt` |
| `features/orders/data/partner_order_repository.dart` | `confirmSelfDelivery()` method |
| `features/orders/presentation/order_detail_screen.dart` | Self-delivery banner widget |
| `core/push/push_service.dart` | FCM — handles `new_order` alarm; `no_drivers` shows as standard notification |

### Supabase
| File | Purpose |
|---|---|
| `supabase/functions/push-on-order-status/index.ts` | Edge function — handles Mode A (status), B (fanout), D (no_drivers) |
| `supabase/migrations/20260510_assignment_and_distance.sql` | Core dispatch waterfall |
| `supabase/migrations/20260628_self_delivery.sql` | Self-delivery exhaustion notification + settlement fix |
| `supabase/migrations/20260628_dynamic_commission_rates.sql` | Commission rates from global_settings |
| `supabase/migrations/20260628_promo_codes_fixup.sql` | Promo codes schema + apply_promo_code RPC |

---

## 9. DEVELOPMENT ENVIRONMENT

| Setting | Value |
|---|---|
| **OS** | Windows 11 Pro |
| **Flutter** | 3.41.1 — SDK at `C:\flutter\flutter\bin` |
| **Node.js** | For admin Next.js dashboard |
| **Supabase project** | cmandili (production — live data) |
| **Git user** | cherif-adam |
| **Monorepo root** | `C:\Users\user\Desktop\cmandili` |
| **Admin repo** | `C:\Users\user\Desktop\cmandili\admin\` → `github.com/cherif-adam/cmandili_admin` |

---

## 10. KEY ARCHITECTURE NOTES

- **Driver ID vs Auth UID:** `drivers.id ≠ auth.uid()`. Use `user_id = auth.uid()` for all driver RLS.
- **Partner–Restaurant link:** `partners.entity_id = restaurants.id::text`. No `partner_id` on restaurants.
- **Commission settlement trigger:** `generate_settlements_on_delivery()` fires on `status → delivered`. Self-delivery orders get `driver_fee_cut = 0`. Driver settlement row only inserted if `driver_id IS NOT NULL AND NOT self_delivery`.
- **Promo code column names:** `type`, `value`, `expires_at` (not discount_type/discount_value/valid_until).
- **Background GPS:** `BackgroundLocationService` runs as persistent foreground Android service while driver is online. Streams GPS to Supabase every 30 meters.
- **State management:** All Flutter apps use Riverpod (`flutter_riverpod`).
- **Order lifecycle:** `pending → confirmed → preparing → ready → on_the_way/picked_up → delivered`.
