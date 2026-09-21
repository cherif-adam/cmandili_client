import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vendor.dart';

/// Reads shops and their items from the generic `vendors` / `vendor_items`
/// tables. One repository serves every category, which is the whole point of
/// the generic schema: adding flowers or pet supplies needs no new code here.
class VendorRepository {
  final SupabaseClient _supabase;

  VendorRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  /// All active categories, ordered for display. Falls back to the built-in
  /// catalogue if the table cannot be read, so the home screen is never blank.
  Future<List<VendorCategory>> getCategories() async {
    try {
      final rows = await _supabase
          .from('vendor_categories')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      final list = (rows as List)
          .map((r) => VendorCategory.fromDb(r as Map<String, dynamic>))
          .toList();
      return list.isEmpty ? VendorCategory.fallback : list;
    } catch (_) {
      return VendorCategory.fallback;
    }
  }

  /// Shops in one category, newest first.
  Future<List<Vendor>> getVendors(String category) async {
    final rows = await _supabase
        .from('vendors')
        .select()
        .eq('category', category)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Vendor.fromDb(r as Map<String, dynamic>))
        .toList();
  }

  /// Live version of [getVendors] — pushes a new list the moment a shop is
  /// added, edited or removed.
  ///
  /// The category filter is applied client-side because Supabase's realtime
  /// `.stream()` only supports one `eq` on the primary key path; filtering
  /// server-side here would silently drop updates.
  Stream<List<Vendor>> watchVendors(String category) {
    return _supabase
        .from('vendors')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((r) => Vendor.fromDb(r))
            .where((v) => v.category == category)
            .toList());
  }

  /// Every shop across all categories — used by search and the "near you"
  /// row, which are deliberately category-agnostic.
  Future<List<Vendor>> getAllVendors() async {
    final rows = await _supabase
        .from('vendors')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Vendor.fromDb(r as Map<String, dynamic>))
        .toList();
  }

  Future<Vendor?> getVendor(String id) async {
    final row =
        await _supabase.from('vendors').select().eq('id', id).maybeSingle();
    return row == null ? null : Vendor.fromDb(row);
  }

  /// Items belonging to one shop, available ones only, grouped by their
  /// in-shop section.
  Future<List<VendorItem>> getItems(String vendorId) async {
    final rows = await _supabase
        .from('vendor_items')
        .select()
        .eq('vendor_id', vendorId)
        .eq('is_available', true)
        .order('sort_order', ascending: true);
    return (rows as List)
        .map((r) => VendorItem.fromDb(r as Map<String, dynamic>))
        .toList();
  }
}
