/// A shop of any category — restaurant, supermarket, florist, pet shop, gift
/// shop, bakery or electronics store.
///
/// Replaces the per-vertical `Restaurant` / `Supermarket` models: those were
/// the same fields twice over, and a third copy per new category does not
/// scale. The [category] discriminator is what used to be encoded in the
/// table name.
class Vendor {
  final String id;

  /// Category id from the `vendor_categories` table: 'food', 'grocery',
  /// 'flowers', 'pets', 'gifts', 'bakery', 'electronics', … Not an enum,
  /// because adding a category must not require an app release.
  final String category;

  final String name;
  final String description;
  final String imageUrl;
  final double rating;
  final int reviewCount;
  final int deliveryTime; // minutes
  final double deliveryFee;
  final double minimumOrder;

  /// Free-form tags used to filter within a category ("pizza", "roses").
  final List<String> categories;

  final bool isOpen;
  final double latitude;
  final double longitude;

  /// Raw Postgres TIME string ('08:30:00') — null when the venue has no
  /// configured hours. Used only for the "Ouvre à HH:MM" hint on cards.
  final String? openingTime;

  final DateTime? createdAt;

  /// True for a week after the venue is added — drives the "Nouveau" badge.
  bool get isNew =>
      createdAt != null && DateTime.now().difference(createdAt!).inDays < 7;

  const Vendor({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.rating,
    required this.reviewCount,
    required this.deliveryTime,
    required this.deliveryFee,
    required this.minimumOrder,
    required this.categories,
    required this.isOpen,
    required this.latitude,
    required this.longitude,
    this.openingTime,
    this.createdAt,
  });

  /// Builds from a raw `vendors` row. Column names are snake_case straight
  /// from Postgres — there is no intermediate camelCase mapping step here,
  /// unlike the older repositories.
  factory Vendor.fromDb(Map<String, dynamic> row) {
    return Vendor(
      id: row['id']?.toString() ?? '',
      category: row['category']?.toString() ?? 'food',
      name: row['name']?.toString() ?? '',
      description: row['description']?.toString() ?? '',
      imageUrl: row['image_url']?.toString() ?? '',
      rating: (row['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (row['review_count'] as num?)?.toInt() ?? 0,
      deliveryTime: (row['delivery_time_min'] as num?)?.toInt() ?? 30,
      deliveryFee: (row['delivery_fee'] as num?)?.toDouble() ?? 0,
      minimumOrder: (row['min_order'] as num?)?.toDouble() ?? 0,
      categories: row['categories'] == null
          ? const []
          : List<String>.from(row['categories'] as List),
      isOpen: row['is_open'] as bool? ?? true,
      latitude: (row['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (row['longitude'] as num?)?.toDouble() ?? 0,
      openingTime: row['opening_time']?.toString(),
      createdAt: row['created_at'] == null
          ? null
          : DateTime.tryParse(row['created_at'].toString()),
    );
  }
}

/// A single purchasable item belonging to a [Vendor] — a dish, a bouquet, a
/// bag of dog food, a phone case.
class VendorItem {
  final String id;
  final String vendorId;
  final String name;
  final String description;
  final String imageUrl;
  final double price;

  /// Section heading within one vendor's catalogue ("Pizzas", "Roses").
  final String? category;

  /// Grocery-style unit ("kg", "L"); null for items sold by the piece.
  final String? unit;

  final bool isOrganic;
  final bool isAvailable;
  final double? discountPrice;
  final DateTime? discountEndTime;

  const VendorItem({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.price,
    this.category,
    this.unit,
    this.isOrganic = false,
    this.isAvailable = true,
    this.discountPrice,
    this.discountEndTime,
  });

  /// Price the customer actually pays right now: the discounted price while a
  /// time-boxed promotion is live, otherwise the base price. Centralised here
  /// so no screen can forget to check the expiry.
  double get effectivePrice {
    final discount = discountPrice;
    if (discount == null) return price;
    final end = discountEndTime;
    if (end != null && DateTime.now().isAfter(end)) return price;
    return discount;
  }

  bool get hasActiveDiscount => effectivePrice < price;

  factory VendorItem.fromDb(Map<String, dynamic> row) {
    return VendorItem(
      id: row['id']?.toString() ?? '',
      vendorId: row['vendor_id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      description: row['description']?.toString() ?? '',
      imageUrl: row['image_url']?.toString() ?? '',
      price: (row['price'] as num?)?.toDouble() ?? 0,
      category: row['category']?.toString(),
      unit: row['unit']?.toString(),
      isOrganic: row['is_organic'] as bool? ?? false,
      isAvailable: row['is_available'] as bool? ?? true,
      discountPrice: (row['discount_price'] as num?)?.toDouble(),
      discountEndTime: row['discount_end_time'] == null
          ? null
          : DateTime.tryParse(row['discount_end_time'].toString()),
    );
  }
}

/// A category shown in the home screen's grid, loaded from
/// `vendor_categories` so a new one appears without an app release.
class VendorCategory {
  final String id;
  final String nameEn;
  final String nameFr;
  final String nameAr;
  final String icon;
  final String colorHex;
  final int sortOrder;

  const VendorCategory({
    required this.id,
    required this.nameEn,
    required this.nameFr,
    required this.nameAr,
    required this.icon,
    required this.colorHex,
    required this.sortOrder,
  });

  factory VendorCategory.fromDb(Map<String, dynamic> row) {
    return VendorCategory(
      id: row['id']?.toString() ?? '',
      nameEn: row['name_en']?.toString() ?? '',
      nameFr: row['name_fr']?.toString() ?? '',
      nameAr: row['name_ar']?.toString() ?? '',
      icon: row['icon']?.toString() ?? '🏪',
      colorHex: row['color_hex']?.toString() ?? '#059669',
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 100,
    );
  }

  /// Name in the app's current locale, falling back to French (the primary
  /// language of the product) then English.
  String localizedName(String languageCode) {
    switch (languageCode) {
      case 'ar':
        return nameAr.isNotEmpty ? nameAr : nameFr;
      case 'en':
        return nameEn.isNotEmpty ? nameEn : nameFr;
      default:
        return nameFr.isNotEmpty ? nameFr : nameEn;
    }
  }

  /// The catalogue every app falls back to when the table cannot be read
  /// (offline first launch, RLS misconfiguration). Keeps the home screen
  /// populated rather than blank, and matches the migration's seed rows.
  static const List<VendorCategory> fallback = [
    VendorCategory(
        id: 'food', nameEn: 'Food', nameFr: 'Restaurants', nameAr: 'مطاعم',
        icon: '🍕', colorHex: '#FF6B35', sortOrder: 10),
    VendorCategory(
        id: 'grocery', nameEn: 'Market', nameFr: 'Supermarché',
        nameAr: 'سوبر ماركت', icon: '🛒', colorHex: '#1D9E75', sortOrder: 20),
    VendorCategory(
        id: 'bakery', nameEn: 'Bakery', nameFr: 'Pâtisserie', nameAr: 'مخبزة',
        icon: '🥐', colorHex: '#D97706', sortOrder: 30),
    VendorCategory(
        id: 'flowers', nameEn: 'Flowers', nameFr: 'Fleurs', nameAr: 'زهور',
        icon: '💐', colorHex: '#EC4899', sortOrder: 40),
    VendorCategory(
        id: 'pets', nameEn: 'Pet Supplies', nameFr: 'Animalerie',
        nameAr: 'مستلزمات الحيوانات', icon: '🐾', colorHex: '#8B5CF6',
        sortOrder: 50),
    VendorCategory(
        id: 'gifts', nameEn: 'Gifts', nameFr: 'Cadeaux', nameAr: 'هدايا',
        icon: '🎁', colorHex: '#F59E0B', sortOrder: 60),
    VendorCategory(
        id: 'electronics', nameEn: 'Electronics', nameFr: 'Électronique',
        nameAr: 'إلكترونيات', icon: '📱', colorHex: '#3B82F6', sortOrder: 70),
  ];
}
