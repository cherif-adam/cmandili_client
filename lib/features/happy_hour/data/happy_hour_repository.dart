import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads the live deals behind the Happy Hour and Promotions screens. Each
/// method returns the raw rows; the providers filter them (distance, daily
/// window) and build the models. [nowUtcIso] must be a UTC ISO-8601 string:
/// it is compared against TIMESTAMPTZ columns (see happyHourRestaurantsProvider).
class HappyHourRepository {
  final _supabase = Supabase.instance.client;

  /// food_items on a timed discount (with or without an end date) or on a
  /// daily happy-hour window.
  Future<List<Map<String, dynamic>>> fetchFoodDeals(String nowUtcIso) {
    return _supabase
        .from('food_items')
        .select()
        .eq('is_available', true)
        .or('and(discount_price.not.is.null,discount_end_time.gt.$nowUtcIso),'
            // No end date = runs until the partner stops it (or its limited
            // quantity sells out and the DB clears it).
            'and(discount_price.not.is.null,discount_end_time.is.null),'
            'is_happy_hour.is.true');
  }

  /// grocery_items on a discount that has not ended, soonest end first.
  Future<List<Map<String, dynamic>>> fetchGroceryDeals(String nowUtcIso) {
    return _supabase
        .from('grocery_items')
        .select()
        .not('discount_price', 'is', null)
        // No end date = runs until the partner stops it.
        .or('discount_end_time.is.null,discount_end_time.gt.$nowUtcIso')
        .eq('is_available', true)
        .order('discount_end_time', ascending: true, nullsFirst: false);
  }

  /// vendor_items of every other shop category on a discount that has not
  /// ended, soonest end first.
  Future<List<Map<String, dynamic>>> fetchShopDeals(String nowUtcIso) {
    return _supabase
        .from('vendor_items')
        .select('*, vendors!inner(category)')
        .not('discount_price', 'is', null)
        .or('discount_end_time.is.null,discount_end_time.gt.$nowUtcIso')
        .not('vendors.category', 'in', '(food,grocery)')
        .eq('is_available', true)
        .order('discount_end_time', ascending: true, nullsFirst: false);
  }
}
