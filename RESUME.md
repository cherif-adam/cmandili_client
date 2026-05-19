# RESUME.md — Cmandili Mobile App

## Project Overview

**App Name:** Cmandili (`cmandili_mobile`)
**Version:** 1.0.0+1
**Platform:** Flutter (SDK >=3.0.0 <4.0.0) — cross-platform (iOS, Android, Web, macOS, Linux, Windows)
**Backend:** Supabase (PostgreSQL, Auth, Storage, Realtime)
**Architecture:** Feature-first, Repository pattern, Riverpod 2.x state management
**Localization:** Trilingual — English, Arabic (`ar`), French (`fr`)
**Currency:** Tunisian Dinar (DT), formatted via `intl` with `fr_TN` locale

---

## Repository Structure

```
lib/
├── main.dart
├── core/
│   ├── config/
│   │   ├── supabase_config.dart
│   │   └── supabase_service.dart
│   ├── models/
│   │   └── service_category.dart
│   ├── providers/
│   │   ├── localization_provider.dart
│   │   ├── service_provider.dart
│   │   └── theme_provider.dart
│   ├── router/
│   │   └── app_router.dart
│   ├── theme/
│   │   ├── app_colors.dart
│   │   └── app_theme.dart
│   └── utils/
│       ├── currency_formatter.dart
│       └── location_service.dart
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── auth_repository.dart
│   │   │   └── models/
│   │   │       ├── user_model.freezed.dart
│   │   │       └── user_model.g.dart
│   │   ├── presentation/
│   │   │   └── auth_screen.dart
│   │   └── providers/
│   │       └── auth_provider.dart
│   ├── bills/
│   │   ├── data/models/
│   │   │   └── bill_provider.dart
│   │   └── presentation/
│   │       └── bill_payment_screen.dart
│   ├── cart/
│   │   ├── data/models/
│   │   │   ├── cart_item.dart
│   │   │   └── order_customization.dart
│   │   ├── presentation/
│   │   │   ├── cart_screen.dart
│   │   │   └── widgets/
│   │   │       └── order_customization_widget.dart
│   │   └── providers/
│   │       └── cart_provider.dart
│   ├── checkout/
│   │   ├── data/models/
│   │   │   ├── address_model.freezed.dart
│   │   │   └── address_model.g.dart
│   │   └── presentation/
│   │       ├── checkout_screen.dart
│   │       └── address_selection_screen.dart
│   ├── courier/
│   │   └── presentation/
│   │       └── courier_screen.dart
│   ├── favorites/
│   │   ├── presentation/
│   │   │   └── favorites_screen.dart
│   │   └── providers/
│   │       └── favorites_provider.dart
│   ├── happy_hour/
│   │   ├── presentation/
│   │   │   ├── happy_hour_screen.dart
│   │   │   └── widgets/
│   │   │       └── happy_hour_card.dart
│   │   └── providers/
│   │       └── happy_hour_provider.dart
│   ├── home/
│   │   ├── data/models/
│   │   │   ├── restaurant.dart
│   │   │   ├── restaurant.freezed.dart
│   │   │   └── restaurant.g.dart
│   │   └── presentation/
│   │       ├── home_screen.dart
│   │       └── widgets/
│   │           ├── service_selector.dart
│   │           ├── bills_placeholder.dart
│   │           └── supermarket_placeholder.dart
│   ├── notifications/
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   └── notification.dart
│   │   │   └── notification_repository.dart
│   │   ├── presentation/
│   │   │   └── notification_screen.dart
│   │   └── providers/
│   │       └── notification_provider.dart
│   ├── orders/
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   ├── order.dart
│   │   │   │   ├── order_model.freezed.dart
│   │   │   │   ├── order_model.g.dart
│   │   │   │   ├── order_item_model.freezed.dart
│   │   │   │   └── order_item_model.g.dart
│   │   │   └── order_repository.dart
│   │   ├── presentation/
│   │   │   ├── order_tracking_screen.dart
│   │   │   └── order_history_screen.dart
│   │   └── providers/
│   │       └── order_provider.dart
│   ├── profile/
│   │   ├── data/
│   │   │   └── profile_repository.dart
│   │   ├── presentation/
│   │   │   ├── profile_screen.dart
│   │   │   ├── edit_profile_screen.dart
│   │   │   ├── saved_addresses_screen.dart
│   │   │   ├── payment_methods_screen.dart
│   │   │   └── help_support_screen.dart
│   │   └── providers/
│   │       ├── address_provider.dart
│   │       └── payment_provider.dart
│   ├── restaurant/
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   ├── food_item.dart
│   │   │   │   ├── food_item.freezed.dart
│   │   │   │   └── food_item.g.dart
│   │   │   └── restaurant_repository.dart
│   │   ├── presentation/
│   │   │   ├── restaurant_detail_screen.dart
│   │   │   └── widgets/
│   │   │       └── restaurant_card.dart
│   │   └── providers/
│   │       └── restaurant_provider.dart
│   └── supermarket/
│       ├── data/
│       │   ├── models/
│       │   │   ├── grocery_category.dart
│       │   │   ├── grocery_item.dart
│       │   │   └── supermarket.dart
│       │   └── supermarket_repository.dart
│       ├── presentation/
│       │   ├── supermarket_list_screen.dart
│       │   └── supermarket_detail_screen.dart
│       └── providers/
│           └── supermarket_provider.dart
└── l10n/
    ├── app_en.arb
    ├── app_ar.arb
    ├── app_fr.arb
    ├── app_localizations.dart
    ├── app_localizations_en.dart
    ├── app_localizations_ar.dart
    └── app_localizations_fr.dart
```

---

## Complete File Catalog

### Entry Point

#### `lib/main.dart`
- **Purpose:** App entry point. Initializes Supabase, wraps the widget tree in `ProviderScope`. `MyApp` is a `ConsumerWidget` that watches `authStateProvider`, `localizationProvider`, and `themeProvider` to conditionally route to `HomeScreen` (logged in) or `AuthScreen`.
- **Key classes:** `MyApp extends ConsumerWidget`
- **Dependencies:** `supabase_flutter`, `flutter_riverpod`, all feature screens, localization delegates
- **Notable patterns:** Auth-gated routing at the root level via `StreamProvider`; supports RTL layout through `supportedLocales` and `locale` binding.

---

### Core Layer

#### `lib/core/config/supabase_config.dart`
- **Purpose:** Static configuration holder for Supabase connection parameters.
- **Key classes:** `SupabaseConfig`
- **Fields:** `supabaseUrl`, `supabaseAnonKey`
- **Notable:** Credentials are hardcoded as static constants. `.env.example` documents expected env variable names.

#### `lib/core/config/supabase_service.dart`
- **Purpose:** Thin wrapper around `Supabase.instance.client` providing generic, reusable database methods.
- **Key classes:** `SupabaseService`
- **Key methods:** `query()` (SELECT with optional filters), `subscribe()` (Realtime channel), `uploadFile()` (Storage), `getPublicUrl()`
- **Providers:** `supabaseServiceProvider` (Riverpod `Provider`)
- **Dependencies:** `supabase_flutter`

#### `lib/core/models/service_category.dart`
- **Purpose:** Defines the 4 top-level service types of the super-app.
- **Key classes:** `ServiceType` enum (foodDelivery, supermarket, billPayments, courier), `ServiceCategory` (id, nameEn, nameAr, nameFr, icon, colorHex)
- **Notable:** Static list of 4 `ServiceCategory` instances, enabling trilingual service labels without localization keys.

#### `lib/core/providers/localization_provider.dart`
- **Purpose:** Persistent locale state management.
- **Key classes:** `LocalizationNotifier extends StateNotifier<Locale>`
- **Providers:** `localizationProvider` (StateNotifierProvider)
- **Behavior:** Reads and writes selected locale to `SharedPreferences`; cycles through `en`, `ar`, `fr`.

#### `lib/core/providers/theme_provider.dart`
- **Purpose:** Persistent theme mode (light/dark) state management.
- **Key classes:** `ThemeNotifier extends StateNotifier<ThemeMode>`
- **Providers:** `themeProvider`
- **Key methods:** `toggleTheme()`
- **Dependencies:** `shared_preferences`

#### `lib/core/providers/service_provider.dart`
- **Purpose:** Tracks which of the 4 service tabs is currently active on the home screen.
- **Key classes:** `SelectedServiceNotifier extends StateNotifier<ServiceType>`
- **Providers:** `selectedServiceProvider`

#### `lib/core/router/app_router.dart`
- **Purpose:** GoRouter configuration defining `/auth`, `/home`, `/cart` routes. Not currently wired into `MaterialApp` — kept as a reference for future migration.
- **Key classes:** `AppRouter`
- **Dependencies:** `go_router`
- **Notable:** App currently uses `MaterialApp(home:)` imperative navigation.

#### `lib/core/theme/app_colors.dart`
- **Purpose:** Centralized brand color palette.
- **Key constants:** `primaryOrange = Color(0xFFFF6B35)`, `secondaryOrange = Color(0xFFF7931E)`, `accentTeal = Color(0xFF4ECDC4)`
- **Notable:** Defines `primaryGradient`, `accentGradient`, `darkGradient` as `LinearGradient` constants.

#### `lib/core/theme/app_theme.dart`
- **Purpose:** Material 3 theme definitions.
- **Key classes:** `AppTheme`
- **Key members:** `lightTheme`, `darkTheme` (both `ThemeData` with `useMaterial3: true`)
- **Notable:** Fully configured sub-themes: AppBar, Card, ElevatedButton, TextButton, InputDecoration, Icon, Divider — ensuring consistent visual language across all screens.

#### `lib/core/utils/currency_formatter.dart`
- **Purpose:** Utility for formatting prices in Tunisian Dinar.
- **Key classes:** `CurrencyFormatter`
- **Key methods:** `formatPrice(double)` → `"X.XX DT"`, `formatPriceCompact(double)`
- **Dependencies:** `intl` (NumberFormat with `'fr_TN'` locale)

#### `lib/core/utils/location_service.dart`
- **Purpose:** GPS and geocoding utilities.
- **Key classes:** `LocationService` (all static methods)
- **Key methods:** `getCurrentPosition()`, `getAddressFromCoordinates(lat, lng)`, `getCoordinatesFromAddress(String)`, `calculateDistance(lat1, lng1, lat2, lng2)`
- **Dependencies:** `geolocator`, `geocoding`

---

### Feature: Authentication

#### `lib/features/auth/data/auth_repository.dart`
- **Purpose:** All authentication operations against Supabase Auth + Google OAuth.
- **Key classes:** `User` (custom model with `fromSupabase()` factory), `AuthRepository`
- **Key methods:** `signInWithEmail()`, `signUpWithEmail()`, `signInWithGoogle()` (GoogleSignIn + Supabase idToken), `signInWithApple()` (throws `UnimplementedError`), `signOut()`, `resetPassword()`
- **Dependencies:** `supabase_flutter`, `google_sign_in`
- **Notable:** Apple Sign-In stubbed but unimplemented.

#### `lib/features/auth/data/models/user_model.freezed.dart`
- **Purpose:** Generated freezed immutable model for a Supabase user record.
- **Key class:** `UserModel` (freezed)
- **Fields:** `id`, `email`, `fullName` (`full_name`), `avatarUrl` (`avatar_url`), `role` (default: `'client'`), `createdAt` (`created_at`)
- **Generated by:** `freezed` + `json_serializable`

#### `lib/features/auth/data/models/user_model.g.dart`
- **Purpose:** Generated JSON serialization for `UserModel`.

#### `lib/features/auth/providers/auth_provider.dart`
- **Purpose:** Provides auth repository and exposes auth state as a stream.
- **Providers:** `authRepositoryProvider` (Provider), `authStateProvider` (StreamProvider<User?>) wrapping `supabase.auth.onAuthStateChange`

#### `lib/features/auth/presentation/auth_screen.dart`
- **Purpose:** Full-featured sign in / sign up screen with animations.
- **Key classes:** `AuthScreen extends ConsumerStatefulWidget`
- **Notable patterns:**
  - Multiple `AnimationController`s for fade, slide, scale, and rotation animations
  - `BackdropFilter` + `ImageFilter.blur` for glassmorphism card effect
  - Tab bar toggling between Sign In and Sign Up forms
  - Language switcher cycling en → ar → fr → en
  - Google and Apple social sign-in buttons
  - Form validation with `GlobalKey<FormState>`

---

### Feature: Home

#### `lib/features/home/data/models/restaurant.dart`
- **Purpose:** Manual (non-generated) `Restaurant` model for home screen listings.
- **Key class:** `Restaurant`
- **Fields:** `id`, `name`, `description`, `imageUrl`, `rating`, `reviewCount`, `deliveryTime`, `deliveryFee`, `minimumOrder`, `categories` (List<String>), `isOpen`, `latitude`, `longitude`
- **Methods:** `fromJson()`, `toJson()` (manual, mapping DB snake_case)

#### `lib/features/home/data/models/restaurant.freezed.dart`
- **Purpose:** Generated freezed version of the Restaurant model with `@JsonKey` annotations mapping DB columns to camelCase fields.

#### `lib/features/home/data/models/restaurant.g.dart`
- **Purpose:** Generated JSON serialization for the freezed `Restaurant` model.

#### `lib/features/home/presentation/home_screen.dart`
- **Purpose:** Root screen with `IndexedStack` managing 4 tabs.
- **Key classes:** `HomeScreen`
- **Tabs:** Home (restaurants/services), Favorites, Cart, Profile
- **Notable patterns:**
  - Floating bottom nav bar with `badges` package for cart item count
  - `ServiceSelector` widget for switching between 4 service types
  - Category filter chips on the food tab
  - Happy Hour promotional banner
  - Search bar with filtering on `restaurantsProvider`
  - Watches: `restaurantsProvider`, `selectedServiceProvider`, `cartItemCountProvider`, `unreadNotificationCountProvider`

#### `lib/features/home/presentation/widgets/service_selector.dart`
- **Purpose:** 4-card animated horizontal service selector.
- **Key classes:** `ServiceSelector extends ConsumerWidget`
- **Notable:** Gradient background activates on selected card; reads locale for trilingual service names.

#### `lib/features/home/presentation/widgets/bills_placeholder.dart`
- **Purpose:** Static placeholder widget for the Bills service section.

#### `lib/features/home/presentation/widgets/supermarket_placeholder.dart`
- **Purpose:** Static placeholder widget for the Supermarket section (superseded by `SupermarketListScreen`).

---

### Feature: Restaurant

#### `lib/features/restaurant/data/models/food_item.dart`
- **Purpose:** Food item model for restaurant menus.
- **Key class:** `FoodItem`
- **Fields:** `id`, `restaurantId`, `name`, `description`, `imageUrl`, `price`, `category`, `isAvailable`, `tags`, `preparationTime`, `isVegetarian`, `isSpicy`, `discountPrice`, `discountEndTime`, `discountQuantity`
- **Notable:** `discountPrice` and `discountEndTime` support Happy Hour time-limited deals; `discountQuantity` tracks remaining discounted units.

#### `lib/features/restaurant/data/models/food_item.freezed.dart`
- **Purpose:** Generated freezed class for `FoodItem`.

#### `lib/features/restaurant/data/models/food_item.g.dart`
- **Purpose:** Generated JSON serialization for `FoodItem`.

#### `lib/features/restaurant/data/restaurant_repository.dart`
- **Purpose:** Data access layer for restaurants and menu items.
- **Key class:** `RestaurantRepository`
- **Key methods:** `getRestaurants()`, `getFoodItems(restaurantId)`
- **Notable:** Explicit DB column mapping (`image_url` → `imageUrl`, etc.) in `fromJson` calls.

#### `lib/features/restaurant/providers/restaurant_provider.dart`
- **Purpose:** Riverpod providers for restaurant data.
- **Providers:** `restaurantRepositoryProvider`, `restaurantsProvider` (FutureProvider<List<Restaurant>>), `foodItemsProvider` (FutureProvider.family<List<FoodItem>, String>)

#### `lib/features/restaurant/presentation/restaurant_detail_screen.dart`
- **Purpose:** Full restaurant menu screen.
- **Key classes:** `RestaurantDetailScreen`
- **Notable patterns:**
  - Parallax `SliverAppBar` with `Hero` tag matching `RestaurantCard`
  - `SliverPersistentHeader` for sticky category tabs
  - Bottom sheet for quantity selection and customization before adding to cart
  - Share button via `share_plus`
  - Favorites toggle via `favoritesProvider`
  - Floating cart FAB with item count badge

#### `lib/features/restaurant/presentation/widgets/restaurant_card.dart`
- **Purpose:** Card widget for restaurant listings.
- **Key classes:** `RestaurantCard`
- **Notable:** `Hero` animation on image; delivery time badge, star rating, open/closed status overlay, delivery fee and minimum order display.

---

### Feature: Cart

#### `lib/features/cart/data/models/cart_item.dart`
- **Purpose:** Unified cart item supporting both restaurant food and grocery items.
- **Key class:** `CartItem` with `CartItemType` enum (restaurant, grocery)
- **Named constructors:** `CartItem.restaurant()`, `CartItem.grocery()`
- **Computed properties:** `id`, `name`, `price` (respects `discountPrice`), `imageUrl`, `totalPrice`

#### `lib/features/cart/data/models/order_customization.dart`
- **Purpose:** Represents a special instruction attached to a cart item — either text or voice.
- **Key class:** `OrderCustomization`, `CustomizationType` enum (text, voice)
- **Fields:** `type`, `content` (text string or audio file path), `timestamp`, `durationSeconds`
- **Methods:** `copyWith()`, `toJson()`, `fromJson()`

#### `lib/features/cart/providers/cart_provider.dart`
- **Purpose:** Cart state management.
- **Key classes:** `CartNotifier extends StateNotifier<List<CartItem>>`
- **Key methods:** `addItem()`, `removeItem()`, `updateQuantity()`, `clearCart()`
- **Providers:** `cartProvider`, `cartSubtotalProvider`, `cartItemCountProvider`, `cartTotalProvider` (subtotal + 3.0 DT delivery fee)

#### `lib/features/cart/presentation/cart_screen.dart`
- **Purpose:** Shopping cart screen.
- **Notable patterns:**
  - `Dismissible` swipe-to-remove for cart items
  - Inline quantity increment/decrement controls
  - "Add Customization" button per item
  - Order summary card with subtotal, delivery fee, total
  - Empty state illustration
  - Clear cart confirmation `AlertDialog`

#### `lib/features/cart/presentation/widgets/order_customization_widget.dart`
- **Purpose:** Bottom sheet for adding text or voice order customizations.
- **Key classes:** `OrderCustomizationWidget`
- **Notable patterns:**
  - Text/voice mode toggle
  - `FlutterSoundRecorder` + `FlutterSoundPlayer` for voice recording/playback
  - `permission_handler` for microphone access
  - Animated pulse effect (scale animation) during active recording
  - Playback controls (play/pause/stop) with visual progress
  - Delete recording option

---

### Feature: Checkout

#### `lib/features/checkout/data/models/address_model.freezed.dart`
- **Purpose:** Generated freezed model for Supabase `addresses` table records.
- **Key class:** `AddressModel` (freezed)
- **Fields:** `id`, `userId` (`user_id`), `name` (e.g., "Home"), `details` (full address), `latitude`, `longitude`, `isDefault` (`is_default`)

#### `lib/features/checkout/data/models/address_model.g.dart`
- **Purpose:** Generated JSON serialization for `AddressModel`.

#### `lib/features/checkout/presentation/checkout_screen.dart`
- **Purpose:** Order placement screen.
- **Notable patterns:**
  - Delivery address selection (navigates to `AddressSelectionScreen`)
  - Payment method section (cash on delivery only)
  - Order notes text field
  - Order summary (items, subtotal, delivery fee, total)
  - Creates `Order` with UUID on confirm and navigates to `OrderTrackingScreen`

#### `lib/features/checkout/presentation/address_selection_screen.dart`
- **Purpose:** Address picker with GPS current location and saved addresses.
- **Notable patterns:**
  - `LocationService.getCurrentPosition()` for current GPS location
  - Saved addresses list from profile
  - `_AddAddressSheet` inline bottom sheet form for new addresses
  - Mock Tunis coordinates as fallback

---

### Feature: Orders

#### `lib/features/orders/data/models/order.dart`
- **Purpose:** Core order model used across all service types.
- **Key class:** `Order`
- **Enums:** `OrderStatus` (pending, confirmed, preparing, ready, pickedUp, onTheWay, delivered, cancelled), `OrderType` (food, supermarket, courier, billPayment)
- **Notable fields:** `pickupAddress`, `recipientName`, `recipientPhone`, `packageDescription`, `isRecipientAccepted` (courier-specific)

#### `lib/features/orders/data/models/order_model.freezed.dart`
- **Purpose:** Generated freezed model for Supabase `orders` table records.
- **Key class:** `OrderModel` (freezed)
- **Fields:** `id`, `userId`, `restaurantId`, `driverId`, `status`, `totalAmount`, `deliveryFee`, `paymentMethod`, `paymentStatus`, `deliveryAddress` (Map snapshot), `createdAt`

#### `lib/features/orders/data/models/order_model.g.dart`
- **Purpose:** Generated JSON serialization for `OrderModel`.

#### `lib/features/orders/data/models/order_item_model.freezed.dart`
- **Purpose:** Generated freezed model for Supabase `order_items` table records.
- **Key class:** `OrderItemModel` (freezed)
- **Fields:** `id`, `orderId`, `foodItemId`, `name`, `price`, `quantity`, `options` (List<String>)

#### `lib/features/orders/data/models/order_item_model.g.dart`
- **Purpose:** Generated JSON serialization for `OrderItemModel`.

#### `lib/features/orders/data/order_repository.dart`
- **Purpose:** Full Supabase CRUD and realtime for orders.
- **Key class:** `OrderRepository`
- **Key methods:**
  - `createOrder()` — inserts to `orders` then `order_items` in sequence; supports both `food_item_id` and `grocery_item_id`
  - `getUserOrders()` — fetches with `restaurants(name)` join
  - `updateOrderStatus()` — PATCH by order ID
  - `streamOrder()` — Supabase Realtime stream on single order row
- **Notable:** `_mapOrderFromDb()` helper handles all DB snake_case → camelCase field renaming.

#### `lib/features/orders/providers/order_provider.dart`
- **Purpose:** Riverpod providers for order data.
- **Providers:** `orderRepositoryProvider`, `orderStreamProvider` (StreamProvider.family<Order, String>), `userOrdersProvider` (FutureProvider)

#### `lib/features/orders/presentation/order_tracking_screen.dart`
- **Purpose:** Live order tracking with Google Maps.
- **Key classes:** `OrderTrackingScreen`
- **Notable patterns:**
  - `GoogleMap` widget with `Marker`s for restaurant, driver, and delivery address
  - `DraggableScrollableSheet` for collapsible detail panel
  - `_OrderTimeline` widget with animated step indicators for each `OrderStatus`
  - Simulated driver movement via periodic `Timer` updating map camera and marker position
  - Courier-specific "Simulate Recipient Acceptance" button
  - Polyline between markers for route visualization

#### `lib/features/orders/presentation/order_history_screen.dart`
- **Purpose:** Past orders list screen.
- **Key classes:** `OrderHistoryScreen`, `_OrderCard`
- **Notable patterns:**
  - Uses `userOrdersProvider`
  - Status badges color-coded per `OrderStatus`
  - Type-specific icons (food/grocery/courier/bills)
  - Date formatting with `intl` `DateFormat`
  - Tap navigates to `OrderTrackingScreen` for order detail

---

### Feature: Profile

#### `lib/features/profile/data/profile_repository.dart`
- **Purpose:** Supabase data access for user profiles.
- **Key class:** `ProfileRepository`
- **Key methods:** `getUserProfile()`, `updateProfile()` (partial update via map), `uploadProfilePicture()` (uploads to `avatars` bucket, returns public URL, updates profile)
- **Dependencies:** `supabase_flutter`, `dart:io`

#### `lib/features/profile/presentation/profile_screen.dart`
- **Purpose:** Profile overview screen.
- **Notable patterns:**
  - `SliverAppBar` with gradient background and circular avatar
  - Menu items: Order History, Edit Profile, Saved Addresses, Payment Methods, Notifications, Language, Theme, Help & Support, Logout
  - Language bottom sheet with 3 locale options calling `localizationProvider`
  - Theme toggle calling `themeProvider`

#### `lib/features/profile/presentation/edit_profile_screen.dart`
- **Purpose:** Profile edit form.
- **Notable patterns:**
  - `ImagePicker` for selecting profile photo from gallery or camera
  - Form fields: full name, email, phone, bio
  - Mock save (not yet wired to `ProfileRepository`)

#### `lib/features/profile/presentation/saved_addresses_screen.dart`
- **Purpose:** Manage saved delivery addresses.
- **Notable patterns:**
  - `Dismissible` swipe-to-delete
  - Set as default button
  - Add address dialog
  - Data from `addressProvider`

#### `lib/features/profile/presentation/payment_methods_screen.dart`
- **Purpose:** Manage saved payment methods.
- **Notable patterns:**
  - Credit card list with gradient card UI
  - Add card dialog (card number, expiry, CVV)
  - `Dismissible` to delete
  - Data from `paymentProvider`

#### `lib/features/profile/presentation/help_support_screen.dart`
- **Purpose:** Help & support contact screen.
- **Fields:** Subject and message text form
- **Contact info:** `support@cmandili.com`, `+216 71 123 456`

#### `lib/features/profile/providers/address_provider.dart`
- **Purpose:** Saved addresses state management.
- **Key classes:** `Address` model, `AddressNotifier extends StateNotifier<List<Address>>`
- **Notable:** Pre-loaded with 2 mock addresses (Home and Work in Tunis); methods: `addAddress()`, `deleteAddress()`, `setDefault()`

#### `lib/features/profile/providers/payment_provider.dart`
- **Purpose:** Payment methods state management.
- **Key classes:** `PaymentMethod` model, `PaymentNotifier extends StateNotifier<List<PaymentMethod>>`
- **Notable:** Pre-loaded with 1 mock Visa card; methods: `addCard()`, `deleteCard()`

---

### Feature: Favorites

#### `lib/features/favorites/presentation/favorites_screen.dart`
- **Purpose:** Saved/favorited restaurants list.
- **Notable:** Currently shows first 2 results from `restaurantsProvider` as mock favorites; empty state with icon.

#### `lib/features/favorites/providers/favorites_provider.dart`
- **Purpose:** Favorites state management.
- **Key classes:** `FavoritesNotifier extends StateNotifier<List<Restaurant>>`
- **Key methods:** `toggleFavorite(Restaurant)`
- **Providers:** `favoritesProvider`, `isFavoriteProvider` (Provider.family<bool, String> for restaurant ID lookup)

---

### Feature: Notifications

#### `lib/features/notifications/data/models/notification.dart`
- **Purpose:** In-app notification model.
- **Key class:** `AppNotification`, `NotificationType` enum (orderUpdate, promotion, system)
- **Fields:** `id`, `title`, `message`, `type`, `timestamp`, `isRead`, `orderId` (optional)

#### `lib/features/notifications/data/notification_repository.dart`
- **Purpose:** Supabase CRUD for notifications.
- **Key class:** `NotificationRepository`
- **Key methods:** `getUserNotifications()`, `markAsRead(id)`, `deleteNotification(id)`, `getUnreadCount()`

#### `lib/features/notifications/providers/notification_provider.dart`
- **Purpose:** Notifications state with 5 pre-loaded mock entries.
- **Key classes:** `NotificationNotifier`
- **Key methods:** `markAsRead()`, `deleteNotification()`, `markAllAsRead()`
- **Providers:** `notificationProvider`, `unreadNotificationCountProvider` (derived computed provider)

#### `lib/features/notifications/presentation/notification_screen.dart`
- **Purpose:** Grouped notification list.
- **Notable patterns:**
  - Groups notifications by date: Today, Yesterday, weekday name, or formatted date
  - `_NotificationCard` with `Dismissible` swipe-to-delete
  - Animated read/unread visual state (dimming + color)
  - Type-specific icons per `NotificationType`
  - "Mark all read" action in AppBar

---

### Feature: Bills

#### `lib/features/bills/data/models/bill_provider.dart`
- **Purpose:** Bill payment provider model.
- **Key class:** `BillProvider`, `BillCategory` enum (internet, electricity, water)
- **Notable:** Static list of 5 Tunisian utility/telecom providers: Ooredoo, Telecom Tunisia, Orange, STEG, SONEDE

#### `lib/features/bills/presentation/bill_payment_screen.dart`
- **Purpose:** Bill payment flow screen.
- **Notable patterns:**
  - Category tab selector (internet/electricity/water)
  - Provider grid with logos
  - Amount input field
  - Creates `Order` of type `billPayment` with 2.0 DT service fee
  - Navigates to `OrderTrackingScreen` on confirm

---

### Feature: Courier

#### `lib/features/courier/presentation/courier_screen.dart`
- **Purpose:** P2P parcel delivery request form.
- **Notable patterns:**
  - Form fields: recipient name, recipient phone, package description
  - Pickup address auto-set from `LocationService.getCurrentPosition()`
  - Dropoff address picker via `AddressSelectionScreen`
  - Fixed pricing: base 10 DT + 5 DT service fee = 15 DT total
  - Creates `Order` of type `courier` and navigates to `OrderTrackingScreen`

---

### Feature: Happy Hour

#### `lib/features/happy_hour/presentation/happy_hour_screen.dart`
- **Purpose:** Time-limited discounts screen.
- **Notable patterns:**
  - `NestedScrollView` with parallax header
  - Two tabs: Restaurants and Supermarkets
  - Uses `happyHourRestaurantsProvider` and `happyHourSupermarketsProvider`

#### `lib/features/happy_hour/presentation/widgets/happy_hour_card.dart`
- **Purpose:** Individual deal card with live countdown.
- **Key class:** `HappyHourCard extends StatefulWidget`
- **Notable patterns:**
  - Live countdown timer updating every second via `Timer.periodic`
  - Discount percentage badge
  - "Only X left!" quantity indicator from `discountQuantity`
  - Strikethrough original price + highlighted discounted price
  - "Grab it!" CTA button

#### `lib/features/happy_hour/providers/happy_hour_provider.dart`
- **Purpose:** Mock data providers for happy hour deals.
- **Providers:** `happyHourRestaurantsProvider`, `happyHourSupermarketsProvider` (both FutureProvider returning mock items with `discountPrice` and `discountEndTime` set)

---

### Feature: Supermarket

#### `lib/features/supermarket/data/models/grocery_category.dart`
- **Purpose:** Grocery category definitions with trilingual names.
- **Key class:** `GroceryCategory` enum (vegetables, fruits, dairy, beverages, bakery, meat, snacks, household)
- **Extension:** Provides `nameEn`, `nameAr`, `nameFr`, `icon` for each category

#### `lib/features/supermarket/data/models/grocery_item.dart`
- **Purpose:** Grocery product model.
- **Key class:** `GroceryItem`
- **Fields:** `id`, `supermarketId`, `name`, `description`, `imageUrl`, `price`, `category`, `isAvailable`, `unit` (kg/piece/liter), `isOrganic`, `discountPrice`

#### `lib/features/supermarket/data/models/supermarket.dart`
- **Purpose:** Supermarket listing model (mirrors `Restaurant` structure).
- **Key class:** `Supermarket`
- **Fields:** `id`, `name`, `description`, `imageUrl`, `rating`, `reviewCount`, `deliveryTime`, `deliveryFee`, `minimumOrder`, `isOpen`, `latitude`, `longitude`

#### `lib/features/supermarket/data/supermarket_repository.dart`
- **Purpose:** Supabase data access for supermarkets and grocery items.
- **Key class:** `SupermarketRepository`
- **Key methods:** `getSupermarkets()`, `getGroceryItems(supermarketId)`

#### `lib/features/supermarket/providers/supermarket_provider.dart`
- **Purpose:** Riverpod providers for supermarket data.
- **Providers:** `supermarketsProvider` (FutureProvider), `groceryItemsProvider` (FutureProvider.family<List<GroceryItem>, String>)

#### `lib/features/supermarket/presentation/supermarket_list_screen.dart`
- **Purpose:** Supermarket listing widget (renders as `SliverList` for composition into `HomeScreen`'s `CustomScrollView`).
- **Key classes:** `SupermarketListScreen extends ConsumerWidget`, `_SupermarketCard`
- **Notable:** Returns sliver widgets, not a full screen, for `CustomScrollView` integration.

#### `lib/features/supermarket/presentation/supermarket_detail_screen.dart`
- **Purpose:** Supermarket product browsing screen.
- **Notable patterns:**
  - `SliverGrid` (2-column) for product display
  - `GroceryCategory` filter chips
  - `_ProductCard` with organic badge, unit label
  - Add to cart via `cartProvider`
  - Floating cart FAB with `badges` package for item count

---

### Localization

#### `lib/l10n/app_en.arb` (source of truth, 58 keys)
Key string groups: auth (signIn, signUp, createAccount, email, password, fullName), navigation (home, favorites, cart, profile, notifications), cart (subtotal, deliveryFee, total, proceedToCheckout, clearCart), customization (specialInstructions, typeMessage, voiceMessage, tapToRecord, tapAgainToStop, microphonePermissionDenied)

#### `lib/l10n/app_ar.arb`
Arabic translations of all 58 keys.

#### `lib/l10n/app_fr.arb`
French translations of all 58 keys.

#### `lib/l10n/app_localizations.dart`
Abstract base class `AppLocalizations` generated by `flutter_localizations` / `intl` tooling. Declares abstract getters for all 58 localization keys.

#### `lib/l10n/app_localizations_en.dart`
Concrete English implementation of `AppLocalizations`.

#### `lib/l10n/app_localizations_ar.dart`
Concrete Arabic implementation of `AppLocalizations`.

#### `lib/l10n/app_localizations_fr.dart`
Concrete French implementation of `AppLocalizations`.

---

## Key Dependencies Summary

| Package | Version | Usage |
|---|---|---|
| `flutter_riverpod` | ^2.4.9 | State management (StateNotifier, FutureProvider, StreamProvider) |
| `supabase_flutter` | ^2.3.0 | Backend: auth, database, storage, realtime |
| `google_maps_flutter` | ^2.5.0 | Order tracking map |
| `geolocator` | ^11.0.0 | GPS location |
| `geocoding` | ^3.0.0 | Address ↔ coordinate conversion |
| `go_router` | ^12.1.3 | Route definitions (reference only; not active) |
| `google_sign_in` | ^6.2.1 | Google OAuth |
| `cached_network_image` | ^3.3.1 | Image caching |
| `flutter_sound` | ^9.2.13 | Voice message recording/playback |
| `permission_handler` | ^11.3.0 | Microphone, location permissions |
| `freezed` | ^2.4.7 | Immutable model code generation |
| `json_serializable` | ^6.7.1 | JSON serialization code generation |
| `intl` | ^0.19.0 | Date/number formatting, localization |
| `shared_preferences` | ^2.2.2 | Persisting theme and locale |
| `image_picker` | ^1.0.7 | Profile photo selection |
| `share_plus` | ^7.2.2 | Native share sheet |
| `uuid` | ^4.3.3 | Order ID generation |
| `lottie` | ^3.0.0 | Lottie animations |
| `shimmer` | ^3.0.0 | Loading skeleton effect |
| `badges` | ^3.1.2 | Cart count badge on FAB/nav |
| `path_provider` | ^2.1.2 | File system paths for audio files |

---

## Architecture Patterns

**Feature-First Structure:** Every feature is a self-contained directory with `data/`, `presentation/`, and `providers/` subdirectories.

**Repository Pattern:** Each feature's `data/` layer contains a `*_repository.dart` that abstracts all Supabase queries. Providers expose repositories via `Provider<*Repository>`.

**Riverpod 2.x Patterns:**
- `StateNotifierProvider` — mutable UI state (cart, favorites, notifications, addresses, payments)
- `FutureProvider` / `FutureProvider.family` — one-shot async data (restaurants, food items, grocery items)
- `StreamProvider` / `StreamProvider.family` — realtime data (auth state, order tracking)
- `Provider.family` — derived/filtered state (e.g., `isFavoriteProvider`, `foodItemsProvider`)

**Freezed Models:** Core DB-mapped models use `@freezed` annotation with `@JsonKey` for snake_case ↔ camelCase mapping. Generated `.freezed.dart` and `.g.dart` files are committed.

**Dual Model Pattern:** Several features have both a manual model (e.g., `restaurant.dart`) and a freezed model (e.g., `restaurant.freezed.dart`) — indicating a freezed migration in progress.

**Navigation:** Imperative `Navigator.push` throughout; GoRouter defined but not wired up.

---

## Supabase Database Tables

Based on repository code analysis:

| Table | Description |
|---|---|
| `profiles` | User profile records (FK: `auth.users`) |
| `restaurants` | Restaurant listings |
| `food_items` | Menu items (FK: `restaurant_id`) |
| `supermarkets` | Supermarket listings |
| `grocery_items` | Grocery products (FK: `supermarket_id`) |
| `orders` | All order types: food, supermarket, courier, billPayment |
| `order_items` | Line items per order (FK: `order_id`; supports `food_item_id` and `grocery_item_id`) |
| `notifications` | User notification records |
| `addresses` | User saved delivery addresses |

**Storage bucket:** `avatars` — profile pictures

---

## Notable Technical Highlights

1. **Super-app architecture:** Single Flutter app covering 4 service verticals (food delivery, supermarket, bill payments, P2P courier) with a shared cart, order tracking, and profile system.

2. **Realtime order tracking:** Combines Supabase Realtime stream on the `orders` table with Google Maps and a `Timer`-based driver position simulation.

3. **Voice order customization:** Full voice note recording and playback (Flutter Sound) integrated into the cart item customization flow.

4. **Happy Hour system:** Time-limited discounted items with live countdown timers, per-item discount quantities, and dedicated screen.

5. **Trilingual RTL support:** Full Arabic support with `Directionality` via Flutter's localization system; locale persisted across sessions via `SharedPreferences`.

6. **Material 3 theming:** Complete light/dark theme with brand orange (`#FF6B35`) as the primary color, fully spec'd sub-themes.

7. **Tunisian market focus:** Currency in DT, Tunisian utility providers (STEG, SONEDE, Ooredoo, Orange, Telecom Tunisia), Tunis coordinates as defaults, French locale (`fr_TN`) for number formatting.

---

*Generated from reading all 82+ Dart source files in the `lib/` directory of the `cmandili_mobile` Flutter project.*
