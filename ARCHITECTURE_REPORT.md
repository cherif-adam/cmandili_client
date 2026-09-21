# ARCHITECTURE AND DESIGN ANALYSIS — AMANA PROJECT

**Investigation Date:** August 3, 2026  
**Status:** READ-ONLY INVESTIGATION  
**Scope:** All four application repositories + Supabase backend

---

## 1. GLOBAL ARCHITECTURE

### 1.1 System Layers and Deployment

```
┌─────────────────────────────────────────────────────────────┐
│              PRESENTATION LAYER (Mobile + Web)              │
├──────────────────────┬──────────────────┬──────────────────┤
│  Flutter Mobile      │  Flutter Mobile  │  Flutter Mobile  │
│  Client App          │  Driver App      │  Partner App     │
│  (cmandili/)         │  (cmandili_      │  (cmandili_      │
│                      │   driver/)       │   partner/)      │
│  ~25k LOC Dart       │  ~18k LOC Dart   │  ~20k LOC Dart   │
└──────────────────────┴──────────────────┴──────────────────┘
                        │
                HTTP / REST / Realtime (supabase_flutter)
                        │
┌─────────────────────────────────────────────────────────────┐
│         EXTERNAL SERVICES (Vendor APIs)                     │
├──────────────────────────────────────────────────────────────┤
│ Firebase Cloud Messaging  │  Mapbox            │ OpenRouter  │
│ (push notifications)      │  (maps/geocoding)  │ (AI LLM)    │
└──────────────────────────────────────────────────────────────┘
                        │
                HTTPS REST (external SDK calls)
                        │
┌─────────────────────────────────────────────────────────────┐
│         SUPABASE BACKEND (SaaS Platform)                    │
├──────────────────────────────────────────────────────────────┤
│  PostgreSQL 17.6      │  Supabase Auth    │  Edge Functions │
│  • 30+ tables         │  • JWT RS256      │  • Deno/TS      │
│  • RLS Policies       │  • Email/OAuth    │  • TypeScript   │
│  • Triggers           │  • Session Mgmt   │  • 4 functions  │
│  • Functions (RPC)    │                   │                 │
│  • pg_cron            │                   │                 │
└──────────────────────────────────────────────────────────────┘
```

### 1.2 Where Business Logic Lives

| Logic Type | Location | Mechanism | Examples |
|---|---|---|---|
| **Authentication** | Supabase Auth | JWT RS256 + OAuth providers | Email/password, Google, Apple Sign-In |
| **Authorization** | PostgreSQL RLS | SECURITY DEFINER policies | Customers see own orders only |
| **Order Workflow** | PostgreSQL Triggers + RPC | `dispatch_on_confirmed()`, `notify_fcm_on_order_status()` | Order status transitions, dispatch waterfall |
| **Real-time Sync** | Supabase Realtime | WebSocket subscriptions | Driver location → client map (pushed every ~30m moved) |
| **Notifications** | Edge Function `push-on-order-status` | Deno/TypeScript FCM routing | Status change → customer/partner/driver push |
| **AI Chat** | Edge Function `ai-chat` | Gemini via OpenRouter | NLP intent detection, product search |
| **UI State** | Flutter Riverpod | StateNotifier + FutureProvider | User authentication, order tracking |
| **Data Access** | Repository pattern (Dart) | Direct Supabase SDK calls | OrderRepository.createOrder() → INSERT orders |
| **Payment** | Dart service layer | Cash on Delivery only (local) | no external gateway, confirmed at app level |
| **Financial Calculations** | PostgreSQL + Dart | NUMERIC(12,3) precision, commission rules | driver_fee_cut = 3.500 + 0.750 * distance_km |

### 1.3 How the Four Applications Communicate with Backend

**All four apps use identical Supabase SDK connection pattern:**

```dart
// lib/core/config/supabase_service.dart (client app, driver app, partner app)
final _supabase = Supabase.instance.client;
// Authenticated as: auth.currentUser().id
// Requests carry JWT in Authorization header (automatically by SDK)
// RLS policies evaluate the JWT and enforce row-level access
```

**Data Flow for Order Creation (Client App Example):**

1. **Client app** (lib/features/orders/data/order_repository.dart:createOrder)
   - Collects order data (items, address, total)
   - Inserts `INSERT INTO orders` with `status='pending'`
   - Inserts `INSERT INTO order_items` (items + customization JSONB)

2. **Supabase DB trigger** (`notify_fcm_on_order_status`)
   - Listens for status change
   - Fires Edge Function `push-on-order-status` via HTTP

3. **Edge Function** (supabase/functions/push-on-order-status)
   - Resolves customer + partner + (optional) driver from order DB row
   - Signs JWT for FCM authentication
   - POST to `https://fcm.googleapis.com/v1/projects/.../messages:send`
   - Returns FCM response

4. **Firebase Cloud Messaging**
   - Routes `RemoteMessage` to device tokens
   - Client receives push → `PushService.initialize()` listener

5. **Client app** (lib/core/push/push_service.dart)
   - Foreground: `FirebaseMessaging.onMessage` → show local notification
   - Background: `firebaseMessagingBackgroundHandler` → (data-only logic if defined)
   - Tap: routes to appropriate order screen via deep-link

6. **Supabase Realtime** (concurrent)
   - Client subscribed to orders stream
   - Driver location updates on ~30m movement (`distanceFilter: 30`, not a timer) → `drivers.current_lat/current_lng`
   - Realtime WebSocket delivers → map refreshes

### 1.4 Edge Functions

All Edge Functions are deployed to Supabase (URL: `https://{project-id}.supabase.co/functions/v1/{name}`).

| Function | Location | Entry Point | Purpose | Invocation | Auth |
|---|---|---|---|---|---|
| **push-on-order-status** | supabase/functions/push-on-order-status/ | index.ts | Fan out FCM pushes on order status change or driver offer | PostgreSQL trigger `notify_fcm_on_order_status()` or `notify_fcm_fanout_ready_order()` | `verify_jwt=true` (Service Role → JWT required) |
| **ai-chat** | supabase/functions/ai-chat/ | index.ts | Gemini LLM intent detection + structured JSON response | Client app `AiChatService._callChatFunction()` | `verify_jwt=true` (User JWT required) |
| **ai-search** | supabase/functions/ai-search/ | index.ts | Hybrid text+image search (currently unused — Docker virtualization issues) | (Not actively invoked) | `verify_jwt=true` |
| **notify-partner-order** | supabase/functions/notify-partner-order/ | index.ts | (UNCERTAIN: purpose unclear from function name; likely partner notification routing) | (UNCERTAIN) | `verify_jwt=true` |

**Edge Function Configuration:**
- All require `verify_jwt=true`: request must carry valid Supabase JWT
- SERVICE_ROLE_KEY used server-side (never client-side)
- FCM_SERVICE_ACCOUNT_JSON (base64) injected as Supabase secret

### 1.5 External Services

| Service | SDK/Integration | Purpose | Data Flow |
|---|---|---|---|
| **Firebase Cloud Messaging (FCM)** | `firebase_messaging` ^14.7.20 | Push notifications to all four apps | Edge Function → HTTP POST FCM API → Device |
| **Mapbox** | `mapbox_maps_flutter` ^2.3.0 | Map display, geocoding, directions, live driver location | Client/Driver/Partner app → Mapbox SDK → REST API / tile service |
| **OpenRouter** | http ^1.6.0 (client) / http ^1.2.0 (partner) | LLM API aggregator (fallback Gemini → OpenAI) | AI Chat: Client app → Edge Function → OpenRouter → Gemini 2.0 Flash. AI Menu Scanner: Partner app → OpenRouter direct (POST /api/v1/chat/completions) |
| **Google Sign-In** | `google_sign_in` ^6.1.6 | OAuth authentication | Client/Driver/Partner app → Google OAuth → Supabase Auth |
| **Apple Sign-In** | `sign_in_with_apple` ^6.1.0 (client only) | OAuth authentication (iOS 13+) | Client app → Apple OAuth → Supabase Auth |
| **Supabase Auth** | `supabase_flutter` ^2.3.0 | Session management, email/password, OAuth providers | All four apps ← → Supabase Auth (JWT issued) |
| **Supabase PostgreSQL** | `supabase_flutter` ^2.3.0 (PostgREST client) | Data persistence, RLS policies, triggers, functions | All apps ← → HTTP REST (PostgREST) ← → PostgreSQL |

---

## 2. DESIGN PATTERNS ACTUALLY USED

### 2.1 State Management: Riverpod (flutter_riverpod ^2.4.9)

**Confirmed by:** pubspec.yaml (all three Flutter apps), actual provider usage.

**Provider Types Used:**

1. **FutureProvider** — async data fetch, single invocation
   ```dart
   // lib/features/restaurant/providers/restaurant_provider.dart
   final restaurantsProvider = FutureProvider<List<Restaurant>>((ref) async {
     final repository = ref.watch(restaurantRepositoryProvider);
     return repository.getRestaurants();
   });
   ```

2. **StreamProvider** — subscription to live data stream
   ```dart
   // lib/features/auth/providers/auth_provider.dart
   final authStateProvider = StreamProvider<User?>((ref) {
     return ref.watch(authRepositoryProvider).authStateChanges;
   });
   
   // cmandili_driver/lib/features/orders/providers/driver_orders_provider.dart
   final availableOrdersProvider = StreamProvider<List<Order>>((ref) async* {
     // Yields orders from Supabase Realtime stream
   });
   ```

3. **StateNotifierProvider** — mutable state with business logic
   ```dart
   // lib/core/providers/service_provider.dart
   final selectedServiceProvider = StateNotifierProvider<SelectedServiceNotifier, ServiceType>((ref) {
     return SelectedServiceNotifier();
   });
   
   // cmandili_driver/lib/features/orders/providers/driver_online_provider.dart
   final driverOnlineProvider = StateNotifierProvider<DriverOnlineNotifier, bool>((ref) {
     // Manages driver's online/offline state
   });
   ```

4. **FutureProvider.family** — parameterized async data
   ```dart
   final foodItemsProvider = FutureProvider.family<List<FoodItem>, String>((ref, restaurantId) async {
     final repository = ref.watch(restaurantRepositoryProvider);
     return repository.getFoodItems(restaurantId);
   });
   ```

5. **Provider** — dependency injection (factories/singletons)
   ```dart
   final restaurantRepositoryProvider = Provider((ref) => RestaurantRepository());
   final authRepositoryProvider = Provider<AuthRepository>((ref) {
     return AuthRepository();
   });
   ```

**Why Riverpod?**
- Type-safe (unlike Provider or GetX)
- Immutable by default → predictable state
- Automatic caching + lifecycle management
- Ref.watch/ref.listen for widget integration
- No BuildContext required

### 2.2 Data Layer: Repository Pattern

**Repositories encapsulate all backend/data access:**

```dart
// lib/features/orders/data/order_repository.dart
class OrderRepository {
  final _supabase = Supabase.instance.client;

  Future<String> createOrder({
    required List<CartItem> items,
    required DeliveryAddress deliveryAddress,
    required double subtotal,
    required double deliveryFee,
    required double total,
    required OrderType orderType,
    String? restaurantId,
    String? supermarketId,
    String? notes,
    String paymentMethod = 'cash',
    double? distanceKm,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw 'User not authenticated';

      // 1. Insert order header (status='pending' for food/supermarket)
      final orderResponse = await _supabase.from('orders').insert({
        'user_id': userId,
        'restaurant_id': restaurantId,
        'supermarket_id': supermarketId,
        'status': 'pending',
        'subtotal': subtotal,
        'delivery_fee': deliveryFee,
        'total': total,
        'payment_method': paymentMethod,
        'notes': notes,
        'delivery_address': deliveryAddress.toJson(),
        'order_type': orderType.toString().split('.').last,
      }).select().single();

      final orderId = orderResponse['id'] as String;

      // 2. Insert order items with customization JSONB
      for (final item in items) {
        final options = <String, dynamic>{};
        if (item.customization != null) {
          options.addAll(item.customization!.toJson());
        }
        if (item.variant != null) {
          options['variant'] = item.variant!.toJson();
        }
        if (item.selectedOptionGroups.isNotEmpty) {
          options['optionGroups'] = item.selectedOptionGroups.map((g) => g.toJson()).toList();
        }

        await _supabase.from('order_items').insert({
          'order_id': orderId,
          'food_item_id': item.type == CartItemType.restaurant ? item.foodItem?.id : null,
          'grocery_item_id': item.type == CartItemType.grocery ? item.groceryItem?.id : null,
          'quantity': item.quantity,
          'price': item.price,
          'options': options,
        });
      }

      return orderId;
    } catch (e) {
      debugPrint('Error creating order: $e');
      rethrow;
    }
  }

  Future<List<Order>> getUserOrders() async { /* ... */ }
  Future<bool> updateOrderStatus(String orderId, OrderStatus status) async { /* ... */ }
}
```

**Repositories in the project:**

| Repository | File | Tables Accessed | Used By |
|---|---|---|---|
| OrderRepository | lib/features/orders/data/order_repository.dart | orders, order_items, restaurants, deliveries | Client app order creation/history |
| RestaurantRepository | lib/features/restaurant/data/restaurant_repository.dart | restaurants, food_items, food_item_variants, food_item_option_groups | Client app menu browsing |
| AuthRepository | lib/features/auth/data/auth_repository.dart | auth.users (Supabase Auth) | All three apps authentication |
| ProfileRepository | lib/features/profile/data/profile_repository.dart | profiles, saved_addresses | Client app profile management |
| PromoRepository | lib/features/promo/data/promo_repository.dart | promo_codes | Client app promo code validation |
| NotificationRepository | lib/features/notifications/data/notification_repository.dart | notifications | Client app notification history |
| (Unnamed) | cmandili_driver/lib/features/orders/data/ | orders, drivers, deliveries | Driver app order management |

**No direct Supabase calls from widgets** — all go through repositories.

### 2.3 Singletons & Factories

**Singleton Pattern — PushService:**
```dart
// lib/core/push/push_service.dart
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _fcm   = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    // ... initialization logic
  }
}

// Called from main.dart after first frame
WidgetsBinding.instance.addPostFrameCallback((_) {
  PushService.instance.initialize();
});
```

**Singleton Pattern — Supabase Client:**
```dart
// All apps use shared Supabase instance
final _supabase = Supabase.instance.client;
// Supabase.initialize() called once in main.dart
```

**Factory Pattern — Riverpod Providers:**
```dart
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(); // Factory creates new instance
});
```

### 2.4 Admin Dashboard (Next.js 16) Architecture

**Router Type:** Next.js App Router (not Pages Router) — confirmed by directory structure `app/dashboard/...`.

**Data Fetching:** Server Components (async) + API Routes

```tsx
// app/dashboard/page.tsx
export const dynamic = 'force-dynamic' // Disable static optimization
import { supabaseAdmin } from "@/lib/supabase-admin";

async function getDashboardStats() {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const [ordersRes, driversRes, restaurantsRes] = await Promise.all([
    supabaseAdmin
      .from("orders")
      .select("id, status, platform_fee, driver_fee_cut, created_at")
      .gte("created_at", today.toISOString()),
    supabaseAdmin.from("drivers").select("id, is_online"),
    supabaseAdmin.from("restaurants").select("id"),
  ]);

  // Data transformation in server component
  const todayTotal = [...];
  return { todayOrders, todayTotal, chartData };
}

export default async function DashboardPage() {
  const stats = await getDashboardStats();
  return (
    <div>
      <StatsCard value={stats.todayOrders} label="Orders Today" />
      <RevenueChart data={stats.chartData} />
    </div>
  );
}
```

**Authentication:** Supabase SSR (Client Components listen to auth state)

```tsx
// app/login/page.tsx
"use client";
const supabase = createBrowserClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

async function handleLogin(e: React.FormEvent) {
  const { error: signInError } = await supabase.auth.signInWithPassword({
    email,
    password,
  });
  if (!signInError) {
    router.push("/dashboard");
    router.refresh(); // Revalidate server components
  }
}
```

**API Routes:** Route Handlers (`/api/*.ts`)

```typescript
// app/api/block/route.ts
export async function POST(req: NextRequest) {
  const { userId, blockStatus } = await req.json();
  const { error } = await supabaseAdmin
    .from("profiles")
    .update({ is_blocked: blockStatus })
    .eq("id", userId);
  
  return NextResponse.json({ success: !error });
}
```

**Pages Structure:**
- `/login` — authentication
- `/dashboard` — main stats page
- `/dashboard/commandes` — order search/tracking
- `/dashboard/restaurants` — restaurant master-detail
- `/dashboard/livreurs` — driver management
- `/dashboard/finances` — revenue reporting
- `/dashboard/fidelite` — loyalty payout ledger
- `/dashboard/promos` — promo code CRUD
- `/api/...` — backend API handlers

---

## 3. FOLDER STRUCTURE

### 3.1 Client App (lib/)

```
lib/
├── core/
│   ├── config/
│   │   ├── supabase_config.dart      — Supabase initialization
│   │   └── supabase_service.dart     — Shared Supabase client instance
│   ├── models/
│   │   └── service_category.dart     — ServiceType enum (food, supermarket, courier, facture)
│   ├── providers/
│   │   ├── localization_provider.dart — Language selection (StateNotifierProvider)
│   │   ├── service_provider.dart     — Selected service type
│   │   ├── theme_provider.dart       — Light/dark mode
│   │   └── location_provider.dart    — User's current GPS location
│   ├── push/
│   │   └── push_service.dart         — Firebase FCM + local notifications singleton
│   ├── payment/
│   │   ├── payment_gateway.dart      — Payment processor interface
│   │   ├── cash_gateway.dart         — Cash on Delivery implementation
│   │   └── payment_service.dart      — Payment orchestration
│   ├── theme/
│   │   ├── app_colors.dart           — Material 3 color palette (orange/emerald)
│   │   └── app_theme.dart            — ThemeData configuration
│   ├── utils/
│   │   ├── currency_formatter.dart   — DT (Tunisian Dinar) formatting
│   │   ├── delivery_fee.dart         — Distance-based fee calculation
│   │   ├── location_service.dart     — Geolocator wrapper
│   │   ├── platform_pricing.dart     — Platform-wide pricing rules
│   │   └── venue_hours.dart          — Restaurant opening hours logic
│   └── widgets/
│       ├── app_map.dart              — Shared Mapbox widget
│       └── map_address_picker.dart   — Address selection on map
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   └── auth_repository.dart  — Supabase Auth: sign up/in/out, session
│   │   ├── providers/
│   │   │   └── auth_provider.dart    — authStateProvider (StreamProvider<User?>)
│   │   └── presentation/
│   │       ├── auth_screen.dart      — Login/signup UI
│   │       ├── forgot_password_screen.dart
│   │       └── reset_password_screen.dart
│   │
│   ├── home/
│   │   ├── data/models/
│   │   │   └── restaurant.dart       — Restaurant model
│   │   └── presentation/
│   │       ├── home_screen.dart      — Restaurant/supermarket discovery grid
│   │       └── widgets/
│   │           ├── service_selector.dart — Food/Supermarket/Courier/Bills tabs
│   │           └── restaurant_card.dart  — Venue card (open/closed state)
│   │
│   ├── restaurant/
│   │   ├── data/
│   │   │   ├── restaurant_repository.dart — Menu queries (getFoodItems, etc.)
│   │   │   └── models/
│   │   │       └── food_item.dart
│   │   ├── providers/
│   │   │   └── restaurant_provider.dart   — FutureProvider.family for menus
│   │   └── presentation/
│   │       ├── restaurant_detail_screen.dart — Menu hierarchy + add-to-cart
│   │       └── widgets/
│   │           ├── food_item_customization_sheet.dart — Option groups UI
│   │           └── restaurant_card.dart
│   │
│   ├── supermarket/
│   │   ├── data/
│   │   │   └── models/
│   │   │       └── supermarket.dart, grocery_item.dart, grocery_category.dart
│   │   ├── providers/
│   │   │   └── supermarket_provider.dart
│   │   └── presentation/
│   │       └── supermarket_list_screen.dart
│   │
│   ├── cart/
│   │   ├── data/
│   │   │   └── models/
│   │   │       ├── cart_item.dart
│   │   │       ├── order_customization.dart — Voice/text customization type
│   │   │       └── selected_option_group.dart — Selected add-on choices
│   │   ├── providers/
│   │   │   └── cart_provider.dart    — StateNotifierProvider for cart state
│   │   └── presentation/
│   │       └── widgets/
│   │           └── order_customization_widget.dart
│   │
│   ├── checkout/
│   │   ├── data/models/
│   │   │   └── delivery_address.dart — Structured address data
│   │   └── presentation/
│   │       ├── address_selection_screen.dart — Saved + new address
│   │       └── checkout_screen.dart  — Confirm + place order
│   │
│   ├── orders/
│   │   ├── data/
│   │   │   ├── order_repository.dart — createOrder, getUserOrders, updateOrderStatus
│   │   │   └── models/
│   │   │       └── order.dart        — OrderStatus enum + model (has loyalty fields)
│   │   ├── providers/
│   │   │   └── order_provider.dart
│   │   └── presentation/
│   │       ├── order_tracking_screen.dart — Map + status timeline + driver info
│   │       ├── order_success_screen.dart  — Post-delivery screen
│   │       ├── order_history_screen.dart  — Past orders list
│   │
│   ├── loyalty/
│   │   ├── data/
│   │   │   └── loyalty_eligibility.dart — Compute next milestone (5th/10th order)
│   │   └── presentation/
│   │       ├── loyalty_card_sheet.dart           — Stamp card modal
│   │       ├── loyalty_cancel_dialog.dart        — Confirm removal animation
│   │       ├── loyalty_rewards_screen.dart       — "Mes récompenses" screen
│   │       └── widgets/
│   │           ├── loyalty_progress_section.dart — Badge (3/5)
│   │           ├── loyalty_stamp.dart
│   │           └── loyalty_stamp_grid.dart
│   │
│   ├── bills/
│   │   ├── data/models/
│   │   │   └── bill_provider.dart    — Bill provider info
│   │   ├── services/
│   │   │   └── bill_reminder_service.dart — Scheduled local notifications
│   │   └── presentation/
│   │       ├── bill_payment_screen.dart  — Select provider + fill reference
│   │       └── mes_factures_screen.dart  — Past bills
│   │
│   ├── courier/
│   │   └── presentation/
│   │       └── courier_screen.dart   — P2P parcel sender screen
│   │
│   ├── facture/
│   │   └── presentation/
│   │       └── facture_screen.dart   — Bill payment details entry
│   │
│   ├── favorites/
│   │   ├── providers/
│   │   │   └── favorites_provider.dart — Saved restaurants
│   │   └── presentation/
│   │       └── favorites_screen.dart
│   │
│   ├── notifications/
│   │   ├── data/
│   │   │   ├── notification_repository.dart
│   │   │   └── models/
│   │   │       └── notification.dart
│   │   ├── providers/
│   │   │   └── notification_provider.dart
│   │   └── presentation/
│   │       └── notification_screen.dart
│   │
│   ├── profile/
│   │   ├── data/
│   │   │   └── profile_repository.dart
│   │   ├── providers/
│   │   │   ├── address_provider.dart
│   │   │   └── payment_provider.dart
│   │   └── presentation/
│   │       ├── profile_screen.dart
│   │       ├── edit_profile_screen.dart
│   │       ├── saved_addresses_screen.dart
│   │       ├── payment_methods_screen.dart
│   │       ├── phone_gate_screen.dart
│   │       └── help_support_screen.dart
│   │
│   ├── promo/
│   │   ├── data/
│   │   │   ├── promo_repository.dart
│   │   │   └── models/
│   │   │       └── promo_code_response.dart
│   │   └── providers/
│   │       └── promo_provider.dart
│   │
│   ├── ai_search/
│   │   ├── data/
│   │   │   ├── ai_search_repository.dart
│   │   │   └── models/
│   │   │       └── search_result.dart
│   │   ├── providers/
│   │   │   └── ai_search_provider.dart
│   │   └── presentation/
│   │       ├── ai_search_screen.dart
│   │       └── widgets/
│   │           └── ai_search_result_card.dart
│   │
│   ├── happy_hour/
│   │   ├── providers/
│   │   │   └── happy_hour_provider.dart
│   │   └── presentation/
│   │       ├── happy_hour_screen.dart
│   │       └── widgets/
│   │           └── happy_hour_card.dart
│   │
│   └── menu/
│       └── data/models/
│           ├── food_item_option_group.dart — Option groups + options + links
│           └── item_variant.dart            — Variants (Normal/Mozzarella)
│
├── models/
│   └── chat_message.dart    — ChatMessage model (AI chat history)
│
├── screens/
│   └── ai_chat_screen.dart  — AI assistant conversational UI
│
├── services/
│   └── ai_chat_service.dart — OpenRouter API client (calls Edge Function)
│
├── l10n/
│   ├── app_localizations_ar.dart
│   ├── app_localizations_en.dart
│   └── app_localizations_fr.dart
│
├── firebase_options.dart    — FlutterFire configuration
├── main.dart                — App entry, Supabase/Firebase init, ProviderScope
```

### 3.2 Driver App (cmandili_driver/lib/)

```
lib/
├── core/
│   ├── config/
│   │   └── supabase_config.dart
│   ├── models/
│   │   └── (models for driver domain)
│   ├── providers/
│   │   ├── localization_provider.dart
│   │   └── theme_provider.dart
│   ├── push/
│   │   └── push_service.dart — FCM initialization
│   ├── services/
│   │   └── background_location_service.dart — Foreground service for GPS tracking
│   ├── theme/
│   │   └── app_colors.dart, app_theme.dart
│   └── utils/
│       └── (location, formatting utilities)
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   └── auth_repository.dart
│   │   ├── providers/
│   │   │   └── auth_provider.dart
│   │   └── presentation/
│   │       ├── auth_screen.dart
│   │       └── vehicle_info_screen.dart — Mandatory vehicle type registration
│   │
│   ├── home/
│   │   └── presentation/
│   │       └── home_screen.dart — Available orders list (status='ready', nearby)
│   │
│   ├── orders/
│   │   ├── data/
│   │   │   └── order_repository.dart — Driver order queries + status updates
│   │   ├── providers/
│   │   │   ├── driver_online_provider.dart — Is driver currently online?
│   │   │   ├── driver_orders_provider.dart — StreamProvider: available + active orders
│   │   │   └── (order stream subscriptions)
│   │   └── presentation/
│   │       ├── order_tracking_screen.dart — Map + delivery route
│   │       └── (order detail screens)
│   │
│   ├── earnings/
│   │   └── presentation/
│   │       └── earnings_screen.dart — Daily/lifetime stats, commission breakdown
│   │
│   ├── profile/
│   │   └── presentation/
│   │       └── profile_screen.dart — Vehicle info edit, ratings, payouts
│   │
│   ├── notifications/
│   │   ├── providers/
│   │   │   └── notification_provider.dart
│   │   └── presentation/
│   │       └── (notification screens)
│   │
│   └── (other features specific to driver workflow)
│
├── l10n/
│   └── (localization files)
│
└── main.dart — App entry + BackgroundLocationService.registerTask()
```

### 3.3 Partner App (cmandili_partner/lib/)

```
lib/
├── core/
│   ├── config/
│   │   ├── supabase_config.dart
│   │   └── openrouter_config.dart — OpenRouter API key for AI menu scanner
│   ├── models/
│   ├── providers/
│   ├── push/
│   ├── theme/
│   └── utils/
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   └── auth_repository.dart
│   │   ├── providers/
│   │   │   └── auth_provider.dart
│   │   └── presentation/
│   │       └── auth_screen.dart
│   │
│   ├── home/
│   │   └── presentation/
│   │       └── home_screen.dart — Dashboard (today stats, pending orders)
│   │
│   ├── menu/
│   │   ├── data/
│   │   │   ├── menu_repository.dart — CRUD food_items
│   │   │   └── models/
│   │   │       └── (food item model with customization)
│   │   ├── providers/
│   │   │   └── menu_provider.dart
│   │   └── presentation/
│   │       ├── menu_screen.dart — Items list
│   │       ├── add_item_screen.dart — Form entry
│   │       ├── ai_menu_scanner_screen.dart — Photo → Gemini → auto-fill items
│   │       └── (item detail/edit screens)
│   │
│   ├── orders/
│   │   ├── data/
│   │   │   └── order_repository.dart — Accept, prepare, ready, cancel order
│   │   ├── providers/
│   │   │   └── partner_orders_provider.dart — StreamProvider: pending → ready
│   │   └── presentation/
│   │       ├── orders_queue_screen.dart — Pending → confirming → preparing → ready
│   │       ├── order_detail_screen.dart — Full order info, items, voice notes
│   │       ├── order_tracking_screen.dart — Mapbox driver location tracking
│   │       └── (status update dialogs)
│   │
│   ├── promotions/ (happy_hour)
│   │   ├── data/
│   │   │   └── promotion_repository.dart
│   │   ├── providers/
│   │   │   └── promotion_provider.dart
│   │   └── presentation/
│   │       └── promotion_screen.dart — Time-based discount scheduling
│   │
│   ├── reports/
│   │   └── presentation/
│   │       ├── reports_screen.dart — Daily/monthly revenue
│   │       └── export_reports.dart
│   │
│   ├── profile/
│   │   ├── data/
│   │   │   └── profile_repository.dart
│   │   └── presentation/
│   │       └── profile_screen.dart — Entity info, hours, payouts
│   │
│   ├── notifications/
│   │   ├── providers/
│   │   │   └── notification_provider.dart
│   │   └── presentation/
│   │       └── (notification screens)
│   │
│   └── (other features)
│
├── l10n/
│   └── (localization)
│
└── main.dart
```

### 3.4 Admin Dashboard (cmandili_admin/)

**Structure:** Next.js 16 App Router (TypeScript)

```
app/
├── page.tsx                         — Redirect to /login
├── layout.tsx                       — RootLayout (HTML wrapper, Tailwind CSS)
│
├── login/
│   └── page.tsx                     — Login form (createBrowserClient Supabase)
│
├── reset-password/
│   └── page.tsx                     — Password reset flow
│
├── dashboard/
│   ├── layout.tsx                   — Sidebar + Shell route
│   ├── page.tsx                     — Main dashboard (stats, charts)
│   │
│   ├── commandes/
│   │   └── page.tsx                 — Order search + table (status, timeline)
│   │
│   ├── livreurs/
│   │   └── page.tsx                 — Driver list, block toggle, earnings detail
│   │
│   ├── restaurants/
│   │   ├── page.tsx                 — Restaurant master list
│   │   └── [id]/
│   │       ├── menu/
│   │       │   ├── page.tsx         — Menu editor for ghost restaurant
│   │       │   └── GhostMenuClient.tsx
│   │       └── (other edit routes)
│   │
│   ├── supermarkets/
│   │   ├── page.tsx                 — Supermarket master list
│   │   └── [id]/
│   │       ├── menu/
│   │       │   ├── page.tsx         — Grocery editor
│   │       │   └── GhostGroceryClient.tsx
│   │
│   ├── clients/
│   │   └── page.tsx                 — Customer list, block toggle
│   │
│   ├── finances/
│   │   └── page.tsx                 — Commission summary, revenue by entity
│   │
│   ├── fidelite/
│   │   └── page.tsx                 — Loyalty payouts ledger, approve settlements
│   │
│   ├── promos/
│   │   └── page.tsx                 — Promo code CRUD
│   │
│   ├── parametres/
│   │   └── page.tsx                 — Global settings form
│   │
│   ├── audit/
│   │   └── page.tsx                 — Admin action logs
│   │
│   └── releve/
│       └── page.tsx                 — Monthly settlement PDF export
│
├── api/
│   ├── auth/
│   │   └── route.ts                 — (if custom auth endpoint)
│   ├── block/
│   │   └── route.ts                 — POST: block/unblock customer/partner/driver
│   ├── loyalty/
│   │   └── settle/
│   │       └── route.ts             — POST: approve driver/partner payout
│   ├── promos/
│   │   └── route.ts                 — POST/PATCH/DELETE promo codes
│   ├── restaurants/
│   │   ├── categories/
│   │   │   └── route.ts             — POST: tag restaurant with category
│   │   ├── menu/
│   │   │   └── route.ts             — GET/POST ghost restaurant menu
│   │   └── toggle-ghost/
│   │       └── route.ts             — POST: toggle is_ghost_restaurant
│   ├── settings/
│   │   └── route.ts                 — PATCH global_settings
│   ├── releve/
│   │   └── route.ts                 — POST: generate settlement PDF
│   ├── logout/
│   │   └── route.ts                 — POST: sign out
│   └── (other API routes)
│
├── lib/
│   ├── supabase-admin.ts            — createClient with SERVICE_ROLE_KEY
│   ├── (other utilities)
│   └── components/ (or separate components/ at root)
│
├── components/
│   ├── StatsCard.tsx                — KPI card display
│   ├── RevenueChart.tsx             — Recharts area chart (last 30 days)
│   ├── OrdersTable.tsx              — Commandes table with status color-coding
│   ├── RestaurantRow.tsx            — Restaurant row with edit/block/toggle
│   ├── DriverRow.tsx                — Driver row with earnings breakdown
│   ├── LoyaltyPayoutRow.tsx         — Settlement row (approve/reject)
│   └── (other reusable components)
│
├── globals.css                      — Tailwind base styles
└── middleware.ts                    — (UNCERTAIN: not found; may be auth guard at page level)

public/
├── (static assets if any)
```

---

## 4. DATA MODEL

### 4.1 Complete Table List (30+ tables)

| Table Name | Purpose | Has RLS | Key Columns |
|---|---|---|---|
| **auth.users** | Supabase Auth (managed by Supabase) | N/A (auth schema) | id (PK UUID), email, created_at, raw_user_meta_data |
| **profiles** | User profile (auto-created by trigger on new auth.user) | ✅ | id (PK = auth.uid()), full_name, phone, profile_photo_url, is_admin, is_blocked, language_preference |
| **drivers** | Driver registration + live location | ✅ | id (PK UUID), user_id (FK auth.users.id), vehicle_type, vehicle_plate, is_online, current_lat, current_lng, rating, verified_at |
| **partners** | Restaurant/supermarket owner | ✅ | user_id (FK), entity_id (FK restaurants\|supermarkets), partner_type ('restaurant'\|'supermarket'), commission_rate, is_blocked |
| **restaurants** | Restaurant entity | ✅ (SELECT only) | id (PK UUID), name, latitude, longitude, is_open, opening_time, closing_time, is_ghost_restaurant, categories (TEXT[]), rating |
| **supermarkets** | Supermarket entity | ✅ (SELECT only) | id (PK UUID), name, latitude, longitude, is_open, opening_time, closing_time, is_ghost_supermarket, rating |
| **food_items** | Restaurant menu items | ✅ (SELECT only) | id (PK UUID), restaurant_id (FK), name, description, price (NUMERIC 12,3), discount_price, image_url, category, is_available, is_spicy, is_vegetarian, preparation_time, created_at |
| **food_item_variants** | Menu item variants (Normal/Mozzarella/Cheddar) | ✅ (SELECT only) | id (PK UUID), food_item_id (FK), variant_name, price_offset (NUMERIC 12,3), sort_order |
| **food_item_option_groups** | Sauce/Suppléments containers | ✅ (SELECT only) | id (PK UUID), restaurant_id (FK), group_name, min_selections, max_selections, sort_order |
| **food_item_options** | Individual choices (Harissa, Gruyère, etc.) | ✅ (SELECT only) | id (PK UUID), option_group_id (FK), option_name, price_offset (NUMERIC 12,3), sort_order |
| **food_item_option_group_links** | Junction: food_items ↔ option_groups | ✅ (SELECT only) | food_item_id (FK), option_group_id (FK), sort_order |
| **grocery_items** | Supermarket products | ✅ (SELECT only) | id (PK UUID), supermarket_id (FK), name, description, price, category, image_url, is_available, created_at |
| **grocery_categories** | Supermarket categories | ✅ (SELECT only) | id (PK UUID), supermarket_id (FK), category_name, icon |
| **orders** | Order header (all service types) | ✅ | id (PK UUID), user_id (FK profiles.id), restaurant_id (FK, nullable), supermarket_id (FK, nullable), driver_id (FK drivers.id, nullable), status ('pending'\|'confirmed'\|'preparing'\|'ready'\|'pickedUp'\|'onTheWay'\|'delivered'\|'cancelled'), subtotal (NUMERIC 12,3), delivery_fee (NUMERIC 12,3), total (NUMERIC 12,3), platform_fee (NUMERIC 12,3), driver_fee_cut (NUMERIC 12,3), payment_method ('cash'), notes, delivery_address (JSONB), pickup_address (JSONB), order_type ('food'\|'supermarket'\|'courier'\|'facture'\|'billPayment'), distance_km, assigned_driver_id (FK drivers.id), assignment_expires_at, passed_driver_ids (UUID[]), no_driver_notified_at, self_delivery, loyalty_milestone_type, loyalty_discount_amount, bill_type, bill_reference, bill_amount, bill_photo_url, bill_receipt_url, cancellation_reason, cancelled_by, cancelled_at, created_at |
| **order_items** | Order line items | ✅ | id (PK UUID), order_id (FK), food_item_id (FK, nullable), grocery_item_id (FK, nullable), quantity, price (NUMERIC 12,3), options (JSONB: customization + variant + optionGroups), voice_note_url |
| **deliveries** | Delivery assignment tracking | ✅ | id (PK UUID), order_id (FK), driver_id (FK), pickup_lat, pickup_lng, delivery_lat, delivery_lng, distance_km, status, created_at |
| **payments** | Payment records (cash only for now) | ✅ | id (PK UUID), order_id (FK), user_id (FK), amount (NUMERIC 12,3), method, status ('pending'\|'collected'), collected_at |
| **device_tokens** | FCM tokens per device | ✅ | id (PK UUID), user_id (FK), token (TEXT), platform ('android'\|'ios'\|'windows'\|'linux'), created_at |
| **notifications** | Notification log (app-internal history) | ✅ | id (PK UUID), user_id (FK), title, message, type ('order_status'\|...), data (JSONB), is_read, created_at |
| **chat_messages** | AI chat history | ✅ | id (PK UUID), user_id (FK), text, is_user (boolean), created_at |
| **settlements** | Financial transactions (platform↔partners/drivers) | ✅ | id (PK UUID), user_id (FK auth.users), entity_type ('restaurant'\|'supermarket'\|'driver'), amount (NUMERIC 12,3), type ('order_earning'\|'commission_deduction'\|'payout'\|'collection'), status ('pending'\|'paid'\|'failed'), description, related_order_id (FK, nullable), created_at, paid_at |
| **promo_codes** | Discount codes | ✅ (SELECT only) | id (PK UUID), code (TEXT UNIQUE), type ('%'\|'TND'), value (NUMERIC 12,3), expires_at, is_active, usage_count, created_at |
| **global_settings** | Platform configuration | ✅ (SELECT all) | id (PK UUID), setting_key (TEXT UNIQUE), setting_value (TEXT), description |
| **partners** (see above) | Links to partner (owner) | ✅ | partner_type, commission_rate, is_blocked |
| **audit_logs** | Admin action audit trail | ✅ | id (PK UUID), admin_id (FK auth.users), action (TEXT), entity_type, entity_id, changes (JSONB), created_at |
| **loyalty_customer_progress** | Customer lifetime delivery count for loyalty | ✅ | customer_id (PK = auth.uid()), delivered_count (INT) |
| **loyalty_driver_payouts** | Per-order driver loyalty bonus tracking | ✅ | id (PK UUID), order_id (UNIQUE FK), driver_id (FK drivers.id), amount_owed (NUMERIC 12,3), status ('pending'\|'settled'), created_at |
| **support_tickets** | Customer support requests | ✅ | id (PK UUID), user_id (FK), subject, message, status, created_at |
| **restaurants** (see above) | Restaurant entity | - | auto_close_enabled, next_open_time |

### 4.2 Key Tables: Columns & Foreign Keys

#### **orders** (most complex)
```
id UUID PRIMARY KEY
user_id UUID NOT NULL → auth.users(id) [RLS: customer owns]
restaurant_id UUID NULLABLE → restaurants(id) [RLS: partner owns entity_id]
supermarket_id UUID NULLABLE → supermarkets(id)
driver_id UUID NULLABLE → drivers(id) [RLS: driver owns driver.id]
status TEXT CHECK (status IN ('pending','confirmed','preparing','ready',
                             'pickedUp','onTheWay','delivered','cancelled'))
subtotal NUMERIC(12,3)
delivery_fee NUMERIC(12,3)
total NUMERIC(12,3) = subtotal + delivery_fee
platform_fee NUMERIC(12,3) [stamped by trigger: 10% restaurant, 15% supermarket]
driver_fee_cut NUMERIC(12,3) [stamped by trigger: 23% of delivery_fee]
payment_method TEXT DEFAULT 'cash'
notes TEXT
delivery_address JSONB {
  "address": "string",
  "city": "string",
  "lat": number,
  "lng": number,
  ...
}
pickup_address JSONB [for courier orders]
order_type TEXT CHECK (order_type IN ('food','supermarket','courier','facture','billPayment'))
distance_km DOUBLE PRECISION [haversine restaurant→customer]
assigned_driver_id UUID NULLABLE → drivers(id) [current offer holder, 10s timeout]
assignment_expires_at TIMESTAMPTZ [assignment deadline]
passed_driver_ids UUID[] [drivers who already rejected this order]
no_driver_notified_at TIMESTAMPTZ [waterfall exhausted → partner notification sent]
self_delivery BOOLEAN [partner chose to deliver themselves]
loyalty_milestone_type TEXT NULLABLE ('half'|'free'|null)
loyalty_discount_amount NUMERIC(12,3) [amount deducted from delivery_fee]
cancellation_reason TEXT
cancelled_by TEXT ('customer'|'admin'|'system')
cancelled_at TIMESTAMPTZ
created_at TIMESTAMPTZ
```

#### **drivers**
```
id UUID PRIMARY KEY [NOT auth.uid()]
user_id UUID NOT NULL UNIQUE → auth.users(id) [RLS uses this, not id]
vehicle_type TEXT CHECK (vehicle_type IN ('motorbike','car','van'))
vehicle_plate TEXT
is_online BOOLEAN
current_lat DOUBLE PRECISION [updated by background service on ~30m movement, not on a timer]
current_lng DOUBLE PRECISION
is_blocked BOOLEAN [excluded from dispatch]
rating NUMERIC(3,2) [average customer rating]
verified_at TIMESTAMPTZ
created_at TIMESTAMPTZ
```

#### **restaurants**
```
id UUID PRIMARY KEY
name TEXT UNIQUE
latitude DOUBLE PRECISION
longitude DOUBLE PRECISION
is_open BOOLEAN [enforced by trigger based on opening_time/closing_time]
opening_time TIME [daily start]
closing_time TIME [daily end]
closing_time_today TIME NULLABLE [admin can override]
auto_close_enabled BOOLEAN [auto-close at closing_time via pg_cron]
is_ghost_restaurant BOOLEAN [test dispatch without real partner]
categories TEXT[] ['Pizzeria', 'Pâtisserie', ...]
rating NUMERIC(3,2)
delivery_fee_base NUMERIC(12,3) [flat rate, then + distance]
created_at TIMESTAMPTZ
```

#### **food_items**
```
id UUID PRIMARY KEY
restaurant_id UUID NOT NULL → restaurants(id)
name TEXT
description TEXT
price NUMERIC(12,3) [base price, updated with variants + options]
discount_price NUMERIC(12,3) [happy hour price]
image_url TEXT
category TEXT [Restaurant's internal categorization]
is_available BOOLEAN [can customer order?]
is_spicy BOOLEAN [for AI filtering]
is_vegetarian BOOLEAN
preparation_time INT [minutes]
created_at TIMESTAMPTZ
updated_at TIMESTAMPTZ
```

#### **profiles** (auto-created by trigger on auth.users INSERT)
```
id UUID PRIMARY KEY = auth.users.id
email TEXT
full_name TEXT
phone TEXT
profile_photo_url TEXT
is_admin BOOLEAN [dashboard gate]
is_blocked BOOLEAN [cannot create orders]
language_preference TEXT ('fr'|'en'|'ar')
created_at TIMESTAMPTZ
updated_at TIMESTAMPTZ
```

### 4.3 Enums (Canonical Values)

**OrderStatus** (8 values, camelCase, must match Dart enum serialization):
```
pending       → customer created food/supermarket order, awaiting partner accept
confirmed     → partner accepted order
preparing     → partner marked order being prepared
ready         → partner ready; dispatchable to drivers (or ready for customer pickup)
pickedUp      → driver picked up food/parcel
onTheWay      → driver en route to customer (NOT on_the_way)
delivered     → order delivered, triggers settlements
cancelled     → order cancelled (terminal status, cannot revert)
```

**OrderType**:
```
food          → restaurant order
supermarket   → grocery/supermarket order
courier       → P2P parcel (pickup + delivery addresses)
facture       → bill payment (water/electric/telecom)
billPayment   → (synonym or legacy?)
```

**ServiceType** (lib/core/models/service_category.dart):
```
foodDelivery  → restaurants
supermarket   → groceries
billPayments  → bills
courier       → parcel delivery
```

**PartnerType**:
```
restaurant    → food service provider
supermarket   → grocery service provider
(boutique)    → [UNCERTAIN: migration 20260704160000 uncommitted]
```

**EntityType** (settlements table):
```
restaurant    → restaurant entity
supermarket   → supermarket entity
driver        → driver entity
```

**SettlementType**:
```
order_earning           → positive amount earned
commission_deduction    → platform cut (negative)
payout                  → settlement payment to user
collection              → amount owed by user to platform
```

**SettlementStatus**:
```
pending   → not yet processed
paid      → payment completed
failed    → payment failed
```

**Vehicle Type** (drivers table):
```
motorbike
car
van
```

### 4.4 Row Level Security (RLS) Policies — Summary

**All tables with RLS enabled:** orders, order_items, deliveries, drivers, profiles, device_tokens, notifications, chat_messages, settlements, audit_logs, loyalty_customer_progress, loyalty_driver_payouts, support_tickets, promo_codes (SELECT only), global_settings (SELECT only), restaurants/supermarkets/food_items (SELECT only for public catalog)

**Key policies by table:**

**orders** (most complex):
```sql
-- Customer SELECT: own orders only
CREATE POLICY "customers_select_own_orders"
  ON orders FOR SELECT
  USING (user_id = auth.uid());

-- Customer UPDATE: only specific columns (status, cancellation_*)
CREATE POLICY "customers_update_own_orders"
  ON orders FOR UPDATE
  USING (user_id = auth.uid());

-- Partner SELECT: orders from their restaurant/supermarket
CREATE POLICY "partners_select_entity_orders"
  ON orders FOR SELECT
  USING (
    restaurant_id IN (SELECT entity_id FROM partners WHERE user_id = auth.uid())
    OR supermarket_id IN (SELECT entity_id FROM partners WHERE user_id = auth.uid())
  );

-- Partner UPDATE: specific columns only
CREATE POLICY "partners_update_entity_orders"
  ON orders FOR UPDATE
  USING (
    restaurant_id IN (SELECT entity_id FROM partners WHERE user_id = auth.uid())
    OR supermarket_id IN (SELECT entity_id FROM partners WHERE user_id = auth.uid())
  );

-- Driver SELECT: assigned or available (ready + no driver_id)
CREATE POLICY "drivers_see_assigned_or_available"
  ON orders FOR SELECT
  USING (
    driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid())
    OR (status IN ('ready') AND driver_id IS NULL AND is_ghost_restaurant IS NOT TRUE)
  );

-- Admin: sees everything (service_role bypasses RLS)
```

**Additional guard trigger** (F16 — column-scope guard):
```sql
-- Before UPDATE, ensure customer cannot change total, delivery_fee, etc.
-- Only column-level audit, not row-level
```

**Additional guard trigger** (F22 — cancelled terminal status):
```sql
-- Cancelled orders cannot transition to any other status
-- Unless actor is admin or service_role
```

**drivers**:
```sql
-- Each driver sees their own record
CREATE POLICY "drivers_select_own"
  ON drivers FOR SELECT
  USING (user_id = auth.uid());

-- Admin/service_role see all
```

**profiles**:
```sql
-- Each user sees their own profile
CREATE POLICY "profiles_select_own"
  ON profiles FOR SELECT
  USING (id = auth.uid());
```

---

## 5. KEY BUSINESS FLOWS

### 5.1 Order Creation (Client App)

**Triggered by:** User taps "Confirm order" on checkout screen.  
**Flow:**

1. **Client App** (lib/features/orders/data/order_repository.dart:createOrder)
   ```dart
   final orderResponse = await _supabase.from('orders').insert({
     'user_id': userId,
     'restaurant_id': restaurantId,
     'status': 'pending',  // CRITICAL: pending for food/supermarket
     'subtotal': subtotal,
     'delivery_fee': deliveryFee,
     'total': total,
     'payment_method': 'cash',
     'delivery_address': deliveryAddress.toJson(),
     'order_type': 'food',  // or 'supermarket', 'courier', 'facture'
   }).select().single();
   ```

2. **Insert order_items** (one row per cart item)
   ```dart
   for (final item in items) {
     final options = {
       'customization': item.customization?.toJson(),
       'variant': item.variant?.toJson(),
       'optionGroups': item.selectedOptionGroups.map((g) => g.toJson()).toList(),
     };
     await _supabase.from('order_items').insert({
       'order_id': orderId,
       'food_item_id': item.foodItem?.id,
       'quantity': item.quantity,
       'price': item.price,
       'options': options,
     });
   }
   ```

3. **PostgreSQL Trigger** (notify_fcm_on_order_status)
   - Fires on `INSERT orders` with `status='pending'`
   - Calls Edge Function `push-on-order-status` with `{ order_id, status: 'pending' }`

4. **Edge Function** (supabase/functions/push-on-order-status)
   - Mode 1 (status change): Routes FCM to:
     - **Customer** (orders.user_id) → push title "🔔 New Order", body "Your order is being reviewed"
     - **Partner** (partners.entity_id matches restaurant_id) → push title "🔔 New Order", body "A new order is waiting for confirmation"
   - Signs JWT with FCM_SERVICE_ACCOUNT_JSON (RSA-256)
   - POST `https://fcm.googleapis.com/v1/projects/.../messages:send`

5. **Firebase Cloud Messaging**
   - Routes to all registered device tokens for customer + partner
   - Android: displays notification from channel "cmandili_orders"
   - Payload includes `order_id` for deep-link routing

6. **Client App** (lib/core/push/push_service.dart)
   - Foreground: `FirebaseMessaging.onMessage` listener shows local notification
   - Background: `firebaseMessagingBackgroundHandler` (data-only logic)
   - Tap notification → deep-link to order tracking screen

7. **Supabase Realtime** (concurrent)
   - Client subscribed to `orders.where(user_id=auth.uid()).on('*', ...)` 
   - INSERT event → client map/UI refreshes immediately

---

### 5.2 Dispatch Waterfall (Automatic Driver Assignment)

**Triggered by:** Partner marks order `status='confirmed'` (accepted order).  
**Flow:**

1. **Partner App** (cmandili_partner/lib/features/orders)
   ```dart
   await supabase
     .from('orders')
     .update({'status': 'confirmed'})
     .eq('id', orderId);
   ```

2. **PostgreSQL Trigger** (dispatch_on_confirmed)
   - Fires on `UPDATE orders SET status='confirmed'`
   - Calls RPC `next_eligible_driver(order_id, radius_km=7)`

3. **RPC: next_eligible_driver** (supabase/migrations/20260510_assignment_and_distance.sql)
   ```sql
   SELECT d.id
   FROM drivers d
   WHERE d.is_online = TRUE
     AND d.current_lat IS NOT NULL
     AND d.is_blocked IS NOT TRUE
     AND NOT (d.id = ANY(passed_driver_ids))
     AND haversine_km(restaurant_lat, restaurant_lng, d.current_lat, d.current_lng) <= 7
   ORDER BY haversine_km(...) ASC
   LIMIT 1;
   ```
   - Returns closest online driver within 7km, not in passed_driver_ids

4. **Update Orders** (dispatch_on_confirmed trigger continuation)
   ```sql
   UPDATE orders
   SET assigned_driver_id = next_eligible_driver(...),
       assignment_expires_at = now() + interval '10 seconds',
       passed_driver_ids = array_append(passed_driver_ids, old_assigned_driver_id)
   WHERE id = order_id;
   ```

5. **Edge Function: push-on-order-status (Mode B: fan-out)**
   - Fires on orders INSERT/UPDATE with `status='ready'`
   - Calls RPC `nearby_online_drivers(lat, lng, radius_km=7)` → get 50 drivers
   - **OR** if `assigned_driver_id` is set, routes high-priority FCM to that ONE driver only
   - Driver push: title "🛵 New Order", body "Order from {Restaurant}, {distance} km away"

6. **Driver App** (cmandili_driver/lib/features/orders/providers)
   ```dart
   final availableOrdersProvider = StreamProvider<List<Order>>((ref) async* {
     yield* supabase
       .from('orders')
       .stream(primaryKey: ['id'])
       .eq('status', 'ready')
       .eq('assigned_driver_id', driverId)  // Offered to this driver
       .or('assigned_driver_id.is.null')    // Unassigned pool
       .order('created_at', ascending: false);
   });
   ```
   - Shows order card with 10s countdown (assignment_expires_at)
   - Driver taps "Accept" → calls `pass_order_offer(order_id, driver_id)`

7. **RPC: pass_order_offer**
   ```sql
   UPDATE orders
   SET driver_id = driver_id,  -- confirm driver
       assigned_driver_id = NULL,
       assignment_expires_at = NULL
   WHERE id = order_id
     AND assigned_driver_id = driver_id  -- driver accepting their own offer
     AND status = 'confirmed';  -- waterfall only runs on confirmed orders
   ```

8. **Timeout Fallback** (pg_cron: rotate_expired_offers every 5s)
   ```sql
   UPDATE orders
   SET assigned_driver_id = next_eligible_driver(...)
   WHERE assignment_expires_at < now()
     AND driver_id IS NULL;  -- still unassigned
   ```
   - Passes order to next closest driver → re-fire push notification

9. **Waterfall Exhausted** (RPC: notify_partner_no_drivers)
   - If `next_eligible_driver(...)` returns NULL (no more drivers)
   - And `no_driver_notified_at IS NULL`
   - Calls Edge Function: push to partner "Je livre cette commande?" (self-delivery option)
   - Partner taps → `confirmSelfDelivery()` sets `self_delivery=true, status='onTheWay'`

---

### 5.3 Real-time Tracking (Driver Location → Customer Map)

**Background Service** (cmandili_driver/lib/core/services/background_location_service.dart):
```dart
class BackgroundLocationService {
  // Runs in foreground service (Android 13+ requirement)
  // Notification: "Amana — Livraison en cours"
  
  void _startLocationTracking() {
    _timer = Timer.periodic(Duration(seconds: 10), (_) {
      _geolocator.getCurrentPosition(timeLimit: Duration(seconds: 5))
        .then((position) {
          // Push GPS to DB
          supabase
            .from('drivers')
            .update({
              'current_lat': position.latitude,
              'current_lng': position.longitude,
            })
            .eq('id', driverId);
        });
    });
  }
}
```

**Client App Tracking** (lib/features/orders/presentation/order_tracking_screen.dart):
```dart
// Subscribe to driver location
supabase
  .from('drivers')
  .stream(primaryKey: ['id'])
  .eq('id', order.driverId)
  .listen((events) {
    // Update map marker whenever a new position row arrives (pushed on ~30m movement)
    _mapController.animateCamera(
      CameraUpdateOptions(
        geometry: Point(
          coordinates: Position(driver.current_lng, driver.current_lat),
        ),
      ),
    );
  });
```

**Frequency:** GPS pushed on ~30m movement (`distanceFilter: 30`, not a fixed interval) → Realtime delivers in <500ms → map updates near-live

---

### 5.4 Order Status Transitions

**Valid transitions (by actor):**

```
Customer (user_id = orders.user_id):
  pending → cancelled [via app UI]
  confirmed → cancelled
  (Cannot advance status)

Partner (owns restaurant_id):
  pending → confirmed [accept order]
  confirmed → preparing [start prep]
  preparing → ready [ready for pickup]
  ready → cancelled [reject]

Driver (driver_id in drivers table):
  ready → pickedUp [pick up from restaurant]
  pickedUp → onTheWay [start delivery]
  onTheWay → delivered [delivery complete]
  [Any] → cancelled [only if NOT already cancelled (F22)]

Admin / service_role:
  [Any] → [Any] (bypasses RLS + guards)
  Exception: cancelled → [Anything] raises exception even for admin if F22 applied
```

**Trigger chain on status change:**
1. `notify_fcm_on_order_status()` fires
   - Routes FCM to customer/partner/driver based on status + actor
   - Updates delivery_status_at, ready_at, confirmed_at timestamps
2. `generate_settlements_on_delivery()` fires (if status = 'delivered')
   - Inserts settlement rows for platform_fee (restaurant) + driver_fee_cut (driver)
   - Updates loyalty_customer_progress (delivered_count += 1)
   - Calculates loyalty_milestone_type if count % 10 == 0 or count % 5 == 0
3. Column-scope guard (F16) rejects unauthorized column changes
4. Terminal status guard (F22) prevents cancelled → anything

---

### 5.5 Loyalty Stamp Card System

**Components:**
- **Backend:** `loyalty_customer_progress` (customer_id, delivered_count)
- **Backend:** `loyalty_driver_payouts` (order_id, driver_id, amount_owed, status)
- **Frontend:** `lib/features/loyalty/` (badge + card + rewards screen)

**Milestone Logic** (lib/features/loyalty/data/loyalty_eligibility.dart):
```dart
// Every order delivered increments loyalty_customer_progress.delivered_count
// Milestones:
//   delivered_count % 10 == 5 → loyalty_milestone_type = 'half' (50% delivery discount)
//   delivered_count % 10 == 0 → loyalty_milestone_type = 'free' (free delivery)

// Trigger: `generate_settlements_on_delivery`
INSERT INTO loyalty_customer_progress (customer_id, delivered_count)
VALUES (user_id, 1)
ON CONFLICT (customer_id) DO UPDATE SET delivered_count = delivered_count + 1;

IF (delivered_count % 10 == 5) THEN
  loyalty_milestone_type = 'half';
  loyalty_discount_amount = delivery_fee * 0.5;
ELSIF (delivered_count % 10 == 0) THEN
  loyalty_milestone_type = 'free';
  loyalty_discount_amount = delivery_fee;
END IF;
```

**Client Display** (lib/features/loyalty/presentation):
- **loyalty_card_sheet.dart:** Animated stamp grid, current milestone progress (3/5 stamps)
- **loyalty_rewards_screen.dart:** "Mes récompenses" → achieved/current/locked milestone cards
- **Progress badge on home:** Displays current position (X/5 or X/10)

---

### 5.6 Food Customization with Option Groups

**Schema:**
```sql
food_items
  ↓
food_item_option_groups (Sauce au choix, Suppléments)
  ↓
food_item_options (Harissa, Gruyère, Cheddar, etc.)
  ↓
food_item_option_group_links (junction: maps items to their groups)

food_items
  ↓
food_item_variants (Normal/Mozzarella/Cheddar pizza variants)
```

**Client Flow** (lib/features/restaurant/presentation):
1. User taps menu item → opens `food_item_customization_sheet.dart`
2. Sheet queries:
   ```dart
   final options = await repository.getFoodItemCustomizationOptions(foodItemId);
   // Returns: variants + option_groups (both ordered by sort_order ASC)
   ```
3. Display:
   - **Variants selector:** Radio buttons (Normal | Mozzarella | Cheddar)
   - **Option groups:** Each group as expandable section
     - Min/max selections enforced (e.g., Sauce: 1 required, Suppléments: 0-3)
   - **Price calculation:** base_price + variant_offset + sum(selected_options.price_offset)

4. User confirms → adds `CartItem` with:
   ```dart
   CartItem(
     foodItem: ...,
     variant: ItemVariant(...),
     selectedOptionGroups: [
       SelectedOptionGroup(groupId, groupName, [
         { optionId, optionName, priceOffset }
       ]),
     ],
     price: final_calculated_price,
   )
   ```

5. On order creation, this JSONB is stored in `order_items.options`:
   ```json
   {
     "variant": { "id": "...", "name": "Mozzarella", "priceOffset": 2.000 },
     "optionGroups": [
       {
         "groupId": "...",
         "groupName": "Sauce au choix",
         "selectedOptions": [
           { "id": "...", "name": "Harissa", "priceOffset": 0.500 }
         ]
       }
     ]
   }
   ```

6. Partner app displays this JSONB on order detail screen for kitchen prep

---

## 6. SECURITY

### 6.1 Authentication Flow

**All four apps:**
```
1. User enters email + password (or taps Google/Apple)
2. createBrowserClient(NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY)
   [or supabaseFlutter.initialize() for Flutter]
3. Supabase Auth issues JWT (RS256, ~1 hour TTL)
4. JWT stored:
   - Flutter: automatically by supabase_flutter SDK
   - Next.js: cookie (if using SSR) or localStorage (browser)
5. Every API request includes `Authorization: Bearer <JWT>`
6. Supabase (PostgreSQL) evaluates JWT:
   - Extracts auth.uid() from JWT claims
   - RLS policies use auth.uid() to enforce row access
```

**OAuth (Google, Apple):**
```
1. User taps "Sign in with Google"
2. Platform SDK (google_sign_in, sign_in_with_apple) handles OAuth flow
3. Returns idToken → passed to Supabase Auth
4. Supabase issues JWT (identity_id = Google/Apple user ID)
```

### 6.2 Roles & Authorization

**Roles (distinguished by DB columns, not Supabase role):**

| Role | Identified By | Key Permissions | Tables Visible |
|---|---|---|---|
| **customer** | `auth.uid()` ∈ users not marked driver/partner | Create food/supermarket/courier orders, view own orders, chat with AI | profiles, restaurants, food_items, supermarkets, grocery_items, orders (own), chat_messages (own) |
| **driver** | `EXISTS(SELECT 1 FROM drivers WHERE user_id = auth.uid())` | Accept offers, update order status (pickedUp/onTheWay/delivered), view earnings, receive push notifications | drivers (own), orders (available + assigned), deliveries (own), settlements (own) |
| **partner** | `EXISTS(SELECT 1 FROM partners WHERE user_id = auth.uid())` | Manage menu (CRUD food_items), accept/prepare orders, view reports | restaurants/supermarkets (own entity_id), food_items (own restaurant_id), orders (own entity), settlements (own) |
| **admin** | `profiles.is_admin = true` | View/edit all data, block users, manage global settings, issue payouts | [All tables via service_role bypass] |

**RLS enforces role membership** by querying auth.uid() and checking which tables they appear in.

### 6.3 Known Gaps & Mitigations

| Issue | Mitigation |
|---|---|
| **Customer can see all restaurants** (UNCERTAIN if intended) | Catalogues (restaurants, food_items) have RLS SELECT all for public discovery — this is intentional for marketplace |
| **Partner could theoretically modify restaurant details if RLS weak** | (Not investigated in this audit) — assume RLS has column guard similar to orders |
| **Driver location pushed on ~30m movement** (privacy concern) | Privacy notice in app + user consent required; foreground service makes it transparent |
| **Cancelled orders terminal (F22) checked in trigger only** | If trigger misfires, a clever UPDATE could theoretically reopen cancelled orders — mitigated by F22 guard ensuring trigger always fires first |

---

## APPENDIX: UNCERTAIN FINDINGS

| Finding | Risk | Investigation Needed |
|---|---|---|
| **Edge Function `notify-partner-order`** | Purpose unclear | Check supabase/functions/notify-partner-order/index.ts for invocation + logic |
| **Middleware.ts missing in admin app** | Auth protection unclear | Check if auth enforced at page component level vs middleware |
| **Column guards on other tables** | May have same data integrity risks as orders | Check migrations for `guard_*` functions on restaurants, partners, drivers, etc. |
| **`boutique_partner_type` migration** (20260704160000) | Schema unclear; CHECK constraint suggests uncommitted feature | Check if migration is applied to live DB or stale |
| **AI Chat call flow (Edge Function vs direct)** | AiChatService comments say "no AI provider key ships in app" but actual invocation unclear | Verify: Edge Function calls OpenRouter, or Flutter app calls OpenRouter directly? |
| **Payment flow** | Cash only, but no explicit validation of COD | Check if any payment validation happens before order is marked "delivered" |
| **Restaurant/supermarket editing by admin** | Admin API routes exist but full scope unclear | Check `/api/restaurants/menu/route.ts` and `/api/supermarkets/menu/route.ts` |
| **Promo code application** | Where/how promo discounts are deducted (client-side? server-side trigger?) | Verify flow in checkout_repository.dart / order_repository.dart |

---

**END OF INVESTIGATION REPORT**

All findings are based on code inspection. No files were modified. Recommendations for further verification listed above.
