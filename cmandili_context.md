# Cmandili — Project Architecture & State Document
> **Purpose:** Dense AI-session bootstrap context. Feed this file at the start of every session instead of reading the full codebase.
> **Last updated:** 2026-06-01 | **Covers:** cmandili_mobile · cmandili_driver · cmandili_partner

---

## 1. System Architecture Overview

Three separate Flutter apps sharing **one Supabase project** (same DB, same Auth, same Storage).

| App | Package | Role |
|-----|---------|------|
| `cmandili_mobile` | `cmandili_mobile` | Customer — browse restaurants, order food, AI chat |
| `cmandili_driver` | `cmandili_driver` | Driver — accept deliveries, live GPS tracking |
| `cmandili_partner` | `cmandili_partner` | Partner/Restaurant — manage menu, receive orders |

**Monorepo layout:**
```
cmandili/
├── cmandili_mobile/
├── cmandili_driver/
├── cmandili_partner/
└── supabase/
    └── functions/
        ├── push-on-order-status/index.ts   ← main FCM fan-out function
        ├── notify-partner-order/index.ts   ← legacy; still active for new orders
        └── ai-search/index.ts
```

**Backend:** Supabase (Auth + PostgreSQL + Realtime + Storage + Edge Functions)
**Push:** Firebase Cloud Messaging (FCM) HTTP v1 API — called from Edge Functions using a service account JWT. Device tokens stored in `device_tokens` table.

---

## 2. Tech Stack

| Concern | Choice | Notes |
|---------|--------|-------|
| Framework | Flutter SDK ≥3.0.0 | |
| State management | **Riverpod** ^2.4.9 | `StateNotifierProvider`, `FutureProvider`, `StreamProvider` |
| Backend | **Supabase** supabase_flutter ^2.3.0 | Auth + DB + Realtime + Storage |
| Push | `firebase_messaging` ^14.7 + `flutter_local_notifications` | FCM delivery, local display |
| Maps | Mapbox Maps Flutter ^2.3.0 | All 3 apps |
| Location | `geolocator` ^10.1, `geocoding` ^2.1 | Distance calc via Mapbox Directions API, fallback Haversine |
| Background GPS | `flutter_background_service` ^5.0.5 | Driver only — separate Android isolate |
| AI / LLM | OpenRouter → `google/gemini-2.0-flash-001` | via `http` package |
| Voice STT | Android `SpeechRecognizer` via `MethodChannel` | Mobile only |
| Voice playback | `audioplayers` ^5.2.1 | Partner app — plays customer voice notes |
| Image | `image_picker` ^1.0.7, `cached_network_image` ^3.3.0 | |
| Permissions | `permission_handler` ^11.1.0 | |
| Config | `flutter_dotenv` | ^6.0 mobile/driver, ^5.1 partner |
| Code gen | `freezed` + `json_serializable` | Used selectively |
| Auth social | `google_sign_in` ^6.1.6 (all), `sign_in_with_apple` ^6.1 (mobile only) | |
| Localization | `flutter_localizations` + ARB files + generated `AppLocalizations` | EN / FR / AR |
| Cart persistence | `shared_preferences` ^2.2.2 | Key: `cmandili_cart_v1` |

---

## 3. Architecture Pattern

**Feature-first Clean Architecture (light MVVM)**

```
lib/
├── core/
│   ├── push/            push_service.dart          ← FCM + local notifications
│   ├── utils/           delivery_fee.dart · platform_pricing.dart · currency_formatter.dart · location_service.dart
│   ├── theme/           app_colors.dart · app_theme.dart
│   └── providers/       localization_provider.dart · theme_provider.dart
├── features/
│   └── <feature>/
│       ├── data/models/     Plain Dart or freezed classes
│       ├── data/<name>_repository.dart
│       ├── presentation/    Screens + widgets
│       └── providers/       Riverpod providers
├── l10n/                app_en.arb · app_fr.arb · app_ar.arb + generated
└── main.dart
```

### Layer rules (enforced)
- `data/` → Supabase queries only. **Never imports Riverpod.**
- `providers/` → Riverpod wiring only. Instantiates repos, exposes async state.
- `presentation/` → Widgets only. Reads providers via `ref.watch`. **Never calls Supabase directly.**
- `core/` → Cross-cutting concerns. **No feature imports.**
- Every repository has a private `_mapXFromDb(Map<String, dynamic>)` — snake_case DB columns → camelCase model fields. **Models never read DB column names directly.**

---

## 4. Routing

**Navigator 1.0 (imperative). No GoRouter. No named routes.**

```dart
Navigator.push(context, MaterialPageRoute(builder: (_) => SomeScreen()));
Navigator.pushAndRemoveUntil(...);  // logout / post-auth redirect
```

### Post-auth gate (all apps)
`authStateProvider` (StreamProvider) drives `MaterialApp.home`:
- `null` → `AuthScreen`
- authenticated → `_PostAuthGate` checks a secondary condition

| App | Gate condition | Redirect |
|-----|----------------|----------|
| mobile | `profiles.phone` non-null | `PhoneGateScreen` |
| driver | `drivers.vehicle_type` non-null | `VehicleInfoScreen` |
| partner | none | directly to `HomeScreen` |

---

## 5. Startup Sequence (all apps)

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');          // 1. env FIRST
  MapboxOptions.setAccessToken(...);            // 2. Mapbox token
  await Future.wait([                           // 3. parallel cold-start
    Supabase.initialize(...),
    Firebase.initializeApp(...).catchError(...),
    SharedPreferences.getInstance(),            // driver only
  ]);
  runApp(const ProviderScope(child: MyApp()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    PushService.instance.initialize();          // 4. deferred — after frame 1
    BackgroundLocationService.initialize();     // driver only
  });
}
```

Driver also writes `supabase_url` + `supabase_anon_key` to SharedPreferences so the GPS background isolate can re-initialize Supabase without `.env` access.

---

## 6. State Management — Provider Inventory

### Mobile providers
| Provider | Type | State |
|----------|------|-------|
| `authStateProvider` | `StreamProvider<User?>` | Supabase auth stream |
| `restaurantsProvider` | `FutureProvider<List<Restaurant>>` | All open restaurants |
| `foodItemsProvider` | `FutureProvider.family<List<FoodItem>, String>` | Menu by restaurantId |
| `foodItemVariantsProvider` | `FutureProvider.family<List<ItemVariant>, String>` | Variants by itemId |
| `cartProvider` | `StateNotifierProvider<CartNotifier, List<CartItem>>` | Cart (SharedPrefs persisted) |
| `cartSubtotalProvider` | `Provider<double>` | Derived — sum of CartItem.price × qty |
| `cartDeliveryFeeProvider` | `Provider<double>` | Preview = 3.500 DT base (distance unknown) |
| `cartTotalProvider` | `Provider<double>` | subtotal + delivery fee |
| `happyHourRestaurantsProvider` | `FutureProvider<List<FoodItem>>` | Active discount items |
| `happyHourSupermarketsProvider` | `FutureProvider<List<GroceryItem>>` | Same for grocery |
| `favoritesProvider` | `StateNotifierProvider` | Saved restaurants |
| `localizationProvider` | `StateNotifierProvider<_, Locale>` | en / ar / fr |
| `themeProvider` | `StateNotifierProvider<_, ThemeMode>` | light / dark |
| `aiSearchProvider` | `StateNotifierProvider<AiSearchNotifier, AiSearchState>` | AI chat state |
| `promoRepositoryProvider` | `Provider<PromoRepository>` | Promo code RPC wrapper |
| `promoProvider` | `StateNotifierProvider.autoDispose<PromoNotifier, PromoState>` | Promo preview; auto-disposed on pop |

### Driver providers
| Provider | Type | State |
|----------|------|-------|
| `authStateProvider` | `StreamProvider<User?>` | auth stream |
| `currentDriverIdProvider` | `FutureProvider<String?>` | resolves/creates `drivers` row |
| `availableOrdersProvider` | `StreamProvider<List<Order>>` | pending/ready + unassigned |
| `activeDeliveryProvider` | `StreamProvider<Order?>` | driver's active non-delivered order |
| `driverDeliveryHistoryProvider` | `FutureProvider<List<Order>>` | completed deliveries |
| `driverOnlineProvider` | `StateNotifierProvider<DriverOnlineNotifier, bool>` | online/offline + BG service |

### Partner providers
| Provider | Type | State |
|----------|------|-------|
| `authStateProvider` | `StreamProvider<User?>` | auth stream |
| `partnerProfileProvider` | `FutureProvider<PartnerProfile?>` | entityId + partnerType |
| `partnerOrdersStreamProvider` | `StreamProvider<List<Order>>` | real-time incoming orders |
| `dashboardStatsProvider` | `FutureProvider<Map>` | orderCount + revenue + avgPrepTime + rating |
| `menuProvider` | `StateNotifierProvider` | food/grocery item list |
| `menuScannerProvider` | `StateNotifierProvider` | AI scan state |

---

## 7. Database Schema

### Core tables

**`profiles`** (FK → auth.users.id)
`id · full_name · avatar_url · phone · updated_at`

**`restaurants`**
`id · name · description · image_url · rating · review_count · delivery_time_min · delivery_fee · minimum_order · categories[] · is_open · latitude · longitude`

**`food_items`** (FK → restaurants.id)
`id · restaurant_id · name · description · image_url · price · category · is_available · preparation_time · is_vegetarian · is_spicy · discount_price · discount_end_time · discount_quantity · is_happy_hour · happy_hour_price · happy_hour_start · happy_hour_end`

**`food_item_variants`** (FK → food_items.id)
`id · food_item_id · name · price · sort_order`

**`supermarkets`**
`id · name · image_url · rating · is_open`

**`grocery_items`** (FK → supermarkets.id)
`id · supermarket_id · name · description · image_url · price · category · unit · is_organic · is_available · discount_price · discount_end_time · discount_quantity`

**`grocery_item_variants`** (FK → grocery_items.id)
`id · grocery_item_id · name · price · sort_order`

**`orders`**
`id · user_id · restaurant_id · supermarket_id · status · subtotal · delivery_fee · total · payment_method · notes · delivery_address(JSONB) · order_type · distance_km · created_at · estimated_delivery_time · driver_id · pickup_address(JSONB) · recipient_name · recipient_phone · package_description`

**`order_items`** (FK → orders.id)
`id · order_id · food_item_id · grocery_item_id · quantity · price · options(JSONB) · voice_note_url`

**`drivers`**
`id · user_id · vehicle_type · is_online · current_lat · current_lng · last_location_update`

**`deliveries`**
`id · current_lat · current_lng · updated_at`

**`device_tokens`**
`id · user_id · token · platform · created_at`
Upserted on `onConflict: 'token'` at login + token refresh.

**`promo_codes`**
`id · code(UNIQUE,UPPER) · type('percentage'|'fixed') · value · min_order_amount · max_uses(NULL=unlimited) · used_count · expires_at(NULL=never) · is_active · created_at`

**`user_promo_usages`**
`id · user_id · promo_code_id · used_at · UNIQUE(user_id, promo_code_id)`

### Views
**`orders_with_customer`** — `orders JOIN profiles` → exposes `customer_name`, `customer_phone`.
Driver app streams `orders` (base table — views can't be subscribed via Realtime), then one-shot fetches `orders_with_customer` for customer contact enrichment.

### RPCs
**`apply_promo_code(p_user_id, p_promo_code, p_subtotal, p_dry_run=FALSE)`**
Returns `JSONB { status, error_code, error_message, discount_amount, new_subtotal }`.
Validation chain: NOT FOUND → INACTIVE → EXPIRED → MAX_USES_REACHED → ALREADY_USED → MIN_ORDER.
`p_dry_run=FALSE`: row-locks with `SELECT FOR UPDATE` → inserts usage → increments counter atomically.

### Order status FSM
```
pending → confirmed → preparing → ready → pickedUp → onTheWay → delivered
                                                               ↘ cancelled (any stage)
```

### Order types
`food | supermarket | courier | billPayment`

---

## 8. Storage Buckets

| Bucket | Path | Content |
|--------|------|---------|
| `profiles` | `avatars/<userId>/avatar.jpg` | User avatars — upsert + cache-bust `?v=<ms>` |
| `items` | `<path>` | Food/grocery item images (partner upload) |
| `voice-messages` | `<orderId>/<timestamp>.aac` | Customer voice order notes (public bucket) |

---

## 9. Auth

| Method | Apps |
|--------|------|
| Email + Password | all |
| Google OAuth (`signInWithIdToken`) | all |
| Apple Sign-In (nonce-bound) | mobile only |

`User.fromSupabase()` maps: `uid ← id`, `email`, `displayName ← full_name ?? name`, `photoURL ← avatar_url ?? picture`, `role ← appMetadata['role'] ?? 'client'`.

### Forgot Password — OTP Flow (all 3 apps)
**Method: 8-digit OTP code. NOT deep links.**

Rationale: deep links need `AndroidManifest` intent-filters + iOS associated-domains for all 3 apps. OTP requires only a Supabase email template change.

**Supabase Dashboard setup (one-time):**
Authentication → Email Templates → Reset Password → change body to use `{{ .Token }}` (the 8-digit code) instead of `{{ .ConfirmationURL }}`.

**Flutter flow:**
```
AuthScreen (Sign In tab) → "Forgot Password?" TextButton
  → ForgotPasswordScreen    (email input)
      authRepo.sendPasswordResetOtp(email)
      = supabase.auth.resetPasswordForEmail(email)
  → ResetPasswordScreen(email: email)
      authRepo.verifyPasswordResetOtp(email, token)
      = supabase.auth.verifyOTP(email, token, type: supabase.OtpType.recovery)
      → recovery session established
      authRepo.updatePassword(newPassword)
      = supabase.auth.updateUser(supabase.UserAttributes(password: ...))
      → Success dialog → Navigator.popUntil(route.isFirst)
```

**Files (identical across all 3 apps):**
- `lib/features/auth/presentation/forgot_password_screen.dart`
- `lib/features/auth/presentation/reset_password_screen.dart`
- `lib/features/auth/data/auth_repository.dart` — methods: `sendPasswordResetOtp`, `verifyPasswordResetOtp`, `updatePassword`

**Critical import rule:** All 3 `auth_repository.dart` files import supabase with alias `as supabase`. Therefore always write `supabase.OtpType.recovery` and `supabase.UserAttributes(...)` — never bare `OtpType` or `UserAttributes`.

**OTP field:** `maxLength: 8`, `FilteringTextInputFormatter.digitsOnly`, validator checks `v.trim().length != 8`.

---

## 10. Platform Pricing (10% Markup — Mobile only)

**Single source of truth:** `cmandili_mobile/lib/core/utils/platform_pricing.dart`

```dart
const double kPlatformMarkupRate = 0.10;
double applyPlatformMarkup(double basePrice) => basePrice * (1 + kPlatformMarkupRate);
```

**Rule:** `food_items.price` / `grocery_items.price` = restaurant's raw base price. `cmandili_mobile` always shows and charges `base × 1.10`. Partner and driver apps are **unaffected** — they read raw prices directly.

**Implementation points:**
- `FoodItem.clientPrice` → `applyPlatformMarkup(discountPrice ?? price)`
- `GroceryItem.clientPrice` → same
- `AiSearchFoodResult.effectivePrice` → `applyPlatformMarkup(discountPrice ?? price)`
- `CartItem.price` getter → `foodItem!.clientPrice` | `groceryItem!.clientPrice` | `applyPlatformMarkup(variant!.price)`
- `CartItem.price` feeds `order_items.price` (DB) — marked-up price is always stored and billed
- All UI price displays in `restaurant_detail_screen.dart`, `supermarket_detail_screen.dart`, `happy_hour_screen.dart`, `ai_search_result_card.dart` use `clientPrice` / `applyPlatformMarkup()`
- **Rate change:** edit only `kPlatformMarkupRate` in `platform_pricing.dart`

---

## 11. Delivery Fee Algorithm

**Single source of truth:** `lib/core/utils/delivery_fee.dart` (in all 3 apps)

```dart
const double kDeliveryBaseFee   = 3.5;   // base fee covers first 3 km
const double _kThresholdKm      = 3.0;   // surcharge starts beyond this
const double _kPerKmSurcharge   = 0.5;   // 0.500 TND per km over threshold

double calculateDeliveryFee({
  double partnerFlatFee = kDeliveryBaseFee,
  double? distanceKm,
}) {
  final extra = (distanceKm ?? 0) - _kThresholdKm;
  final candidate = partnerFlatFee + (extra > 0 ? extra * _kPerKmSurcharge : 0);
  return candidate < kDeliveryBaseFee ? kDeliveryBaseFee : candidate;
}
// Examples: 2.5 km → 3.500 | 4.0 km → 4.000 | 4.5 km → 4.250 TND
```

**Cart preview:** `cartDeliveryFeeProvider` returns `calculateDeliveryFee()` = 3.500 DT (no distance yet). No longer fetches `restaurant.delivery_fee` — the base fee is a platform constant.

**Checkout final fee:** `checkout_screen.dart` fetches only `latitude, longitude` from the restaurant/supermarket row (NOT `delivery_fee`), computes real distance via Mapbox Directions API (`tryDistanceKm()`), then calls `calculateDeliveryFee(distanceKm: distanceKm)`.

**Special order types:** Courier passes `partnerFlatFee: courierBaseFee`, bill payment passes `partnerFlatFee: 2.0`. The 3.500 floor still applies.

**Distance:** `LocationService.calculateRouteDistance()` uses Mapbox Directions API with 5s timeout; falls back to `Geolocator.distanceBetween()` (Haversine) if the API fails.

---

## 12. Push Notification Architecture

### Overview

```
Order event in DB
  → Supabase Database Webhook (HTTP POST)
  → Edge Function: push-on-order-status/index.ts
      ├── Standard events (confirmed/preparing/ready/…) → sendFcm() with notification block
      │     → System renders banner notification
      └── Alarm events (new_order / offer_to_driver) → sendDataOnlyFcm() NO notification block
            → Flutter firebaseMessagingBackgroundHandler fires
            → Flutter shows alarm notification (custom sound + fullScreenIntent)
```

### Why data-only for alarm events
FCM messages with a `notification` block are rendered by the system (Android OS / iOS). This means Flutter's `firebaseMessagingBackgroundHandler` is **skipped** for alarm-style events. To use custom alarm channels, full-screen intents, and `FLAG_INSISTENT`, the message must be **data-only** (no `notification` block). The Flutter handler then takes full control of the notification display.

### Edge Function: `push-on-order-status/index.ts`
Two FCM helper functions:
- `sendFcm()` — includes `notification` block; used for standard status pushes (customer/partner/driver lifecycle updates).
- `sendDataOnlyFcm()` — data only; used for `offer_to_driver` and waterfall dispatch. Includes `android.direct_boot_ok: true` and `apns.content-available: 1`.

Two fan-out helpers:
- `pushToUsers()` — calls `sendFcm()`
- `pushDataOnlyToUsers()` — calls `sendDataOnlyFcm()`

Three modes inside the function:
- **Mode A (status change):** fans out to customer + partner + assigned driver.
  - Partner gets **data-only FCM** (`pushDataOnlyToUsers`) when `status === 'pending'` OR `status === 'confirmed'` — both trigger the `type: 'new_order'` alarm payload so the Flutter background handler fires regardless of whether the DB trigger fires on INSERT or UPDATE.
  - All other statuses use `pushToUsers()` (standard FCM banner) for both partner and customer.
- **Mode B (driver_fanout/waterfall):** uses `pushDataOnlyToUsers()` with `event: 'offer_to_driver'` data.
- **Mode C (offer_to_driver):** single driver, uses `pushDataOnlyToUsers()` with `event: 'offer_to_driver'` data.

### Partner App Push (`cmandili_partner/lib/core/push/push_service.dart`)

**Channels:**
- `cmandili_orders` — standard, `Importance.high`
- `cmandili_orders_urgent_2` — alarm channel, `Importance.max`, `sound: new_order` (mp3 in `res/raw/`)

**Background handler** (`firebaseMessagingBackgroundHandler`):
- **Must be registered before `runApp()`** in `main.dart` — this is critical. Android wires up the background isolate entrypoint at app startup; registering it after `runApp()` (e.g. in `addPostFrameCallback`) causes all background/terminated FCM messages to be silently dropped.
- Fires when `data['type'] == 'new_order'`
- Shows notification on `cmandili_orders_urgent_2` with:
  - `fullScreenIntent: true` — wakes screen / shows on lock screen
  - `additionalFlags: [4]` — `FLAG_INSISTENT` (repeats sound continuously)
  - `audioAttributesUsage: AudioAttributesUsage.alarm` — bypasses DND/silent
  - `category: AndroidNotificationCategory.alarm`
  - `visibility: NotificationVisibility.public`
  - iOS: `sound: 'new_order.wav'`, `interruptionLevel: InterruptionLevel.critical`
- Uses stable `_kAlarmNotifId = 42` for cancellation

**`cancelOrderAlarm()`** — call after partner accepts/rejects to stop ringing.

**Audio file:** `android/app/src/main/res/raw/new_order.mp3` (Android), `ios/Runner/new_order.wav` (iOS, max 30s). Shared across all 3 apps — same filename everywhere.
**In-app audio (foreground):** `audioplayers` reads from `assets/audio/new_order.mp3` (Flutter asset). This is **separate** from `res/raw/` — both files must exist. The asset is used by `AudioAlertService` for the in-app incoming-order dialog loop.

**AndroidManifest permissions added:** `USE_FULL_SCREEN_INTENT`, `TURN_SCREEN_ON`, `DISABLE_KEYGUARD`.

### Driver App Push (`cmandili_driver/lib/core/push/push_service.dart`)

**Channels:**
- `cmandili_orders` — standard, `Importance.high`
- `cmandili_driver_alarm` — alarm channel, `Importance.max`, `AudioAttributesUsage.alarm`, `sound: driver_alarm` (mp3 in `res/raw/`)

**Background handler** (`firebaseMessagingBackgroundHandler`):
- Fires when `data['event'] == 'offer_to_driver'`
- Shows notification on `cmandili_driver_alarm` with:
  - `fullScreenIntent: true` — call-style screen wake
  - `additionalFlags: [4]` — `FLAG_INSISTENT`
  - `audioAttributesUsage: AudioAttributesUsage.alarm`
  - `ongoing: true` — **cannot be swiped away** (driver must open app to respond)
  - `autoCancel: false`
  - `category: AndroidNotificationCategory.call`
  - `visibility: NotificationVisibility.public`
  - iOS: `sound: 'driver_alarm.wav'`, `interruptionLevel: InterruptionLevel.critical`
- Uses stable `kDriverAlarmNotifId = 101` for cancellation

**Foreground handler** also emits on `offerStream` (StreamController) → home screen shows accept/reject modal.

**`cancelDeliveryAlarm()`** — called at the **very first line** of `_acceptOrder()` in `available_orders_screen.dart` to stop ringing immediately when the driver responds.

**`OrderOffer` class:** `{ orderId: String, receivedAt: DateTime }` — emitted on `offerStream`.

**Audio file:** `android/app/src/main/res/raw/new_order.mp3` (Android), `ios/Runner/new_order.wav` (iOS). Same filename as the partner app — standardized across all 3 apps.

**AndroidManifest permissions added:** `VIBRATE`, `USE_FULL_SCREEN_INTENT`, `TURN_SCREEN_ON`, `DISABLE_KEYGUARD`.

### Mobile App Push (`cmandili_mobile/lib/core/push/push_service.dart`)

**Channels:**
- `cmandili_orders` — standard, `Importance.high`
- `cmandili_orders_urgent` — `Importance.max` for `onTheWay`/`pickedUp` status

Standard FCM with `notification` block — system renders banners. Background handler is a no-op (system handles display).

---

## 13. Partner Dashboard & Orders — UI and Business Logic

### Order card UI (Dashboard + Orders tab)
Both `home_screen.dart` → `_buildOrderCard()` and `partner_orders_screen.dart` → `_OrderCard` show:
- **Thumbnail (52×52):** `CachedNetworkImage` of the first cart item's image URL, with a `CircularProgressIndicator` placeholder and shopping-bag fallback icon (`_itemFallback()`).
- **Title:** `firstItem.displayName` (includes variant suffix if selected) + `"+ N item(s)"` overflow if multiple items.
- **Fallback title:** `#${order.id.substring(0, 8).toUpperCase()}` if `order.items` is empty.

Data source: `order_items(*, food_items(*), grocery_items(*))` join — already fetched by `getPartnerOrders()`. No additional DB query needed.

**Critical bug fixed in `CartItem.fromJson` (partner app):**
`_parseOrderItems` in the repository maps item images using camelCase key `'imageUrl'`. The `CartItem.fromJson` was reading `food['image_url']` (snake_case) → always `''`. Fixed to `food['imageUrl']` and `grocery['imageUrl']`.

### Order Business Logic — Pending → Confirmed flow
**The client never confirms their own order.** `cmandili_mobile` inserts orders with `status: 'pending'` only. The `confirmOrder()` call was removed from `checkout_screen.dart`. The full FSM is now:

```
pending  ──(partner Accepter)──▶  confirmed  ──▶  preparing  ──▶  ready  ──▶  pickedUp  ──▶  onTheWay  ──▶  delivered
   └──(partner Refuser + Oui)──▶  cancelled
```

### Incoming Order Dialog (`incoming_order_dialog.dart`)
**File:** `cmandili_partner/lib/features/orders/presentation/incoming_order_dialog.dart`

Triggered the instant a new `pending` order appears in the realtime stream. The dialog is:
- **Shown from `_HomeScreenState`** via `ref.listen<AsyncValue<List<Order>>>(partnerOrdersStreamProvider, ...)`.
- **Deduped** using `_shownPendingIds = Set<String>` — each order ID triggers the dialog at most once per session, preventing duplicates on stream reconnect.
- **Displayed via `addPostFrameCallback`** — safe to call during `build()`.
- **`barrierDismissible: false`** — partner cannot dismiss by tapping outside.

**Dialog content:** gradient header with bell icon, item thumbnail + order title, total, payment method, customer name, notes.

**Audio:** `AudioAlertService` (`audioplayers`, looping `assets/audio/new_order.mp3`) is already started by `orderAlertProvider` when pending orders exist. The dialog calls `stopAlert()` proactively on user action for immediate silence.

**Actions:**
- **Accepter** → `stopAlert()` + `updateOrderStatus(confirmed)` + `Navigator.pop()`
- **Refuser** → secondary `AlertDialog` ("Êtes-vous sûr ?"):
  - **Oui** → `stopAlert()` + `updateOrderStatus(cancelled)` + pop both dialogs
  - **Non** → pop confirmation only → back to main dialog (audio keeps playing)

---

## 14. AI Integrations

### Mobile AI Chat
**Endpoint:** `POST https://openrouter.ai/api/v1/chat/completions`
**Model:** `dotenv['OPENROUTER_CHAT_MODEL'] ?? 'google/gemini-2.0-flash-001'`
**Trilingual:** FR / EN / Derja (Tunisian dialect) auto-detected.
**Response schema:** `{ message, intent, category, keyword, spicy, vegetarian, max_price, min_price, delivery_time }`
**Voice STT:** Android MethodChannel `com.cmandili.mobile/speech` → Kotlin `SpeechRecognizer`.
**Image vision:** base64 encoded via `image_picker` → OpenRouter vision content part.

### Partner AI Menu Scanner
**Same OpenRouter endpoint.** Partner photographs physical menu → LLM extracts item array → `Future.wait(inserts)` bulk-inserts into `food_items` or `grocery_items`. JSON parsing is defensive (strips fences, handles wrapper objects, regex fallback).

---

## 15. Background GPS (Driver)

**Service:** `BackgroundLocationService` (`flutter_background_service`) — Android foreground service, separate isolate.
**Settings:** `accuracy: high, distanceFilter: 30m`
**Writes every position update:**
```dart
drivers.update({ current_lat, current_lng, last_location_update }).eq('id', driverId)
deliveries.update({ current_lat, current_lng, updated_at }).eq('id', deliveryId)  // if active
```
**Lifecycle:** `startOnlinePresence(driverId)` → `startTracking(driverId, deliveryId)` → `stopTracking()`.

---

## 16. Completed Features

### cmandili_mobile
- Email/Password + Google + Apple auth with post-auth phone gate
- Trilingual UI (EN/FR/AR), dark/light theme — both persisted to SharedPreferences
- Restaurant list → restaurant detail → food menu (with variants dialog)
- Supermarket list → supermarket detail → grocery catalog
- Cart: add/remove/qty, per-item text or voice customization, variant selection
- **Checkout:** address selection, Mapbox distance calc, dynamic delivery fee (3.5 + 0.5/km), COD payment. Order inserted as `pending` — partner must accept before it becomes `confirmed`.
- Voice note per order item → uploaded to `voice-messages` bucket at checkout
- Order placement → real-time tracking (Supabase Realtime + Mapbox)
- Order history
- Happy Hour: time-limited discount items feed
- Favorites, Profile (photo upload), saved addresses, payment methods
- FCM push notifications (standard + `onTheWay`/`pickedUp` urgent channel)
- AI Chat Assistant — trilingual NLP, food/shop search, image vision, voice STT, P2P delivery card
- Courier/P2P screen, Bill payment screen
- **Promo Code System** — single-use codes, dry-run preview, atomic commit, server-side discount
- **Platform Pricing** — 10% markup on all items; `lib/core/utils/platform_pricing.dart`
- **Forgot Password** — 8-digit OTP flow (`ForgotPasswordScreen` → `ResetPasswordScreen`)

### cmandili_driver
- Email/Password + Google auth with post-auth vehicle registration gate
- Online/Offline toggle (DB + background service lifecycle)
- Background GPS foreground service (30m filter, separate isolate)
- Real-time available orders feed
- Order accept → active delivery tracking → Mapbox navigation
- Delivery history + earnings screen
- **FCM push: alarm-style delivery offers** — data-only FCM → background handler → `cmandili_driver_alarm` channel with `fullScreenIntent`, `FLAG_INSISTENT`, `ongoing: true`, `cancelDeliveryAlarm()` on accept
- **Forgot Password** — 8-digit OTP flow

### cmandili_partner
- Auth + partner onboarding
- Real-time incoming orders dashboard with **item image + name on order cards**
- Menu CRUD (food + grocery), availability toggle, variants CRUD
- Happy Hour setup
- AI Menu Scanner (camera → OpenRouter Vision → bulk insert)
- Order detail with customer voice note playback
- Order tracking (Mapbox), reports/analytics, payout, business info screens
- **FCM push: alarm-style new orders** — data-only FCM → background handler registered **before `runApp()`** → `cmandili_orders_urgent_2` channel with `fullScreenIntent`, `FLAG_INSISTENT`, `AudioAttributesUsage.alarm`
- **Incoming Order Dialog** — `IncomingOrderDialog` shown on every new `pending` order via `ref.listen` in `HomeScreen`; loops `new_order.mp3` via `audioplayers`; Accept → `confirmed`, Reject → confirmation sub-dialog → `cancelled`
- **Item image + name on all order cards** — both Dashboard and Commandes tab show `CachedNetworkImage` thumbnail + `firstItem.displayName`
- **Forgot Password** — 8-digit OTP flow

---

## 17. Coding Rules for Future Sessions

### 1. Supabase import alias — always prefix
All 3 apps import supabase with `as supabase`. **Always** use the prefix for types:
```dart
// ✅ Correct
supabase.OtpType.recovery
supabase.UserAttributes(password: newPassword)
supabase.OAuthProvider.google

// ❌ Wrong — will cause "getter isn't defined" compile errors
OtpType.recovery
UserAttributes(password: newPassword)
```

### 2. Prefer pure Flutter/Dart over heavy native packages
Before adding a new package, check if the goal is achievable with existing ones. Examples:
- **Alarm-style notifications:** `flutter_local_notifications` with `AudioAttributesUsage.alarm` + `fullScreenIntent` + `FLAG_INSISTENT` — no need for `awesome_notifications` or `flutter_callkit_incoming`.
- **Password reset:** Supabase OTP (`verifyOTP` + `updateUser`) — no need for deep link packages.
- **Distance:** `Geolocator.distanceBetween()` (Haversine) as fallback — no dedicated geo package.

### 3. FCM — data-only for alarm events
When a push must trigger custom Flutter code (custom sound, full-screen intent, alarm channel):
- Send **data-only** FCM (no `notification` block) from the Edge Function.
- The Flutter `firebaseMessagingBackgroundHandler` will fire.
- The handler re-inits `flutter_local_notifications` and shows the custom notification.
- If `notification` block is present, the **system** renders it and Flutter's handler is bypassed.

### 4. OTP for auth flows, not deep links
For any mobile OTP/magic-link feature: use Supabase's `verifyOTP()` with the 8-digit token from the email. Deep links require `AndroidManifest` intent-filters + iOS `Info.plist` associated domains — too much native config for 3 apps.

### 5. Delivery fee — never use restaurant.delivery_fee as the base
The delivery fee base is a **platform constant** (`kDeliveryBaseFee = 3.5`). The `restaurants.delivery_fee` column is no longer read in checkout or cart. Only `latitude` and `longitude` are fetched from the restaurant/supermarket row.

### 6. Platform pricing — clientPrice, not price
In `cmandili_mobile`, **never display `foodItem.price` directly** to the customer. Always use `foodItem.clientPrice` (or `applyPlatformMarkup()` for variants). The partner app reads/writes `price` raw.

### 7. CartItem image key is camelCase
`_parseOrderItems()` in `partner_order_repository.dart` stores item data with camelCase keys (`'imageUrl'`, NOT `'image_url'`). When reading in `CartItem.fromJson`, use `food['imageUrl']` and `grocery['imageUrl']`.

### 8. Alarm notification cancellation
Whenever the driver accepts an offer or the partner acknowledges a new order, **cancel the alarm notification immediately** to stop continuous ringing:
- Driver: `PushService.instance.cancelDeliveryAlarm()` — first line of `_acceptOrder()`
- Partner: `PushService.instance.cancelOrderAlarm()` — call when partner accepts/confirms

### 9. FCM background handler — register before `runApp()`
`FirebaseMessaging.onBackgroundMessage(handler)` **must** be called before `runApp()` in `main()`. Android wires up the background Dart isolate entrypoint at launch time. If it is called later (e.g. in `addPostFrameCallback` or inside a service's `initialize()`), the plugin never registers it and all background/terminated-state data-only FCM messages are silently dropped — the alarm never fires. The rest of push init (token fetch, foreground listener) can remain deferred.

```dart
// ✅ Correct — in main(), before runApp()
FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
runApp(...);

// ❌ Wrong — too late, Android has already started
WidgetsBinding.instance.addPostFrameCallback((_) {
  FirebaseMessaging.onBackgroundMessage(...); // never wired up
});
```

### 10. Partner incoming-order dialog — deduplication pattern
When showing a dialog reactively from a Riverpod stream listener, always guard with a `Set<String>` of already-shown IDs and use `addPostFrameCallback` to avoid calling `showDialog` during a build pass:

```dart
final Set<String> _shownPendingIds = {};

ref.listen(partnerOrdersStreamProvider, (_, next) {
  next.whenData((orders) {
    for (final order in orders) {
      if (order.status == OrderStatus.pending && !_shownPendingIds.contains(order.id)) {
        _shownPendingIds.add(order.id);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showDialog(...);
        });
      }
    }
  });
});
```

### 11. Two separate audio systems in the partner app
- **`flutter_local_notifications`** + `RawResourceAndroidNotificationSound('new_order')` → reads `android/app/src/main/res/raw/new_order.mp3` → used for **background/terminated FCM** alarm notifications.
- **`audioplayers`** + `AssetSource('audio/new_order.mp3')` → reads `assets/audio/new_order.mp3` (declared in `pubspec.yaml`) → used for **foreground in-app** audio in `IncomingOrderDialog`.

Both files must exist. They serve different subsystems and cannot substitute for each other.

### 12. Standard coding conventions
- **Repository error handling:** always `try/catch`, log with `debugPrint`, return `null`/`[]`/`false`. Only `createOrder` rethrows.
- **Responsive sizing:** `MediaQuery.of(context).size.width * 0.04` — never hardcoded pixels.
- **Snackbar:** `behavior: SnackBarBehavior.floating`, `shape: RoundedRectangleBorder(borderRadius: 12)`.
- **Async UI state:** always `.when(data:, loading:, error:)` on providers.
- **Parallel init:** `Future.wait([...])` — never sequential `await` for independent operations.
- **Deferred init:** push service + background service always in `addPostFrameCallback`.

---

## 18. Environment Variables

| Key | Apps | Notes |
|-----|------|-------|
| `SUPABASE_URL` | all | Supabase project URL |
| `SUPABASE_ANON_KEY` | all | Public anon key |
| `MAPBOX_PUBLIC_TOKEN` | all | `pk.*` — safe to ship |
| `OPENROUTER_API_KEY` | mobile, partner | `sk-or-v1-*` — **extractable from APK. Set spending cap.** |
| `OPENROUTER_CHAT_MODEL` | mobile | Mobile reads this key (not `OPENROUTER_MODEL`) |
| `OPENROUTER_MODEL` | partner | Partner reads this key |

**Supabase Edge Function secrets** (set via `supabase secrets set`):
- `SERVICE_ROLE_KEY` — service role JWT (NOT `SUPABASE_*` prefix — reserved)
- `FCM_SERVICE_ACCOUNT_JSON` — Firebase service account JSON, **base64-encoded**
- `DRIVER_FANOUT_RADIUS_KM` — optional, default 7

---

## 19. Android Permissions Summary

### cmandili_mobile
`INTERNET · ACCESS_FINE_LOCATION · ACCESS_COARSE_LOCATION · RECORD_AUDIO · CAMERA · READ_MEDIA_IMAGES · WRITE_EXTERNAL_STORAGE(≤32) · READ_EXTERNAL_STORAGE(≤32) · RECEIVE_BOOT_COMPLETED · POST_NOTIFICATIONS · WAKE_LOCK · VIBRATE`

### cmandili_driver
`ACCESS_FINE_LOCATION · ACCESS_COARSE_LOCATION · ACCESS_BACKGROUND_LOCATION · FOREGROUND_SERVICE · FOREGROUND_SERVICE_LOCATION · POST_NOTIFICATIONS · WAKE_LOCK · RECEIVE_BOOT_COMPLETED · INTERNET · VIBRATE · USE_FULL_SCREEN_INTENT · TURN_SCREEN_ON · DISABLE_KEYGUARD`

### cmandili_partner
`POST_NOTIFICATIONS · INTERNET · WAKE_LOCK · VIBRATE · USE_FULL_SCREEN_INTENT · TURN_SCREEN_ON · DISABLE_KEYGUARD`

---

## 20. Known Issues / Outstanding Work

1. **iOS audio files** — copy `new_order.wav` to `cmandili_driver/ios/Runner/` and `cmandili_mobile/ios/Runner/` (max 30s). Android `new_order.mp3` is already present in all 3 apps' `res/raw/` directories. **Important:** Android's `res/raw/` directory rejects any file whose name contains uppercase letters, spaces, or non-underscore symbols — never place README/placeholder files there.

2. **Partner in-app audio asset** — copy `new_order.mp3` to `cmandili_partner/assets/audio/new_order.mp3`. This is the file used by `audioplayers` (`AssetSource`) for the foreground `IncomingOrderDialog` ringtone loop. It is separate from `res/raw/new_order.mp3` (used by FCM notifications). Both must exist.

3. **iOS critical alerts entitlement** — `InterruptionLevel.critical` on iOS requires an Apple-approved entitlement (`com.apple.developer.usernotifications.critical-alerts`). Without it iOS treats these as regular alerts. Apply at developer.apple.com → Certificates, IDs & Profiles.

4. **Supabase Realtime — enable on `orders` table** — Supabase Realtime must be explicitly enabled for the `orders` table: Dashboard → Database → Replication → toggle `orders` ON. Without this, the partner's stream subscription never fires for new inserts/updates.

5. **Partners RLS policy on `orders`** — the `orders` table needs a policy allowing partners to read orders for their own entity. Run once in Supabase SQL Editor:
   ```sql
   CREATE POLICY "Partners can read their own entity orders"
   ON orders FOR SELECT
   USING (
     restaurant_id IN (
       SELECT entity_id FROM partners WHERE user_id = auth.uid() AND partner_type = 'restaurant'
     )
     OR
     supermarket_id IN (
       SELECT entity_id FROM partners WHERE user_id = auth.uid() AND partner_type = 'supermarket'
     )
   );
   ```

6. **Restaurant name missing on driver's available-orders list** — `availableOrdersProvider` streams raw `orders` without a `restaurants` join; `restaurantName` is always `''`. Fix: add restaurant name to the `orders_with_customer` view or enrich the stream with a secondary query.

7. **OpenRouter API key exposed in git** (commit d74ede3) — rotate at openrouter.ai and set a spending cap.

8. **Promo code SQL migration** — `cmandili_mobile/supabase_promo_migration.sql` must be run once in the Supabase SQL editor before the promo code feature is live.

9. **`USE_FULL_SCREEN_INTENT` Android 14+** — Google Play requires justification for this permission from API 34+. Declare intended use in the Play Console declaration form.
