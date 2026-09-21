/// What the home screen is currently showing.
///
/// Two different kinds of thing live in this enum:
///
///  * **Shop categories** — food, supermarket, bakery, flowers, pets, gifts,
///    electronics. These all browse the generic `vendors` table and differ
///    only by their [ServiceTypeX.vendorCategory] discriminator.
///  * **Standalone services** — courier and bill payments. These have no shop
///    catalogue at all; they open their own flow.
///
/// New shop categories should be added here *and* to `vendor_categories` in
/// the database. The enum exists because the home screen switches layout on
/// it; the category list the user actually sees is loaded from the database,
/// so a category can be launched or hidden without shipping an app update.
enum ServiceType {
  foodDelivery,
  supermarket,
  bakery,
  flowers,
  pets,
  gifts,
  electronics,
  billPayments,
  courier,
}

extension ServiceTypeX on ServiceType {
  /// The `vendors.category` value this service browses, or null for the
  /// services that are not shop catalogues (courier, bill payments).
  String? get vendorCategory {
    switch (this) {
      case ServiceType.foodDelivery:
        return 'food';
      case ServiceType.supermarket:
        return 'grocery';
      case ServiceType.bakery:
        return 'bakery';
      case ServiceType.flowers:
        return 'flowers';
      case ServiceType.pets:
        return 'pets';
      case ServiceType.gifts:
        return 'gifts';
      case ServiceType.electronics:
        return 'electronics';
      case ServiceType.billPayments:
      case ServiceType.courier:
        return null;
    }
  }

  /// True when this service browses a shop catalogue, so the home screen
  /// should render a vendor list rather than a bespoke flow.
  bool get isVendorCategory => vendorCategory != null;

  /// Maps a `vendors.category` value back to its service. Returns null for an
  /// unknown category — one added to the database but not yet handled by this
  /// build — which callers treat as "not selectable in this app version".
  static ServiceType? fromVendorCategory(String category) {
    for (final t in ServiceType.values) {
      if (t.vendorCategory == category) return t;
    }
    return null;
  }
}

class ServiceCategory {
  final String id;
  final ServiceType type;
  final String nameEn;
  final String nameAr;
  final String nameFr;
  final String icon;
  final String colorHex;

  const ServiceCategory({
    required this.id,
    required this.type,
    required this.nameEn,
    required this.nameAr,
    required this.nameFr,
    required this.icon,
    required this.colorHex,
  });

  /// Built-in catalogue, used as the fallback when the `vendor_categories`
  /// table cannot be read and as the source for the two non-shop services,
  /// which have no database row.
  static const List<ServiceCategory> categories = [
    ServiceCategory(
      id: 'food',
      type: ServiceType.foodDelivery,
      nameEn: 'Food',
      nameAr: 'مطاعم',
      nameFr: 'Restaurants',
      icon: '🍕',
      colorHex: '#FF6B35',
    ),
    ServiceCategory(
      id: 'supermarket',
      type: ServiceType.supermarket,
      nameEn: 'Market',
      nameAr: 'سوبر ماركت',
      nameFr: 'Supermarché',
      icon: '🛒',
      colorHex: '#1D9E75',
    ),
    ServiceCategory(
      id: 'bakery',
      type: ServiceType.bakery,
      nameEn: 'Bakery',
      nameAr: 'مخبزة',
      nameFr: 'Pâtisserie',
      icon: '🥐',
      colorHex: '#D97706',
    ),
    ServiceCategory(
      id: 'flowers',
      type: ServiceType.flowers,
      nameEn: 'Flowers',
      nameAr: 'زهور',
      nameFr: 'Fleurs',
      icon: '💐',
      colorHex: '#EC4899',
    ),
    ServiceCategory(
      id: 'pets',
      type: ServiceType.pets,
      nameEn: 'Pet Supplies',
      nameAr: 'مستلزمات الحيوانات',
      nameFr: 'Animalerie',
      icon: '🐾',
      colorHex: '#8B5CF6',
    ),
    ServiceCategory(
      id: 'gifts',
      type: ServiceType.gifts,
      nameEn: 'Gifts',
      nameAr: 'هدايا',
      nameFr: 'Cadeaux',
      icon: '🎁',
      colorHex: '#F59E0B',
    ),
    ServiceCategory(
      id: 'electronics',
      type: ServiceType.electronics,
      nameEn: 'Electronics',
      nameAr: 'إلكترونيات',
      nameFr: 'Électronique',
      icon: '📱',
      colorHex: '#3B82F6',
    ),
    ServiceCategory(
      id: 'courier',
      type: ServiceType.courier,
      nameEn: 'Send Parcel',
      nameAr: 'إرسال طرد',
      nameFr: 'Colis',
      icon: '📦',
      colorHex: '#1D9E75',
    ),
    ServiceCategory(
      id: 'facture',
      type: ServiceType.billPayments,
      nameEn: 'Pay Bill',
      nameAr: 'دفع الفاتورة',
      nameFr: 'Facture',
      icon: '🧾',
      colorHex: '#FF9500',
    ),
  ];
}
