import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/platform_pricing.dart';
import '../../restaurant/data/models/food_item.dart';
import '../../supermarket/data/models/grocery_item.dart';
import '../../supermarket/data/models/grocery_category.dart';
import '../../../core/models/vendor.dart';

// Queries food_items where discount_price is set and discount_end_time is in the future
final happyHourRestaurantsProvider = FutureProvider<List<FoodItem>>((ref) async {
  final supabase = Supabase.instance.client;
  // .toUtc() matters even though nothing is written here: this string is
  // compared against a TIMESTAMPTZ column. A LOCAL timestamp serializes
  // without an offset, so Postgres read it as UTC and "now" looked an hour
  // later than it was in Tunisia (UTC+1) — happy-hour items disappeared from
  // the list a full hour before their discount actually ended.
  final now = DateTime.now().toUtc().toIso8601String();

  // TWO mechanisms put an item on happy hour, and this list has to honour
  // both or the partner's work silently goes nowhere:
  //
  //   a) HappyHourSetupScreen writes discount_price + discount_end_time --
  //      an absolute deadline. That is what this query always matched.
  //   b) The add/edit item screen's Happy Hour switch writes is_happy_hour +
  //      happy_hour_price + happy_hour_start/happy_hour_end -- a daily
  //      window with no date. Items configured that way never appeared here
  //      at all, however correctly the partner filled the form.
  //
  // (b) cannot be filtered server-side on time: happy_hour_start/end are
  // plain `time` columns holding Tunis local wall-clock, so the window is
  // closed below against the device clock instead.
  final response = await supabase
      .from('food_items')
      .select()
      .eq('is_available', true)
      .or('and(discount_price.not.is.null,discount_end_time.gt.$now),'
          // No end date = runs until the partner stops it (or its limited
          // quantity sells out and the DB clears it).
          'and(discount_price.not.is.null,discount_end_time.is.null),'
          'is_happy_hour.is.true');

  final rows = (response as List).where((json) {
    if (json['discount_price'] != null) return true; // (a), already time-filtered
    return _withinHappyHourWindow(
      json['happy_hour_start'] as String?,
      json['happy_hour_end'] as String?,
    );
  }).toList()
    // Soonest to expire first, as before. Items on mechanism (b) have no end
    // date, so they sort after the timed ones rather than being dropped.
    ..sort((a, b) {
      final ae = a['discount_end_time'] as String?;
      final be = b['discount_end_time'] as String?;
      if (ae == null && be == null) return 0;
      if (ae == null) return 1;
      if (be == null) return -1;
      return ae.compareTo(be);
    });

  return rows.map((json) => FoodItem(
    id: json['id'] ?? '',
    restaurantId: json['restaurant_id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    imageUrl: json['image_url'] ?? '',
    price: (json['price'] ?? 0).toDouble(),
    category: json['category'] ?? '',
    isAvailable: json['is_available'] ?? true,
    tags: List<String>.from(json['tags'] ?? []),
    preparationTime: json['preparation_time'] ?? 15,
    isVegetarian: json['is_vegetarian'] ?? false,
    isSpicy: json['is_spicy'] ?? false,
    // An item on mechanism (b) carries its reduced price in happy_hour_price;
    // the card only knows about discountPrice, so it is fed from whichever
    // mechanism is actually active.
    discountPrice: json['discount_price'] != null
        ? (json['discount_price'] as num).toDouble()
        : json['happy_hour_price'] != null
            ? (json['happy_hour_price'] as num).toDouble()
            : null,
    // Daily-window items have no absolute deadline, but the Happy Hour card
    // needs one (it force-unwraps it for the countdown) — so they get the end
    // of *today's* window, which is exactly when the deal stops.
    discountEndTime: json['discount_end_time'] != null
        ? DateTime.parse(json['discount_end_time'])
        : json['discount_price'] != null
            ? null // timed-discount deal with no end date: no countdown
            : _todaysWindowEnd(
                json['happy_hour_start'] as String?,
                json['happy_hour_end'] as String?,
              ),
    discountQuantity: json['discount_quantity'],
  )).toList();
});

/// End of the daily happy-hour window currently running, as a local
/// DateTime. A window crossing midnight (22:00 -> 02:00) that is in its
/// evening half ends tomorrow. Null when the times are missing/unparseable.
DateTime? _todaysWindowEnd(String? start, String? end) {
  if (start == null || end == null) return null;
  List<int>? hm(String v) {
    final p = v.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    return (h == null || m == null) ? null : [h, m];
  }

  final s = hm(start);
  final e = hm(end);
  if (s == null || e == null) return null;
  final now = DateTime.now();
  var endAt = DateTime(now.year, now.month, now.day, e[0], e[1]);
  final crossesMidnight = e[0] * 60 + e[1] < s[0] * 60 + s[1];
  if (crossesMidnight && now.hour * 60 + now.minute >= s[0] * 60 + s[1]) {
    endAt = endAt.add(const Duration(days: 1));
  }
  return endAt;
}

/// True when the device's local wall-clock is inside [start]..[end], both
/// 'HH:MM:SS' as stored in happy_hour_start / happy_hour_end.
///
/// A window that ends before it starts (22:00 -> 02:00) crosses midnight and
/// is treated as such; comparing naively would report it closed all night,
/// which is exactly when it should be open.
bool _withinHappyHourWindow(String? start, String? end) {
  if (start == null || end == null) return false;
  int? minutes(String hhmmss) {
    final parts = hhmmss.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  final from = minutes(start);
  final to = minutes(end);
  if (from == null || to == null) return false;

  final nowLocal = DateTime.now();
  final current = nowLocal.hour * 60 + nowLocal.minute;
  return from <= to
      ? current >= from && current < to
      : current >= from || current < to;
}

// Queries grocery_items where discount_price is set and discount_end_time is in the future
final happyHourSupermarketsProvider = FutureProvider<List<GroceryItem>>((ref) async {
  final supabase = Supabase.instance.client;
  // .toUtc() — see happyHourRestaurantsProvider above.
  final now = DateTime.now().toUtc().toIso8601String();

  final response = await supabase
      .from('grocery_items')
      .select()
      .not('discount_price', 'is', null)
      // No end date = runs until the partner stops it.
      .or('discount_end_time.is.null,discount_end_time.gt.$now')
      .eq('is_available', true)
      .order('discount_end_time', ascending: true, nullsFirst: false);

  return (response as List).map((json) => GroceryItem(
    id: json['id'] ?? '',
    supermarketId: json['supermarket_id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    imageUrl: json['image_url'] ?? '',
    price: (json['price'] ?? 0).toDouble(),
    category: GroceryCategory.values.firstWhere(
      (e) => e.toString().split('.').last == (json['category'] ?? ''),
      orElse: () => GroceryCategory.vegetables,
    ),
    unit: json['unit'] ?? 'piece',
    isOrganic: json['is_organic'] ?? false,
    isAvailable: json['is_available'] ?? true,
    discountPrice: json['discount_price'] != null
        ? (json['discount_price'] as num).toDouble()
        : null,
    discountEndTime: json['discount_end_time'] != null
        ? DateTime.parse(json['discount_end_time'])
        : null,
    discountQuantity: json['discount_quantity'],
  )).toList();
});

/// Happy-hour deals from every other shop category (gifts, flowers, pets,
/// bakery, electronics). Their items live only in `vendor_items`; the
/// food_items / grocery_items views are filtered to restaurants and
/// supermarkets, so without this a boutique's happy hour never reached a
/// customer at all.
final happyHourShopsProvider = FutureProvider<List<VendorItem>>((ref) async {
  final supabase = Supabase.instance.client;
  final now = DateTime.now().toUtc().toIso8601String(); // see above re .toUtc()

  final response = await supabase
      .from('vendor_items')
      .select('*, vendors!inner(category)')
      .not('discount_price', 'is', null)
      .or('discount_end_time.is.null,discount_end_time.gt.$now')
      .not('vendors.category', 'in', '(food,grocery)')
      .eq('is_available', true)
      .order('discount_end_time', ascending: true, nullsFirst: false);

  return (response as List)
      .map((json) => VendorItem.fromDb(json as Map<String, dynamic>))
      .where((item) => item.hasActiveDiscount)
      .toList();
});

/// One live happy-hour offer, flattened across food and grocery so the home
/// screen can show "what's on right now" without caring where it came from.
/// Prices are the customer-facing ones (platform markup applied), matching
/// what the Happy Hour screen shows.
class HappyHourDeal {
  final String id;
  final String name;
  final String imageUrl;
  final double price;
  final double dealPrice;

  /// Absolute deadline for timed deals; null for daily-window deals, which
  /// carry no date (see happyHourRestaurantsProvider).
  final DateTime? endsAt;

  /// Happy Hour screen tab that lists this deal: 0 restaurants,
  /// 1 supermarkets, 2 other shops.
  final int tab;

  const HappyHourDeal({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.dealPrice,
    required this.endsAt,
    required this.tab,
  });

  int get percentOff =>
      price <= 0 ? 0 : (((price - dealPrice) / price) * 100).round();
}

/// Every happy-hour deal live right now, food first, for the home screen.
///
/// The home banner used to be a static picture that looked identical with
/// zero deals or twenty, so customers had no way to tell a happy hour was
/// actually on. This feeds it real data, and re-queries every minute so a
/// deal a partner starts shows up (and an ended one drops off) without the
/// customer restarting the app. Refreshing the two source providers also
/// keeps the Happy Hour screen itself current.
///
/// Returns the last known list while a refresh is in flight, so the banner
/// never flickers back to its "no deals" state between polls.
final happyHourLiveDealsProvider = Provider<List<HappyHourDeal>>((ref) {
  final timer = Timer.periodic(const Duration(minutes: 1), (_) {
    ref.invalidate(happyHourRestaurantsProvider);
    ref.invalidate(happyHourSupermarketsProvider);
    ref.invalidate(happyHourShopsProvider);
  });
  ref.onDispose(timer.cancel);

  final food = ref.watch(happyHourRestaurantsProvider).valueOrNull ?? const [];
  final grocery =
      ref.watch(happyHourSupermarketsProvider).valueOrNull ?? const [];
  final shops = ref.watch(happyHourShopsProvider).valueOrNull ?? const [];
  final now = DateTime.now();

  bool live(double? dealPrice, double price, DateTime? endsAt) =>
      dealPrice != null &&
      dealPrice < price &&
      (endsAt == null || endsAt.isAfter(now));

  return [
    for (final f in food)
      if (live(f.discountPrice, f.price, f.discountEndTime))
        HappyHourDeal(
          id: f.id,
          name: f.name,
          imageUrl: f.imageUrl,
          price: applyPlatformMarkup(f.price),
          dealPrice: f.clientPrice,
          endsAt: f.discountEndTime,
          tab: 0,
        ),
    for (final g in grocery)
      if (live(g.discountPrice, g.price, g.discountEndTime))
        HappyHourDeal(
          id: g.id,
          name: g.name,
          imageUrl: g.imageUrl,
          price: applyPlatformMarkup(g.price),
          dealPrice: g.clientPrice,
          endsAt: g.discountEndTime,
          tab: 1,
        ),
    for (final v in shops)
      if (live(v.discountPrice, v.price, v.discountEndTime))
        HappyHourDeal(
          id: v.id,
          name: v.name,
          imageUrl: v.imageUrl,
          price: applyPlatformMarkup(v.price),
          dealPrice: applyPlatformMarkup(v.effectivePrice),
          endsAt: v.discountEndTime,
          tab: 2,
        ),
  ];
});
