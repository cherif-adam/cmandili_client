# CMANDILI_CONTEXT.md
> **Purpose:** AI session bootstrap. Read this file at the start of every session to understand the full project and continue immediately without reading every file.
> **Last updated:** 2026-07-07 (loyalty UI/copy fixes + rewards screen + cancelled-terminal hardening session — see §7 status table, F21/F22)

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
- **`orders`** (key cols): `status` (see canonical table), `driver_id` (`drivers.id`, null until accepted — **not** `auth.users.id`), `assigned_driver_id`+`assignment_expires_at`+`passed_driver_ids` (waterfall), `self_delivery`, `no_driver_notified_at`, `platform_fee`, `driver_fee_cut` (0 for self-delivery), `order_type` ∈ `food|courier|supermarket|facture`, cancellation cols (`cancellation_reason`, `cancelled_by` ∈ customer|admin|system, `cancelled_at`), `bill_*` (facture), `bill_receipt_url` (driver upload; `receipt_photo_url` does NOT exist live), `loyalty_milestone_type`/`loyalty_discount_amount` (F20, trigger-only).
- **`loyalty_customer_progress`** (customer_id PK, delivered_count) and **`loyalty_driver_payouts`** (order_id UNIQUE, driver_id→`drivers(id)`, amount_owed, status pending/settled) — F20, see §10.
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

Everything through **`20260706171000_loyalty_program.sql` is applied to production** and recorded in migration history (via `db query --file` + `migration repair`). Edge functions deployed: `push-on-order-status` (Modes A/B/D), `ai-chat` (Gemini fallback; OPENROUTER_API_KEY secret is a dead truncated paste), `ai-search`, `notify-partner-order`. All edge functions pinned `verify_jwt=true`.

⚠️ **`20260707180000_guard_cancelled_terminal.sql` (F22) exists in the repo but is NOT yet applied to production and NOT in migration history.** Adam approved the content 2026-07-07; it still needs `supabase db query --linked --file <f>` + `migration repair --status applied <version>` (per the rule above — never blanket `db push`). Do not assume it's live until §7/§8 say so.

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
| F19 | Driver settlement P0: `settlements.user_id` got `drivers.id` instead of the driver's `auth.uid()` (FK type mismatch) — **aborted every non-self-delivery cash order's `delivered` transition**, `settlements` had 0 rows ever, `driver_fee_cut` stuck at 0 | ✅ live + rolled-back-verified on 2 real affected orders | `20260706170000_fix_driver_settlement_user_id.sql` |
| F20 | Loyalty program: unified lifetime delivered-count (food/courier/facture) → 5th order =50% off delivery, 10th=free; driver settlement untouched; admin payout ledger + net-per-driver view; mobile progress badge | ✅ live + 6-scenario rolled-back harness (see §10) | `20260706171000_loyalty_program.sql`; admin `dashboard/fidelite/`, `api/loyalty/settle/`, `LoyaltyPayoutRow.tsx`; mobile `orders/` (model, repo, provider, history + tracking screens) |
| — | Earlier-session pending work committed in this wrap-up: partner/driver auth + l10n updates, `ai-chat` edge function source, audit_logs + operating-hours migrations | committed, see git history | various |
| F21 | Loyalty UI follow-up: fixed wrong "bon de 5 DT" copy → real dynamic half/free-delivery wording (fr/en/ar), milestone-aware sheet text (progressing vs. landing-on-5th/10th celebration lines), 10th-order cycle-reset animation (card empties after a ~1.4s celebratory hold), new "Mes récompenses" rewards screen (milestone cards achieved/current/locked + "Comment ça marche"). Cycle position derived client-side via `count % 10` — backend counter intentionally still never resets (see §10) | ✅ `flutter analyze` clean; ⚠️ **NOT visually/device-tested** (no emulator on this machine — see §8) | mobile `lib/features/loyalty/` (new: `loyalty_rewards_screen.dart`, `widgets/loyalty_progress_section.dart`; changed: `loyalty_card_sheet.dart`, `data/loyalty_eligibility.dart`); `lib/core/theme/app_colors.dart`; `lib/l10n/app_{fr,en,ar}.arb` |
| F22 | Security hardening: `cancelled` made a terminal order status for `authenticated`/`anon` (blocks ALL transitions out of cancelled, not just →delivered) — closes a gap where nothing stopped a cancelled order being flipped back to delivered via direct UPDATE (would have incorrectly fed loyalty_customer_progress + settlements). Admin (`is_admin`) and service_role/postgres exempt, same bypass idiom as F16 | ⚠️ **file written + Adam-approved, NOT yet applied to production** (see §6) | `20260707180000_guard_cancelled_terminal.sql` |

Historical fixes 1–12 (MP3 sound, Java 17, GPS-0, FCM setup, pub cache, dispatch columns, overflow UI, Sousse coords, finance overcount, restaurant blocking, promo schema) — all shipped, details in git history.

---

## 8. OPEN ITEMS — MANUAL STEPS PENDING ON ADAM

- [ ] **Tag pastry venues**: admin → Restaurants → pink "Pâtisserie" button. Until then the mobile "Pâtisseries" chip shows an empty list (zero venues are tagged).
- [ ] **Device-test notification tap routing** (partner + driver): tap an order/offer push with app killed AND backgrounded → must open the right order screen. This was never verified on a device — treat as unconfirmed.
- [ ] **Release signing**: Android release builds still signed with DEBUG keys (audit P1-1) — create an upload keystore + real `release` signingConfig before any Play Store upload.
- [ ] **`cmandili_admin/` stale checkout**: decide — delete it or fast-forward to `admin/`'s head. It still contains the pre-F17 snake_case status display bugs.
- [ ] **OPENROUTER_API_KEY** Supabase secret is a dead truncated paste — replace it or remove it (ai-chat currently survives via GEMINI_API_KEY fallback).
- [ ] Consider a follow-up "open-first" sort in listings (deliberately out of F15 scope).
- [ ] **F20+F21 loyalty program — still not visually/device-tested**: verified via `flutter analyze` (clean) + admin `next build` (clean) + DB rolled-back harness only. This machine has no Android/iOS emulator and the project's Chrome/web target fails to build for an unrelated pre-existing reason (`flutter_sound_web` incompatible with the pinned `web` package); Windows-desktop target has no Visual Studio toolchain installed. Nobody has looked at: the sheet's overshoot entrance + stamp-impact animation (ripple/shake/haptic), the milestone-aware progress text incl. both 5th/10th celebration lines, the 10th-order cycle-reset (card empties after the celebratory hold), the cancellation dialog's stamp-removal animation, the new "Mes récompenses" rewards screen (milestone card states + how-it-works section), `/dashboard/fidelite`, or fr/en/ar (incl. RTL) rendering of any of it. **This needs a real device/emulator with the Adam test account before F20/F21 can be considered done.**
- [ ] **F22 migration not applied**: run `20260707180000_guard_cancelled_terminal.sql` via `supabase db query --linked --file <f>` + `migration repair --status applied <version>` (per §6 rule — never blanket `db push`).
- [ ] **F22 SQL verification script does not exist yet** — needs to be *written* (not just run) next session, following the rolled-back `DO $$` harness pattern (§ header rule / F16/F19/F20 precedent): impersonate `authenticated` as a non-admin customer and confirm (T1) `cancelled→delivered` raises, (T2) `cancelled→cancelled` (no-op) and non-status column updates on a cancelled row still succeed, (T3) the same `cancelled→delivered` attempt succeeds when impersonating an admin or run as `service_role`/`postgres`. End with `RAISE EXCEPTION 'ALL_TESTS_PASSED :: …'` so nothing persists.
- [ ] **`boutique_partner_type` migration still uncommitted** — correction: it is NOT in the separate `cmandili_admin` GitHub repo. It's an untracked file (`supabase/migrations/20260704160000_boutique_partner_type.sql`) sitting in the **top-level `C:\Users\user\Desktop\cmandili` checkout** — which is itself a *second, separate clone of this same `cmandili_client` repo* (confirmed 2026-07-07; not the `cmandili_admin` repo, and not this `cmandili_mobile` checkout, which does not have this file at all). See the multi-clone note directly below — decide whether to port this migration into the canonical `cmandili_mobile` tree or commit it from that other checkout.
- [ ] **Multi-clone confusion, worth resolving**: as of 2026-07-07 there are at least 3 `cmandili_client` checkouts on disk pointing at the same GitHub repo: (1) `C:\Users\user\Desktop\cmandili` top-level (has its own uncommitted work, e.g. the boutique_partner_type migration above), (2) `C:\Users\user\Desktop\cmandili\cmandili_mobile` (**this is the one treated as canonical/"LIVE tree" per §1 and the one all F20/F21/F22 work in this doc was done in/committed from**), and (3)+(4) accidental nested clones inside (2) at `cmandili_mobile/cmandili_admin/` and `cmandili_mobile/cmandili_mobile/` (both point to `cmandili_client.git` too, not real submodules — no `.gitmodules` exists). None of this was created by tonight's session; flagging so nobody assumes a fix committed to one checkout is visible in another without an explicit `git pull`.
- [x] ~~Root repo (`cmandili_client`) diverged from `origin/main`~~ — **resolved 2026-07-07**: this `cmandili_mobile` checkout pulled the Amana rebrand merge earlier in the session and is now 0 ahead / 0 behind `origin/main` (confirmed via `git rev-list --left-right --count`). Note this was only checked/fixed for *this* checkout — the other `cmandili_client` clones noted above (top-level, and the two accidental nested ones) were not touched and may still be stale.
- [ ] **`admin/` repo branch ambiguity**: local checkout tracks `master` (matches `origin/master` exactly), but GitHub's default branch is `origin/main`, which has diverged 148 files from `master`. Confirm which branch is actually the live one Vercel/hosting deploys from before pushing further admin work to `master`.

---

## 9. KNOWN REMAINING WORK (audit backlog — not started unless noted)

- **Logout bug**: profile-screen logout doesn't call `signOut()` (Google session + Supabase) and never clears/unregisters the FCM token → next account on same device can receive the previous user's pushes.
- **orderStreamProvider realtime leak** (mobile): channel not disposed on screen exit.
- **Hardcoded FR strings / error snackbars**: mixed FR/EN literals across mobile (incl. F15's "Fermé"/"Ouvre à…" pills and home category chips) — needs an l10n pass through `AppLocalizations` (fr/en/ar exist).
- **Reorder feature** (customer re-orders a past order) — not started.
- **Post-delivery rating flow** — not started.
- **Dead code cleanup**: `bill_payment_screen.dart`, `supermarket supabase_service.dart`, `confirmOrder()` in mobile order_repository (no callers).
- **Status transition matrix**: the column guard restricts WHICH columns, not which status VALUES — any in-scope role can set any of the 8 statuses (mostly still true). **Partial exception (F22, pending apply)**: `cancelled` is being made terminal specifically — see §6/§7/§8. No other transition-value restrictions exist yet beyond that.
- Known residual: in-scope actors can still rewrite values within their ALLOWED columns (e.g. partner setting a nonsense status) — acceptable, documented.

---

## 10. KEY ARCHITECTURE NOTES (durable)

- **orders UPDATE RLS (F14)** — 5 policies: `orders_customer_update` (own rows), `orders_partner_update` (venue via entity chain), `orders_driver_update_own` (accepted orders), `orders_driver_claim` (atomic accept; must-be-a-driver EXISTS guard is load-bearing — permissive WITH CHECKs are OR'd across policies, an identity-free USING would enable order hijack), `orders_admin_update` (`is_admin`). New client `UPDATE orders` paths must fit one of these or they silently update 0 rows; server paths use SECURITY DEFINER/service_role.
- **Column guard (F16)**: trigger `aa_guard_orders_column_scope` BEFORE UPDATE, SECURITY INVOKER, deny-by-default OLD/NEW jsonb diff. Allowed: customer→`status,cancellation_reason,cancelled_by,cancelled_at`; partner→`status,self_delivery`; driver→`status,bill_receipt_url` (+`driver_id` claim NULL→own); admin unrestricted; bypass when `current_user NOT IN ('authenticated','anon')`. **The `aa_` prefix is load-bearing** — BEFORE triggers fire alphabetically and the guard must precede `order_cancelled_at`/`order_status_timestamps`; never add a BEFORE UPDATE trigger on orders sorting before `aa_`. `driver_fee_cut` is intentionally NOT client-writable (settlements trigger stamps it).
- **Category system recipe (F18)**: canonical values live in `ALLOWED_CATEGORIES` (`admin/app/api/restaurants/categories/route.ts`) and must stay byte-identical (accents!) with mobile `home_screen.dart _categories` — the chip filter is `toLowerCase()` equality. To add a category: add to both lists (+ optional icon case in `restaurant_card.dart`), tag venues in admin. Card badge = first category, only renders when non-empty. No schema change needed.
- **Closed-venue UX (F13+F15)**: DB trigger `enforce_venue_open` (BEFORE INSERT, `RAISE 'VENUE_CLOSED'`) is the source of truth; detail screens gate add-to-cart; checkout re-checks and maps the error; list cards dim + "Fermé" + `nextOpeningLabel()` (Africa/Tunis fixed UTC+1, returns null for missing/invalid hours). Closed venues stay visible and tappable — browsing allowed, ordering blocked.
- **Settlements**: `generate_settlements_on_delivery()` fires on cash orders' `status→delivered`; stamps `platform_fee`/`driver_fee_cut`; partner earning row; driver deduction row only if `driver_id IS NOT NULL AND NOT self_delivery`. **`orders.driver_id` is `drivers.id`, NEVER `auth.users.id`** — any code inserting it into a column FK'd to `auth.users` (like `settlements.user_id`) must resolve it first via `SELECT user_id FROM drivers WHERE id = <driver_id>` (F19 bug — this was broken live for months, silently discarding every driver-delivered cash order's `delivered` transition).
- **Loyalty program (F20)**: `apply_loyalty_program()` / trigger `on_order_delivered_loyalty`, `AFTER UPDATE OF status ON orders`, same shape/ordering as the settlements trigger — fires on `food`/`courier`/`facture` only (not `supermarket`, product decision). Increments `loyalty_customer_progress.delivered_count` (customer_id PK; **intentionally not a `profiles` column** — `profiles_update` RLS has no column-scope guard, so a counter there would be client-forgeable; this table has SELECT-own RLS only, zero write policies, only the SECURITY DEFINER trigger writes it). On the 5th/10th order it stamps `orders.loyalty_milestone_type`/`loyalty_discount_amount` (deny-by-default guard already blocks all 4 client roles — no guard changes needed) and inserts a row in `loyalty_driver_payouts` (`driver_id` → `drivers(id)`, same convention as `orders.driver_id`, admin-only, no RLS policies). **Never touches `delivery_fee`/`subtotal`** — that's why the driver settlement is provably unaffected (settlements trigger reads those same untouched columns). **Discount is determined at delivery time, not checkout** (COD — the charged amount only becomes real once the driver marks it delivered) — this is a deliberate deviation from a literal "show at checkout" read, not a bug to "fix" later. Admin: `admin/app/dashboard/fidelite/` (pending payouts + settle action + net-per-driver = commission owed − payouts). Mobile: progress card + milestone badge on `order_history_screen.dart`, celebration banner on `order_tracking_screen.dart`.
- **Loyalty cycle position, client-side (F21)**: `loyalty_customer_progress.delivered_count` is a lifetime counter and **by design does NOT reset in storage** (confirmed 2026-07-07, Adam decided against a reset migration) — the milestone trigger's own `% 5`/`% 10` checks already re-fire correctly forever regardless. The client derives "position in the current 10-cycle" the same way: `loyaltyCyclePosition(count) => count % kLoyaltyTotalSlots` (`lib/features/loyalty/data/loyalty_eligibility.dart`) — this is the ONLY place that math should live; both `loyalty_card_sheet.dart` and `loyalty_rewards_screen.dart` call it rather than reimplementing. Sheet-specific: `_positionAfterToday = position + 1` (1..10) drives the milestone-aware copy (progressing vs. landing-on-5th/10th celebration) and the 10th-order cycle-reset (after the impact settles, a ~1.4s delayed `setState` flips the grid back to an empty 0/10 card — no new animation machinery, just changes to the same props the stagger/cross-fade already react to).
- **Rewards screen (F21)**: `loyalty_rewards_screen.dart`, reached only via the sheet's "Voir mes récompenses" button (no other entry point added — surgical per Adam's ask). Static snapshot only — no pending-order awareness, unlike the sheet. Milestone-card states: the 5th-order card is "achieved" once `position >= 5` (stable for the rest of the cycle) else "current"; the 10th-order card is "current" once `position >= 5` else "locked" — it deliberately has **no persistent "achieved" state**, because hitting the 10th immediately resets `position` to 0 next cycle, so "just achieved the 10th" is only ever a transient moment (handled by the sheet's celebration text), not a snapshot-able state.
- **F22 — cancelled-terminal guard**: see §6/§7/§8. Trigger `aa_guard_cancelled_terminal`, `BEFORE UPDATE OF status`, same bypass idiom as F16 (`current_user NOT IN ('authenticated','anon')` → return; `profiles.is_admin` → return). Blocks OLD.status='cancelled' → NEW.status<>'cancelled' for everyone else. Column-specific (`OF status`) means non-status writes to a cancelled row (e.g. `cancellation_reason` correction) are untouched. **Not yet applied — do not assume this protection is live.**
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
| `supabase/migrations/20260706170000_fix_driver_settlement_user_id.sql` | Settlements driver_id/user_id FK fix (F19) |
| `supabase/migrations/20260706171000_loyalty_program.sql` | Loyalty program schema+trigger (F20) |
| `supabase/migrations/20260707180000_guard_cancelled_terminal.sql` | Cancelled-terminal guard trigger (F22) — **written, NOT yet applied** |
| `cmandili_mobile/lib/features/loyalty/data/loyalty_eligibility.dart` | Shared eligible-order-types set + `kLoyaltyTotalSlots` + `loyaltyCyclePosition()` (F21) |
| `cmandili_mobile/lib/features/loyalty/presentation/loyalty_card_sheet.dart` | Post-order stamp-card bottom sheet: entrance/stagger/impact/ripple animation, milestone-aware copy, cycle-reset (F21) |
| `cmandili_mobile/lib/features/loyalty/presentation/loyalty_cancel_dialog.dart` | Cancellation confirmation dialog + stamp-removal animation (F21) |
| `cmandili_mobile/lib/features/loyalty/presentation/loyalty_rewards_screen.dart` | "Mes récompenses" screen: milestone cards + how-it-works (F21) |
| `cmandili_mobile/lib/features/loyalty/presentation/widgets/` | `loyalty_stamp.dart`, `loyalty_stamp_grid.dart`, `loyalty_progress_section.dart` — shared by sheet, dialog, rewards screen |
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
