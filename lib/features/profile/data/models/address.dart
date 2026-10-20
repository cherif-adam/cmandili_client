/// A delivery address saved in the customer's address book
/// (table `user_addresses`).
class Address {
  final String id;
  final String name; // Home, Work, etc.
  final String fullAddress;
  final bool isDefault;
  final double latitude;
  final double longitude;

  Address({
    required this.id,
    required this.name,
    required this.fullAddress,
    this.isDefault = false,
    this.latitude = 0,
    this.longitude = 0,
  });

  Address copyWith({
    String? id,
    String? name,
    String? fullAddress,
    bool? isDefault,
    double? latitude,
    double? longitude,
  }) {
    return Address(
      id: id ?? this.id,
      name: name ?? this.name,
      fullAddress: fullAddress ?? this.fullAddress,
      isDefault: isDefault ?? this.isDefault,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
