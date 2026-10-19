import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/vendor.dart';
import '../../../../core/providers/vendor_provider.dart';

/// The shop page's logic, per vendor id: its catalogue (from
/// [vendorItemsProvider], VendorRepository behind it), the retry and the
/// grouping into in-shop sections.
final vendorDetailControllerProvider = NotifierProvider.autoDispose
    .family<VendorDetailController, AsyncValue<List<VendorItem>>, String>(
        VendorDetailController.new);

class VendorDetailController
    extends AutoDisposeFamilyNotifier<AsyncValue<List<VendorItem>>, String> {
  // ── State ─────────────────────────────────────────────────────────────────

  @override
  AsyncValue<List<VendorItem>> build(String vendorId) =>
      ref.watch(vendorItemsProvider(vendorId));

  // ── User actions ──────────────────────────────────────────────────────────

  void retry() => ref.invalidate(vendorItemsProvider(arg));

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// One entry per in-shop section ("Roses", "Croquettes"), in the order the
  /// rows came back (sort_order), so the shop controls how its catalogue
  /// reads. Items without a section go under [defaultSection].
  Map<String, List<VendorItem>> sections(
      List<VendorItem> items, String defaultSection) {
    final grouped = <String, List<VendorItem>>{};
    for (final item in items) {
      final key = (item.category?.trim().isNotEmpty ?? false)
          ? item.category!.trim()
          : defaultSection;
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }
}
