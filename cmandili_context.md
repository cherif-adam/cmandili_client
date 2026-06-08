# CMANDILI_CONTEXT.md
> **Purpose:** AI session bootstrap. Read this file at the start of every session to understand the full project and continue immediately without reading every file.
> **Last updated:** 2026-06-08

---

## 1. PROJECT OVERVIEW

| Field | Value |
|---|---|
| **App name** | Amena (formerly Cmandili) |
| **Type** | Food & package delivery platform |
| **Apps** | 3 separate Flutter apps in one monorepo |
| **Backend** | Supabase (PostgreSQL + Auth + Storage + Edge Functions) |
| **Notifications** | Firebase FCM |
| **Maps** | Mapbox |

### The 3 Apps

| Folder | Role |
|---|---|
| `cmandili_mobile/` | Customer app — browse restaurants, place orders, track delivery |
| `cmandili_driver/` | Driver app — toggle online/offline, accept deliveries, live GPS tracking |
| `cmandili_partner/` | Restaurant/partner app — manage menu, receive and process orders |

All three apps share the **same Supabase project** (same DB, Auth, Storage).

---

## 2. DATABASE STRUCTURE

### `drivers` table
| Column | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key — NOT the same as auth.uid() |
| `user_id` | uuid | FK → auth.users.id (this equals auth.uid()) |
| `is_online` | bool | Driver availability toggle |
| `current_lat` | float | GPS latitude (was stuck at 0 — now fixed) |
| `current_lng` | float | GPS longitude (was stuck at 0 — now fixed) |
| `last_location_update` | timestamptz | Last GPS write timestamp |

> **Critical:** `drivers.id ≠ auth.uid()`. All RLS policies on this table must use `user_id = auth.uid()`, not `id = auth.uid()`.

### `device_tokens` table
| Column | Notes |
|---|---|
| `user_id` | FK → auth.users.id |
| `token` | FCM device token |
| `platform` | `android` / `ios` |

### `restaurants` table
| Column | Notes |
|---|---|
| `id` | Primary key |
| `name` | Restaurant name |
| `partner_id` | FK → partners table |

### `orders` table
| Column | Notes |
|---|---|
| `id` | Primary key |
| `status` | `pending` → `confirmed` → `ready` → `picked_up` → `delivered` / `cancelled` |
| `driver_id` | FK → drivers.id (null until assigned) |
| `assigned_driver_id` | Driver dispatched to this order before acceptance (added in session 2) |
| `assignment_expires_at` | Timestamp when the current driver assignment offer expires (added in session 2) |
| `passed_driver_ids` | Array of driver IDs that already declined/timed out (added in session 2) |
| `distance_km` | Delivery distance in km (added in session 2) |
| `user_id` | Customer's auth.uid() |
| `restaurant_id` | FK → restaurants |
| `delivery_fee` | Dynamic, set at order creation |
| `current_lat / current_lng` | Live driver position mirrored here during active delivery |

---

## 3. COMPLETED FIXES

### Fix 1 — MP3 notification sound
- **Problem:** `new_order.mp3` placed in `android/app/src/main/res/res/` (wrong path).
- **Fix:** Moved to `android/app/src/main/res/raw/new_order.mp3` (correct Android raw resource path).
- **Affected apps:** `cmandili_driver`, `cmandili_partner`

### Fix 2 — Java version
- **Problem:** Build failing due to Java version mismatch.
- **Fix:** Updated `build.gradle.kts` in both driver and partner apps to use Java 17 (`JavaVersion.VERSION_17`).

### Fix 3 — GPS coordinates stuck at 0 when driver goes online
- **Problem:** When driver toggled Online, `current_lat` and `current_lng` stayed 0 in Supabase.
- **Root causes found and fixed (in order of discovery):**

  **3a. `setOnline()` wasn't fetching GPS at all**
  - File: `cmandili_driver/lib/features/orders/providers/driver_online_provider.dart`
  - Fix: Added `LocationService.getCurrentPosition()` call inside `setOnline()` before the Supabase update. GPS coordinates are now included in the update payload when going online.

  **3b. Missing `flutter/foundation.dart` import**
  - `debugPrint` used without the import causing a build failure.
  - Fix: Added `import 'package:flutter/foundation.dart';` at the top of `driver_online_provider.dart`.

  **3c. `getCurrentPosition()` silently returning null (timeout)**
  - File: `cmandili_driver/lib/core/utils/location_service.dart`
  - Problem: `Geolocator.getCurrentPosition(accuracy: high)` blocks for 10–30s on Android, throws `TimeoutException`, which was caught and swallowed as `null`.
  - Fix: Added 8-second timeout. On timeout, falls back to `Geolocator.getLastKnownPosition()` (instant cached GPS). All failures now log the actual exception via `debugPrint`.

  **3d. Missing RLS UPDATE policy on `drivers` table**
  - Problem: No RLS policy allowed authenticated drivers to UPDATE their own row. Supabase silently blocked every write — client sees "success" but nothing is written.
  - Fix: Created and applied migration `supabase/migrations/20260607_drivers_rls_policies.sql`:
    - `drivers_select_own` — `FOR SELECT USING (user_id = auth.uid())`
    - `drivers_update_own` — `FOR UPDATE USING (user_id = auth.uid())`
    - `drivers_insert_own` — `FOR INSERT WITH CHECK (user_id = auth.uid())`
  - Applied directly to production: `supabase db query --linked --file`.

### Fix 4 — Push notifications (FCM)
- Added `CmandiliMessagingService.kt` (custom `FirebaseMessagingService`) to driver and partner apps.
- Added `Application.kt` to both apps to initialize the messaging service.
- Updated `AndroidManifest.xml` in both apps to register the FCM service and notification channel.
- Edge function `push-on-order-status` sends FCM on order status changes.
- Removed 5-minute throttle rule that was suppressing push notifications.
- Added RLS policies so the Edge Function (service role) can read `device_tokens`.

### Fix 5 — Windows Smart App Control blocking dartaotruntime.exe
- **Problem:** Flutter SDK moved from `C:\Users\user\Downloads\flutter_windows_3.41.1-stable` to `C:\flutter`. Windows Smart App Control flagged `dartaotruntime.exe` as an unrecognized executable and blocked it, preventing any Flutter/Dart command from running.
- **Fix:**
  1. Disabled Smart App Control in Windows Security → App & browser control → Smart App Control → Off.
  2. Moved Flutter SDK to `C:\flutter` (final location).
  3. Updated PATH to `C:\flutter\flutter\bin`.

### Fix 6 — Flutter pub cache corrupted after SDK move
- **Problem:** After relocating the Flutter SDK, hundreds of compile errors appeared in cached pub packages (`BinaryMessenger isn't a type`, `MethodChannel isn't a type`, `Widget isn't a type`). These were not app code errors — the pub cache was stale/broken.
- **Fix:** Ran in order:
  ```
  flutter clean
  flutter pub cache repair   → reinstalled 417 packages
  flutter pub get
  ```

### Fix 7 — orders table missing 4 columns for driver dispatch
- **Problem:** `order_repository.dart` and `courier_screen.dart` referenced `assigned_driver_id`, `assignment_expires_at`, `passed_driver_ids`, and `distance_km` but these columns didn't exist in the DB, causing runtime errors.
- **Fix:**
  - Ran migration SQL in Supabase SQL editor to add all 4 columns to the `orders` table.
  - `distance_km` was also referenced in `order_repository.dart` and `courier_screen.dart` but couldn't be populated reliably — removed those specific lines from both files.
- **Affected files:** `cmandili_driver/lib/features/orders/data/order_repository.dart`, `cmandili_mobile/lib/features/courier/presentation/courier_screen.dart`

### Fix 8 — Overflow UI bugs
- **Problem 1:** `SliverAppBar` in driver `home_screen.dart` had `expandedHeight: 180` — content was clipping/overflowing.
- **Fix:** Changed to `expandedHeight: 200`.
- **Problem 2:** Address picker text in `checkout_screen.dart` (mobile app) was overflowing its row.
- **Fix:** Wrapped the address text widget in an `Expanded` widget.
- **Affected files:** `cmandili_driver/lib/features/home/presentation/home_screen.dart`, `cmandili_mobile/lib/features/checkout/presentation/checkout_screen.dart`

### Fix 9 — Restaurant coordinates all 0
- **Problem:** All restaurants had `latitude=0, longitude=0` in the DB, so restaurant map pins were appearing in the ocean.
- **Fix:** Ran in Supabase SQL editor:
  ```sql
  UPDATE restaurants SET latitude=35.6781, longitude=10.0994 WHERE latitude=0;
  ```
  (Sousse, Tunisia coordinates — where the test restaurants are located.)

### Fix 10 — driver_online_provider updating by wrong ID
- **Problem:** `driver_online_provider.dart` was calling `.eq('id', driverId)` (using `drivers.id`) instead of matching on `user_id`. This conflicted with the RLS UPDATE policy which checks `user_id = auth.uid()`, so GPS writes were silently blocked.
- **Fix:** Changed the Supabase update to use `.eq('user_id', userId)` where `userId = supabase.auth.currentUser!.uid`. GPS coordinates now save correctly to Supabase.
- **Affected file:** `cmandili_driver/lib/features/orders/providers/driver_online_provider.dart`

---

## 4. CURRENT STATUS (as of 2026-06-08)

| Feature | Status |
|---|---|
| GPS fix (driver goes online → coordinates saved) | ✅ WORKING |
| Restaurant coordinates | ✅ FIXED (35.6781, 10.0994) |
| orders table columns (4 dispatch columns added) | ✅ FIXED |
| Flutter pub cache | ✅ FIXED (417 packages repaired) |
| Flutter SDK location | `C:\flutter\flutter\bin` |
| Windows Smart App Control | ✅ DISABLED |
| Overflow UI bugs | ✅ FIXED |

**Next step:** Connect phone via USB and run `flutter run` to test full notification flow end to end.

**If GPS coordinates still show 0 in the Supabase dashboard:**
1. Hard-kill and restart the driver app (not just background)
2. Refresh the Supabase dashboard — it can show stale data
3. Confirm the RLS migration applied: run in Supabase SQL editor:
   ```sql
   SELECT policyname, cmd FROM pg_policies WHERE tablename = 'drivers';
   ```
   Should return 3 rows: `drivers_select_own`, `drivers_update_own`, `drivers_insert_own`.

---

## 5. IMPORTANT FILE LOCATIONS

### Driver app (`cmandili_driver/lib/`)
| File | Purpose |
|---|---|
| `features/orders/providers/driver_online_provider.dart` | Online/offline toggle, GPS fetch, Supabase update |
| `features/orders/providers/driver_orders_provider.dart` | `currentDriverIdProvider` — resolves `drivers.id` from `auth.uid()` via `user_id` lookup |
| `core/utils/location_service.dart` | GPS wrapper — `getCurrentPosition()` with 8s timeout + `getLastKnownPosition` fallback |
| `core/services/background_location_service.dart` | Foreground Android service — streams GPS to Supabase every 30 meters while online |
| `features/home/presentation/home_screen.dart` | UI — online toggle calls `setOnline()` |
| `core/push/push_service.dart` | FCM token registration and notification handling |
| `android/app/src/main/kotlin/com/example/food_delivery_app/CmandiliMessagingService.kt` | Custom FCM service for background notifications |
| `android/app/src/main/kotlin/com/example/food_delivery_app/Application.kt` | App entry point, initializes FCM service |

### Partner app (`cmandili_partner/lib/`)
| File | Purpose |
|---|---|
| `core/push/push_service.dart` | FCM token registration and notification handling |
| `android/app/src/main/kotlin/com/example/food_delivery_app/CmandiliMessagingService.kt` | Custom FCM service for background notifications |

### Supabase
| File | Purpose |
|---|---|
| `supabase/migrations/20260607_drivers_rls_policies.sql` | **RLS policies for `drivers` table** (SELECT, UPDATE, INSERT) |
| `supabase/migrations/20260510_assignment_and_distance.sql` | Order assignment + waterfall driver dispatch |
| `supabase/migrations/20260605_dispatch_on_confirmed.sql` | Auto-dispatch trigger when order status → confirmed |
| `supabase/migrations/20260605_fix_new_order_trigger_fallback.sql` | Fallback trigger fix for new order notifications |
| `supabase/functions/push-on-order-status/index.ts` | Edge function — sends FCM push on order status change |

---

## 6. DEVELOPMENT ENVIRONMENT

| Setting | Value |
|---|---|
| **OS** | Windows 11 Pro |
| **Flutter** | 3.41.1 — SDK at `C:\flutter\flutter\bin` |
| **IDE** | VS Code with Claude Code |
| **Test device** | Xiaomi 2201117TG (Android) |
| **Supabase project** | cmandili (production — live data) |
| **Git user** | cherif-adam |
| **Monorepo root** | `C:\Users\user\Desktop\cmandili` |

---

## 7. KEY ARCHITECTURE NOTES

- **Driver ID vs Auth UID:** `drivers.id` is a separate UUID from `auth.uid()`. The auth UID is stored in `drivers.user_id`. `currentDriverIdProvider` resolves this: it queries `drivers WHERE user_id = auth.uid()` to get `drivers.id`, which is what all order/delivery foreign keys reference.
- **Background GPS:** `BackgroundLocationService` runs as a persistent foreground Android service while the driver is online. It streams GPS updates to Supabase (`drivers` and `deliveries` tables) every 30 meters. Started in `setOnline(true)`, stopped in `setOnline(false)`.
- **State management:** All three apps use Riverpod (`flutter_riverpod`).
- **Order lifecycle:** `pending` → (partner confirms) → `confirmed` → (auto-dispatch trigger) → driver assigned → `ready` → (driver picks up) → `picked_up` → `delivered`.
- **RLS pattern for drivers:** Always `user_id = auth.uid()` — never `id = auth.uid()`. This is the most common mistake when writing new policies or queries for this table.
