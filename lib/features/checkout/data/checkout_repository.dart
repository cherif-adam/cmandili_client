import 'package:supabase_flutter/supabase_flutter.dart';

/// The two `vendors` reads the checkout makes just before placing an order.
/// Every shop — restaurant, supermarket, florist, pet shop — is a row in
/// `vendors`, so one lookup covers all of them. Errors are thrown: the
/// caller decides what a failed read means.
class CheckoutRepository {
  final _supabase = Supabase.instance.client;

  /// `vendors.is_open` for [vendorId]; null when there is no such row or the
  /// column is empty.
  Future<bool?> vendorIsOpen(String vendorId) async {
    final row = await _supabase
        .from('vendors')
        .select('is_open')
        .eq('id', vendorId)
        .maybeSingle();
    return row?['is_open'] as bool?;
  }

  /// The `latitude, longitude, category` row of [vendorId], untouched; null
  /// when there is no such row.
  Future<Map<String, dynamic>?> vendorPickupRow(String vendorId) {
    return _supabase
        .from('vendors')
        .select('latitude, longitude, category')
        .eq('id', vendorId)
        .maybeSingle();
  }
}
