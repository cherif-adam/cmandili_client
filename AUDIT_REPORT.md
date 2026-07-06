# cmandili_mobile — Pre-Release Audit Report

**Date:** 2026-07-03
**Scope:** Customer app (`cmandili_mobile`) — full read-only pre-release checkup.
**Build state at audit:** `flutter analyze` = 4 info-level deprecations (no errors/warnings).
`flutter build apk --release` = **SUCCESS** (`app-release.apk`, 122.1 MB, arm64-v8a only).

> This audit is READ-ONLY. No source file was modified. Section A is the
> **do-not-break** list — these flows were traced in code and confirmed wired
> end-to-end. Every issue below cites `file:line` so fixes can be surgical.

---

## Section A — VERIFIED WORKING (do-not-break list)

These were traced through the actual code paths (not assumed) and are functional.
Protect them during future fixes.

### Auth (fully wired)
- Email **signup** / **login** — [auth_repository.dart:58](lib/features/auth/data/auth_repository.dart:58), [auth_repository.dart:71](lib/features/auth/data/auth_repository.dart:71); called from [auth_screen.dart:103](lib/features/auth/presentation/auth_screen.dart:103).
- **Google** sign-in (with serverClientId) and **Apple** sign-in (nonce-bound) — [auth_repository.dart:89](lib/features/auth/data/auth_repository.dart:89), [auth_repository.dart:123](lib/features/auth/data/auth_repository.dart:123).
- **Password reset** — 3-step OTP flow (send code → verify OTP → update password) — [auth_repository.dart:185](lib/features/auth/data/auth_repository.dart:185); UI in [forgot_password_screen.dart](lib/features/auth/presentation/forgot_password_screen.dart) + [reset_password_screen.dart:75](lib/features/auth/presentation/reset_password_screen.dart:75).
- **Session persistence** — `authStateProvider` stream drives routing in [main.dart:82](lib/main.dart:82). **Logout** in [phone_gate_screen.dart:63](lib/features/profile/presentation/phone_gate_screen.dart:63) calls `signOut()` (Google + Supabase). See P1-5 for the profile-screen logout caveat.
- **Phone gate** — after login, a phone number on `profiles` is required before the app opens — [main.dart:103](lib/main.dart:103).

### Food ordering (end-to-end)
- **Browse** — home restaurant list with proper `.when(loading/error/empty)` + pull-to-refresh — [home_screen.dart:589](lib/features/home/presentation/home_screen.dart:589).
- **Restaurant detail → cart** — add-to-cart with variant handling — [restaurant_detail_screen.dart:884](lib/features/restaurant/presentation/restaurant_detail_screen.dart:884). (See **P0-1**: no open/closed gate here.)
- **Checkout** — address selection, contact prefill from profile, promo apply, delivery-fee recompute from pickup↔dropoff distance — [checkout_screen.dart:92](lib/features/checkout/presentation/checkout_screen.dart:92).
- **Order placement** — `createOrder` inserts `status='pending'` for food/supermarket (correct — partner must accept), uploads voice notes, writes order_items — [order_repository.dart:16](lib/features/orders/data/order_repository.dart:16).
- **Realtime tracking** — driver location via `deliveries` stream + Mapbox route polyline on map — [order_tracking_screen.dart:44](lib/features/orders/presentation/order_tracking_screen.dart:44).
- **Delivered** — customer self-confirm receipt — [order_tracking_screen.dart:232](lib/features/orders/presentation/order_tracking_screen.dart:232).

### Promo codes (correct + secure)
- Dry-run **preview** + commit-at-placement, server-authoritative discount (client never computes price) — [promo_repository.dart:25](lib/features/promo/data/promo_repository.dart:25), consumed at [checkout_screen.dart:118](lib/features/checkout/presentation/checkout_screen.dart:118).
- RPC params match live DB and the fixup migration uses the **real** live column names `type` / `value` / `expires_at` — [20260628_promo_codes_fixup.sql:28](../supabase/migrations/20260628_promo_codes_fixup.sql). Verified the client passes `p_user_id/p_promo_code/p_subtotal/p_dry_run` correctly.

### Order cancellation (client matches DB)
- `cancelOrderByCustomer` writes `status='cancelled'`, `cancellation_reason`, `cancelled_by='customer'`, `cancelled_at`, guarded to own orders in `('pending','confirmed')` — [order_repository.dart:158](lib/features/orders/data/order_repository.dart:158). DB columns + auto-stamp trigger exist — [20260629_order_cancellation.sql](../supabase/migrations/20260629_order_cancellation.sql).

### Colis (P2P courier) — complete
- Full flow: pickup/dropoff addresses, package size, photo upload to `package-photos`, saved recipients, distance/fee, creates `status='ready'` + `order_type='courier'`, → tracking — [courier_screen.dart:361](lib/features/courier/presentation/courier_screen.dart:361). `status='ready'` is correct for courier (no partner-prep step).

### Facture (bill payment) — complete
- Creates `status='ready'` + `order_type='facture'`, photo upload → tracking — [facture_screen.dart:195](lib/features/facture/presentation/facture_screen.dart:195).
- **Mes Factures** list — [mes_factures_screen.dart](lib/features/bills/presentation/mes_factures_screen.dart); backed by `getBillOrders()` — [order_repository.dart:257](lib/features/orders/data/order_repository.dart:257).
- **Bill reminders** — local scheduled notifications with timezone init (`Africa/Tunis`) — [main.dart:27](lib/main.dart:27), [bill_reminder_service.dart](lib/features/bills/services/bill_reminder_service.dart).

### Other confirmed-working
- **Favorites** — DB-backed (`user_favorites`) — [favorites_provider.dart:17](lib/features/favorites/providers/favorites_provider.dart:17).
- **Notifications list** — DB-backed (`notifications`) — [notification_repository.dart:14](lib/features/notifications/data/notification_repository.dart:14).
- **FCM** — token registration on init + refresh + sign-in, foreground display with a standard + urgent channel, background notification-payload rendering; channels also created natively in [Application.kt](android/app/src/main/kotlin/com/example/food_delivery_app/Application.kt) — [push_service.dart:37](lib/core/push/push_service.dart:37). (Tap-routing is the gap — see **P1-2**.)
- **Realtime cleanup (tracking)** — `_deliverySubscription` is cancelled in `dispose()` — [order_tracking_screen.dart:106](lib/features/orders/presentation/order_tracking_screen.dart:106).
- **Location resilience** — GPS off / permission denied returns `null` and falls back to manual map pick; no crash — [location_service.dart:32](lib/core/utils/location_service.dart:32), [map_address_picker.dart:106](lib/core/widgets/map_address_picker.dart:106).
- **AI chat security** — talks only to the `ai-chat` edge function via `functions.invoke`; **no** OpenRouter/API keys or direct HTTP in the client — [ai_chat_service.dart:25](lib/services/ai_chat_service.dart:25).
- **Secrets hygiene** — no secrets shipped in the client. Firebase keys in [firebase_options.dart](lib/firebase_options.dart) are public project identifiers (safe). The Mapbox **secret** download token lives in `android/gradle.properties`, which is **git-ignored** and build-time only (does not ship in the APK). `.env` ships only the publishable anon key + Mapbox `pk.` public token.
- **Release build config** — real `applicationId = com.cmandili.mobile`, app label `Cmandili`, custom `launcher_icon` across all densities, `launch_background` splash, arm64-only + locale filtering, `minSdk 24`. Native `.Application`/`MainActivity` classes declare the correct `com.cmandili.mobile` package (only the folder path is stale — see P2).

---

## Section B — P0 BLOCKERS (must fix before ANY test release)

### P0-1 — Ghost order: a customer can order from a CLOSED restaurant/supermarket
**Confirmed at BOTH layers.**

- **UI level — no open/closed gate.** The add-to-cart button only disables when a variant is unpicked (`mustPick`), never on `isOpen` — [restaurant_detail_screen.dart:881](lib/features/restaurant/presentation/restaurant_detail_screen.dart:881). Same for supermarket — [supermarket_detail_screen.dart:414](lib/features/supermarket/presentation/supermarket_detail_screen.dart:414). The cart → checkout transition has no gate either — [cart_screen.dart:128](lib/features/cart/presentation/cart_screen.dart:128) — and `_placeOrder` never reads `is_open` — [checkout_screen.dart:92](lib/features/checkout/presentation/checkout_screen.dart:92). `isOpen` is fetched and shown only as a **badge** — [restaurant_card.dart:110](lib/features/restaurant/presentation/widgets/restaurant_card.dart:110).
- **DB level — no enforcement.** The order INSERT policies check only user ownership and `is_blocked` — [20260628_profiles_is_blocked.sql:27](../supabase/migrations/20260628_profiles_is_blocked.sql) — and the base `orders_insert` checks `auth.uid() = user_id`. **Neither checks `restaurants.is_open` / `supermarkets.is_open`.** The `*_ghost_*` migrations are unrelated (they auto-confirm orders for partner-less "ghost" venues, not closed-hours). The `auto-close` cron only flips `is_open=false` on schedule — nothing then blocks the insert.

**Why it matters:** orders land on a closed venue that will never accept them → stuck `pending` orders, bad first impression, driver/partner confusion.
**Suggested fix (one line):** disable add-to-cart + block checkout when `!isOpen` client-side, AND add an `is_open` check to order insert server-side (RLS `WITH CHECK` subquery or a `BEFORE INSERT` trigger that raises on closed venue).

---

## Section C — P1 IMPORTANT (fix before public test)

### P1-1 — Release build is signed with DEBUG keys
[build.gradle.kts](android/app/build.gradle.kts) release buildType: `signingConfig = signingConfigs.getByName("debug")`.
**Why it matters:** a debug-signed artifact **cannot be uploaded to Play Store** (blocker if you distribute via any Play track — effectively P0 for that path), and updates break once you switch to a real key. Sideloaded APK for closed testing will still install.
**Fix:** create an upload keystore and a proper `release` `signingConfig`.

### P1-2 — Notification tap does nothing (no routing / deep-link)
No `getInitialMessage` (terminated launch), no `onMessageOpenedApp` (background tap), no `onDidReceiveNotificationResponse` (foreground local-notif tap) anywhere — [push_service.dart](lib/core/push/push_service.dart). The manifest even declares a `FLUTTER_NOTIFICATION_CLICK` intent-filter ([AndroidManifest.xml:39](android/app/src/main/AndroidManifest.xml)) but the Dart side ignores it.
**Why it matters:** tapping an order push just opens the home screen — the customer can't jump to the order it referenced.
**Fix:** handle the three entry points and navigate to `OrderTrackingScreen(orderId: message.data['order_id'])`.

### P1-3 — `orders` UPDATE RLS is open to any authenticated user
Live policy: `orders_update ... USING (auth.role() = 'authenticated')` — [cmandili_schema.sql:310](../cmandili_schema.sql); no migration tightens it.
**Why it matters:** any signed-in user could UPDATE any order row (e.g. mark delivered / cancel) if they know its UUID. Exploitability is low (order UUIDs aren't enumerable — the SELECT policy is `user_id`-scoped, and v4 UUIDs aren't guessable), but the policy is far broader than intended. The customer app relies on this permissive policy for self-cancel/confirm, so tightening must add proper scoped policies.
**Fix:** replace with `USING (user_id = auth.uid())` for customers, plus explicit driver/partner update policies.

### P1-4 — Localization gaps: Colis / Facture / Tracking / Mes Factures are FR-hardcoded
High density of hardcoded French literals (headers, buttons, dialogs): Colis ~32 in [courier_screen.dart](lib/features/courier/presentation/courier_screen.dart), Facture ~22 in [facture_screen.dart](lib/features/facture/presentation/facture_screen.dart), Order Tracking ~22 incl. the whole cancel dialog [order_tracking_screen.dart:111](lib/features/orders/presentation/order_tracking_screen.dart:111), Mes Factures ~13. Also user-facing **raw error strings in English**: `'Error: $e'` [checkout_screen.dart:260](lib/features/checkout/presentation/checkout_screen.dart:260), `'Error loading restaurants: $error'` [home_screen.dart:654](lib/features/home/presentation/home_screen.dart:654), and the "added to cart" snackbar [restaurant_detail_screen.dart:894](lib/features/restaurant/presentation/restaurant_detail_screen.dart:894). The rest of the app correctly uses `AppLocalizations` (ar/en/fr).
**Why it matters:** AR/EN users hit French walls in three core modules; raw `$e` strings look broken.
**Fix:** move these literals into the `.arb` files; replace raw-error snackbars with a friendly localized message.

### P1-5 — FCM token not removed on logout
`signOut()` never deletes the `device_tokens` row — [push_service.dart:94](lib/core/push/push_service.dart:94), [auth_repository.dart:175](lib/features/auth/data/auth_repository.dart:175). Also note the **profile-screen logout** [profile_screen.dart:270](lib/features/profile/presentation/profile_screen.dart:270) only navigates to `AuthScreen` — it does **not** call `signOut()` at all, so the Supabase session isn't actually cleared from there.
**Why it matters:** a logged-out (or switched) device keeps receiving the previous user's order pushes until the token is reused; the profile-screen path leaves a live session behind.
**Fix:** on logout, delete the current device token then call `authRepository.signOut()`; wire the profile logout button to the same path.

### P1-6 — `orderStreamProvider` is a non-autoDispose family (realtime leak)
[order_provider.dart:8](lib/features/orders/providers/order_provider.dart:8) — `StreamProvider.family` (not `.autoDispose`). Each distinct `orderId` opened keeps an `orders` realtime stream open for the app's lifetime.
**Why it matters:** opening several orders in a session accumulates open Postgres realtime subscriptions (memory + connection pressure).
**Fix:** make it `StreamProvider.autoDispose.family`.

---

## Section D — P2 NICE-TO-HAVE (post-test-release)

### D-1 — "Commander à nouveau" (reorder) does NOT exist
No reorder code anywhere. **Where it plugs in:** a per-order action in [order_history_screen.dart](lib/features/orders/presentation/order_history_screen.dart) that rebuilds `CartItem`s from `order_items` via [cart_provider.dart](lib/features/cart/providers/cart_provider.dart), then routes to checkout.

### D-2 — Post-delivery rating not wired
The `reviews` table exists in schema ([cmandili_schema.sql:473](../cmandili_schema.sql)) but the mobile app **never reads or writes it**, and there is no rating UI (the `_StarRating` in [ai_chat_screen.dart:1267](lib/screens/ai_chat_screen.dart:1267) is display-only for chat cards). **Where it plugs in:** a prompt after the delivered state in [order_tracking_screen.dart:232](lib/features/orders/presentation/order_tracking_screen.dart:232) or from order history, inserting into `reviews`.

### D-3 — Dead code to remove
- [core/config/supabase_service.dart](lib/core/config/supabase_service.dart) — never imported; also opens an uncleaned realtime channel.
- [bills/presentation/bill_payment_screen.dart](lib/features/bills/presentation/bill_payment_screen.dart) — never referenced; its only consumer of [bills/data/models/bill_provider.dart](lib/features/bills/data/models/bill_provider.dart) — both dead. (The **live** bill flow is `facture/` + `mes_factures_screen`.)
- `confirmOrder()` — [order_repository.dart:128](lib/features/orders/data/order_repository.dart:128) — never called (checkout explicitly says not to).

### D-4 — `flutter analyze`: 4 deprecations
`activeColor`→`activeThumbColor` at [courier_screen.dart:790](lib/features/courier/presentation/courier_screen.dart:790) and [profile_screen.dart:486](lib/features/profile/presentation/profile_screen.dart:486); Radio `groupValue`/`onChanged`→`RadioGroup` at [order_tracking_screen.dart:171](lib/features/orders/presentation/order_tracking_screen.dart:171).

### D-5 — Cosmetic / metadata
- `.env` says `APP_NAME=Cmandili Partner` (wrong app) — but it's **dead** (never read; `APP_NAME` isn't used in code).
- `MaterialApp` title is `'Food Delivery'` — [main.dart:65](lib/main.dart:65); shows in Android recents. Set to Cmandili.
- Stale Kotlin folder path `com/example/food_delivery_app/` (the `package` declaration inside is correct, so it's harmless — rename for tidiness only).
- Release APK is **122 MB** with R8 disabled ([build.gradle.kts](android/app/build.gradle.kts)); post-test, consider an App Bundle and re-enabling R8 with keep rules. Also Java-8 "obsolete source/target" warnings during the release build.

---

## Suggested fix ORDER (one item per future prompt)

1. **Ghost order (P0-1)** — gate add-to-cart + checkout on `isOpen` (restaurant & supermarket) AND enforce `is_open` on order insert server-side.
2. **Release signing (P1-1)** — generate upload keystore + real `release` signingConfig.
3. **Notification tap routing (P1-2)** — implement `getInitialMessage` + `onMessageOpenedApp` + local-notif tap → navigate to the order.
4. **Order security & token hygiene (P1-3 + P1-5)** — scope `orders_update` RLS to owner/driver/partner; delete device token and truly `signOut()` on both logout paths.
5. **Localization (P1-4)** — move Colis/Facture/Tracking/Mes Factures strings to `.arb`; replace raw `$e` snackbars with friendly localized text.
6. **Realtime leak + dead code (P1-6 + D-3 + D-4)** — `autoDispose` on `orderStreamProvider`; delete dead files/methods; clear the 4 analyzer deprecations.
7. **Reorder (D-1)** — "Commander à nouveau" from order history.
8. **Rating (D-2)** — post-delivery review UI writing to `reviews`.
9. **Polish (D-5)** — app title/name, APK size / R8, stale package path.
