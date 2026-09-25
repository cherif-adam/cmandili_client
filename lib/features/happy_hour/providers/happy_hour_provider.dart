import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../restaurant/data/models/food_item.dart';
import '../../supermarket/data/models/grocery_item.dart';
import '../../supermarket/data/models/grocery_category.dart';

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
    discountEndTime: json['discount_end_time'] != null
        ? DateTime.parse(json['discount_end_time'])
        : null,
    discountQuantity: json['discount_quantity'],
  )).toList();
});

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
      .gt('discount_end_time', now)
      .eq('is_available', true)
      .order('discount_end_time', ascending: true);

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
