class Supermarket {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final double rating;
  final int reviewCount;
  final int deliveryTime; // in minutes
  final double deliveryFee;
  final double minimumOrder;
  final bool isOpen;
  final double latitude;
  final double longitude;

  /// Raw Postgres TIME string ('08:30:00') — null when the venue has no
  /// configured hours. Used only for the "Ouvre à HH:MM" hint on cards.
  final String? openingTime;

  const Supermarket({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.rating,
    required this.reviewCount,
    required this.deliveryTime,
    required this.deliveryFee,
    required this.minimumOrder,
    required this.isOpen,
    required this.latitude,
    required this.longitude,
    this.openingTime,
  });
}
