# CMANDILI_CONTEXT.md
> **Purpose:** AI session bootstrap. Read this file at the start of every session to understand the full project and continue immediately without reading every file.
> **Last updated:** 2026-07-04 (post-audit fix session — see §7 status table)

---

## ⚠️ MIGRATION RULES — READ BEFORE WRITING ANY SQL

- Supabase runs **PostgreSQL 15**. `CREATE POLICY IF NOT EXISTS` is PG17+ syntax and FAILS — always guard `CREATE POLICY` in a `DO $$` block checking `pg_policies` (same for triggers via `pg_trigger`).
- **Never run blanket `supabase db push`**: migration filenames share 8-digit date versions (duplicate history keys → conflicts). Apply single files with `supabase db query --linked --file <f>` then `supabase migration repair --status applied <version>`. New migrations: use unique 14-digit versions (`YYYYMMDDHHMMSS_name.sql`).
- Verify RLS/trigger changes with a rolled-back harness: one `DO $$` block that impersonates roles (`set_config('request.jwt.claims', …, true)` + `SET LOCAL ROLE authenticated` … `RESET ROLE`) and ends with `RAISE EXCEPTION 'ALL_TESTS_PASSED :: …'` so nothing persists. Pick role-clean fixture users — several real users wear multiple hats (customer+driver, partner+admin).
- `supabase db query` rejects UTF-8 BOM — write SQL files BOM-less (PS5.1 `Set-Content -Encoding utf8` adds one; use `[IO.File]::WriteAllText` with `UTF8Encoding($false)`).

## ⚠️ ORDER STATUS RULES

**Canonical status values (the ONLY 8 the `orders_status_check` CHECK accepts — case matters):**

| Value | Set by | Meaning |
|---|---|---|
| `pending` | customer create (food/supermarket) | awaiting partner accept |
| `confirmed` | partner accept / ghost auto-confirm | accepted |
| `preparing` | partner | in preparation |
| `ready` | partner; courier/facture/ghost created/set here | dispatchable to drivers |
| `pickedUp` | driver | picked up — **never `picked_up`** |
| `onTheWay` | driver; partner self-delivery | in transit — **never `on_the_way`** |
| `delivered` | driver / partner self-delivery / customer confirm-receipt | fires settlements (cash) |
| `cancelled` | customer / partner reject / admin | cancelled |

Flutter `OrderStatus` enums serialize via `toString().split('.').last` — new literals must match this table byte-for-byte.

**Status at creation:** orders with NO `restaurant_id`/`supermarket_id` (courier, facture, any direct-to-driver type) MUST be created `'ready'` — the driver list only shows `status=='ready' && driver_id==null`, so `'pending'` partner-less orders are permanently invisible.

## ⚠️ DISPATCH RULE — PERMANENT

**Orders are ALWAYS dispatched through the automatic waterfall** (`next_eligible_driver` → `offer_order_to_driver` → `rotate_expired_offers` pg_cron / `pass_order_offer`). No manual admin assignment, ever. Waterfall exhausted → partner notified to self-deliver (§4).

---

## 1. PROJECT OVERVIEW

| Field | Value |
|---|---|
| **App name** | Amena (formerly Cmandili) |
| **Type** | Food & package delivery platform (Tunisia — Africa/Tunis = fixed UTC+1) |
| **Apps** | 3 Flutter apps + 1 Next.js admin |
| **Backend** | Supabase (PostgreSQL 15 + Auth + Storage + Edge Functions), Firebase FCM, Mapbox |

| Folder | Role | Git |
|---|---|---|
| `cmandili_mobile/` | Customer app (LIVE tree — root `lib/` is a stale copy) | own repo, submodule of `cmandili_client` |
| `cmandili_driver/` | Driver app | in `cmandili_client` monorepo (mirror repo `cmandili_driver` exists on GitHub) |
| `cmandili_partner/` | Partner app | in `cmandili_client` monorepo (mirror repo `cmandili_partner` exists on GitHub) |
| `admin/` | Admin dashboard (Next.js 16) — **canonical** | own repo → `cmandili_admin` |
| `cmandili_admin/` | STALE second checkout of the admin repo | do not edit — delete or fast-forward it someday |

All apps share one Supabase project (production, live data).

---

## 2. DATABASE STRUCTURE (key facts)

- **`drivers`**: `id` ≠ `auth.uid()`; `user_id` = auth.uid(). ALL driver RLS uses `user_id = auth.uid()`.
- **`partners`**: `user_id`, `entity_id` (**UUID in live DB — schema file says TEXT**; always compare `entity_id::text = x::text`), `partner_type` ('restaurant'|'supermarket'), `commission_rate`, `is_blocked`. NO `partner_id` on restaurants — the link is `partners.entity_id = restaurants.id`.
- **`orders`** (key cols): `status` (see canonical table), `driver_id` (null until accepted), `assigned_driver_id`+`assignment_expires_at`+`passed_driver_ids` (waterfall), `self_delivery`, `no_driver_notified_at`, `platform_fee`, `driver_fee_cut` (0 for self-delivery), `order_type` ∈ `food|courier|supermarket|facture`, cancellation cols (`cancellation_reason`, `cancelled_by` ∈ customer|admin|system, `cancelled_at`), `bill_*` (facture), `bill_receipt_url` (driver upload; `receipt_photo_url` does NOT exist live).
- **`restaurants`/`supermarkets`**: `is_open` (+ trigger-enforced, §7 F13), `opening_time`/`closing_time` TIME (single daily slot; pg_cron auto-close every 5 min when `auto_close_enabled`; auto-OPEN does not exist — partners open manually), `is_ghost_restaurant`, `categories` TEXT[] (restaurants only — see §10 category recipe).
- **`profiles`**: `is_admin` (dashboard gate + RLS admin scope), `is_blocked` (blocked customers can't INSERT orders).
- **`global_settings`**: `default_restaurant_commission_rate` 0.10, `default_driver_commission_rate` 0.23.
- **`promo_codes`** live columns: `type`/`value`/`expires_at` — NEVER `discount_type`/`discount_value`/`valid_until`.

---

## 3. ADMIN DASHBOARD (`admin/`, Next.js 16 + Turbopack + Tailwind)

- Auth: `proxy.ts` middleware guards `/dashboard/*` via `sb-token` cookie; login allowed only for `profiles.is_admin`. Reads/writes via `supabaseAdmin` (service_role — bypasses RLS AND the orders column guard).
- Pages: `/dashboard` (stats), `/livreurs`, `/restaurants` (block, ghost toggle, **Pâtisserie toggle**, schedule, relevé), `/commandes` (filters, stuck-order red highlight = `status IN ('ready','confirmed') AND driver_id IS NULL AND age>5min`, "Auto-livré" badge from `self_delivery`), `/clients`, `/finances`, `/promos`, `/parametres`.
- API routes (all service_role + `logAudit`): `/api/block`, `/api/settings`, `/api/promos`, `/api/restaurants/toggle-ghost`, `/api/restaurants/categories` (validates against `ALLOWED_CATEGORIES`), `/api/releve`, `/api/logout`.
- Status display maps (`OrdersTable.tsx` STATUS_COLORS/ALL_STATUSES, `commandes/page.tsx` STATUS_LABELS) use the 8 canonical camelCase keys — keep in sync with the status table.

---

## 4. SELF-DELIVERY FALLBACK

Waterfall exhausted → `notify_partner_no_drivers(order_id)` (guarded by `no_driver_notified_at`) → edge function Mode D → partner FCM. Partner taps "Je livre cette commande" → `confirmSelfDelivery()` sets `self_delivery=true, status='onTheWay'` (camelCase — was the Fix 17 bug) → existing "mark as delivered" flow. Commissions: `platform_fee` unchanged, `driver_fee_cut=0`, no driver settlement row. Admin shows "Auto-livré" badge.

---

## 5. DISPATCH WATERFALL — DO NOT MODIFY

`supabase/migrations/20260510_assignment_and_distance.sql` (core), `20260605_dispatch_on_confirmed.sql`, `20260613_driver_is_blocked.sql`, `20260628_self_delivery.sql`.
Functions (all SECURITY DEFINER owned by postgres → bypass RLS + column guard): `next_eligible_driver`, `offer_order_to_driver`, `rotate_expired_offers` (pg_cron 5s), `pass_order_offer`, `notify_partner_no_drivers`, `dispatch_driver_for_order`, ghost auto-confirm triggers, `generate_settlements_on_delivery`.

---

## 6. MIGRATION STATE

Everything through **`20260703140000_fix_settlements_entity_cast.sql` is applied to production** and recorded in migration history (via `db query --file` + `migration repair`). Edge functions deployed: `push-on-order-status` (Modes A/B/D), `ai-chat` (Gemini fallback; OPENROUTER_API_KEY secret is a dead truncated paste), `ai-search`, `notify-partner-order`. All edge functions pinned `verify_jwt=true`.

---

## 7. SESSION STATUS (2026-07-03/04 audit-fix session)

| # | Fix | Status | Files / migration |
|---|---|---|---|
| F13 | Ghost-order block: closed venues reject order INSERT (`VENUE_CLOSED` trigger) + client gating in detail/checkout screens | ✅ live + SQL-verified | `20260703_enforce_venue_open.sql`; mobile `restaurant_detail/supermarket_detail/checkout_screen.dart` |
| F15 | Closed-venue LIST cards: dim + "Fermé" pill + "Ouvre à HH:MM" (helper `nextOpeningLabel`, 7 unit tests) | ✅ code-verified (analyze clean) | mobile `restaurant_card.dart`, `supermarket_list_screen.dart`, `core/utils/venue_hours.dart`, models/repos/`favorites_provider` |
| — | Notification tap routing (deep-link on push tap, partner + driver) | ⚠️ **implemented, NOT device-tested** | partner `core/push/notification_navigation.dart` + `push_service.dart` + `MainActivity.kt`; driver `push_service.dart` + `MainActivity.kt` |
| F14 | orders UPDATE RLS: dropped 2 any-authenticated policies → 5 scoped ones | ✅ live + verified (14 rolled-back scenarios) | `20260703120000_tighten_orders_update_rls.sql` |
| F16 | Column-scope guard trigger on orders (per-role column allowlist) | ✅ live + verified (28 scenarios) | `20260703130000_guard_orders_column_scope.sql` |
| F17a | Self-delivery wrote invalid `'on_the_way'` status → CHECK violation | ✅ live + E2E-verified | partner `partner_order_repository.dart`; admin `OrdersTable.tsx` + `commandes/page.tsx` (dead snake_case display keys) |
| F17b | Settlements trigger `uuid=text` crash — **aborted every cash order's `delivered` transition** | ✅ live + E2E-verified (settlement rows + fee0 asserted) | `20260703140000_fix_settlements_entity_cast.sql` |
| F18 | Pâtisseries category (activated dormant `categories` TEXT[] system) | ✅ code+SQL verified — **needs manual venue tagging (§8)** | mobile `home_screen.dart`, `restaurant_card.dart`, `favorites_provider.dart`; admin `api/restaurants/categories/route.ts`, `RestaurantRow.tsx`, `restaurants/page.tsx` |
| — | Earlier-session pending work committed in this wrap-up: partner/driver auth + l10n updates, `ai-chat` edge function source, audit_logs + operating-hours migrations | committed, see git history | various |

Historical fixes 1–12 (MP3 sound, Java 17, GPS-0, FCM setup, pub cache, dispatch columns, overflow UI, Sousse coords, finance overcount, restaurant blocking, promo schema) — all shipped, details in git history.

---

## 8. OPEN ITEMS — MANUAL STEPS PENDING ON ADAM

- [ ] **Tag pastry venues**: admin → Restaurants → pink "Pâtisserie" button. Until then the mobile "Pâtisseries" chip shows an empty list (zero venues are tagged).
- [ ] **Device-test notification tap routing** (partner + driver): tap an order/offer push with app killed AND backgrounded → must open the right order screen. This was never verified on a device — treat as unconfirmed.
- [ ] **Release signing**: Android release builds still signed with DEBUG keys (audit P1-1) — create an upload keystore + real `release` signingConfig before any Play Store upload.
- [ ] **`cmandili_admin/` stale checkout**: decide — delete it or fast-forward to `admin/`'s head. It still contains the pre-F17 snake_case status display bugs.
- [ ] **OPENROUTER_API_KEY** Supabase secret is a dead truncated paste — replace it or remove it (ai-chat currently survives via GEMINI_API_KEY fallback).
- [ ] Consider a follow-up "open-first" sort in listings (deliberately out of F15 scope).

---

## 9. KNOWN REMAINING WORK (audit backlog — not started unless noted)

- **Logout bug**: profile-screen logout doesn't call `signOut()` (Google session + Supabase) and never clears/unregisters the FCM token → next account on same device can receive the previous user's pushes.
- **orderStreamProvider realtime leak** (mobile): channel not disposed on screen exit.
- **Hardcoded FR strings / error snackbars**: mixed FR/EN literals across mobile (incl. F15's "Fermé"/"Ouvre à…" pills and home category chips) — needs an l10n pass through `AppLocalizations` (fr/en/ar exist).
- **Reorder feature** (customer re-orders a past order) — not started.
- **Post-delivery rating flow** — not started.
- **Dead code cleanup**: `bill_payment_screen.dart`, `supermarket supabase_service.dart`, `confirmOrder()` in mobile order_repository (no callers).
- **Status transition matrix**: the column guard restricts WHICH columns, not which status VALUES — any in-scope role can set any of the 8 statuses. Business-rules layer if ever needed.
- Known residual: in-scope actors can still rewrite values within their ALLOWED columns (e.g. partner setting a nonsense status) — acceptable, documented.

---

## 10. KEY ARCHITECTURE NOTES (durable)

- **orders UPDATE RLS (F14)** — 5 policies: `orders_customer_update` (own rows), `orders_partner_update` (venue via entity chain), `orders_driver_update_own` (accepted orders), `orders_driver_claim` (atomic accept; must-be-a-driver EXISTS guard is load-bearing — permissive WITH CHECKs are OR'd across policies, an identity-free USING would enable order hijack), `orders_admin_update` (`is_admin`). New client `UPDATE orders` paths must fit one of these or they silently update 0 rows; server paths use SECURITY DEFINER/service_role.
- **Column guard (F16)**: trigger `aa_guard_orders_column_scope` BEFORE UPDATE, SECURITY INVOKER, deny-by-default OLD/NEW jsonb diff. Allowed: customer→`status,cancellation_reason,cancelled_by,cancelled_at`; partner→`status,self_delivery`; driver→`status,bill_receipt_url` (+`driver_id` claim NULL→own); admin unrestricted; bypass when `current_user NOT IN ('authenticated','anon')`. **The `aa_` prefix is load-bearing** — BEFORE triggers fire alphabetically and the guard must precede `order_cancelled_at`/`order_status_timestamps`; never add a BEFORE UPDATE trigger on orders sorting before `aa_`. `driver_fee_cut` is intentionally NOT client-writable (settlements trigger stamps it).
- **Category system recipe (F18)**: canonical values live in `ALLOWED_CATEGORIES` (`admin/app/api/restaurants/categories/route.ts`) and must stay byte-identical (accents!) with mobile `home_screen.dart _categories` — the chip filter is `toLowerCase()` equality. To add a category: add to both lists (+ optional icon case in `restaurant_card.dart`), tag venues in admin. Card badge = first category, only renders when non-empty. No schema change needed.
- **Closed-venue UX (F13+F15)**: DB trigger `enforce_venue_open` (BEFORE INSERT, `RAISE 'VENUE_CLOSED'`) is the source of truth; detail screens gate add-to-cart; checkout re-checks and maps the error; list cards dim + "Fermé" + `nextOpeningLabel()` (Africa/Tunis fixed UTC+1, returns null for missing/invalid hours). Closed venues stay visible and tappable — browsing allowed, ordering blocked.
- **Settlements**: `generate_settlements_on_delivery()` fires on cash orders' `status→delivered`; stamps `platform_fee`/`driver_fee_cut`; partner earning row; driver deduction row only if `driver_id IS NOT NULL AND NOT self_delivery`.
- **State management**: Riverpod everywhere. **Background GPS**: foreground Android service streams to Supabase every 30 m.

---

## 11. FILE LOCATIONS (quick jump)

| File | Purpose |
|---|---|
| `supabase/functions/push-on-order-status/index.ts` | Edge fn — Mode A (status push), B (fanout), D (no_drivers) |
| `supabase/migrations/20260510_assignment_and_distance.sql` | Dispatch waterfall core |
| `supabase/migrations/20260703_enforce_venue_open.sql` | Closed-venue INSERT block (F13) |
| `supabase/migrations/20260703120000_tighten_orders_update_rls.sql` | 5 scoped UPDATE policies (F14) |
| `supabase/migrations/20260703130000_guard_orders_column_scope.sql` | Column guard trigger (F16) |
| `supabase/migrations/20260703140000_fix_settlements_entity_cast.sql` | Settlements uuid=text fix (F17b) |
| `cmandili_mobile/lib/core/utils/venue_hours.dart` | `nextOpeningLabel()` helper (+ `test/venue_hours_test.dart`) |
| `cmandili_mobile/lib/features/restaurant/presentation/widgets/restaurant_card.dart` | Shared venue card: closed state + category badge |
| `cmandili_partner/lib/features/orders/data/partner_order_repository.dart` | `confirmSelfDelivery()` (canonical `onTheWay`) |
| `admin/app/api/restaurants/categories/route.ts` | Category writes — `ALLOWED_CATEGORIES` source of truth |
| `admin/components/OrdersTable.tsx` | Orders table: canonical status maps, stuck indicator, Auto-livré |
| `admin/components/RestaurantRow.tsx` | Ghost + Pâtisserie toggles, block, relevé |

---

## 12. DEVELOPMENT ENVIRONMENT

| Setting | Value |
|---|---|
| **OS / Flutter / Node** | Windows 11 Pro; Flutter 3.41.1 at `C:\flutter\flutter\bin`; Node for admin |
| **Supabase** | project `cmandili` (PRODUCTION, live data) — linked ref `hoqlxxtphskgxktqjpfu` |
| **Git user** | cherif-adam |
| **Analyze baselines** | cmandili_mobile: 4 info deprecations; cmandili_partner: 6 warnings + 166 infos (all pre-existing) |
