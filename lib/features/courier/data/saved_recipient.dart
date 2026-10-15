import '../../checkout/data/models/delivery_address.dart';

/// A recipient the customer saved from a previous parcel
/// (table `saved_recipients`).
class SavedRecipient {
  final String id;
  final String? name;
  final String phone;
  final DeliveryAddress? deliveryAddress;

  SavedRecipient({
    required this.id,
    this.name,
    required this.phone,
    this.deliveryAddress,
  });

  String get displayLabel =>
      (name != null && name!.isNotEmpty) ? name! : phone;

  factory SavedRecipient.fromJson(Map<String, dynamic> json) {
    return SavedRecipient(
      id: json['id'] as String,
      name: json['name'] as String?,
      phone: json['phone'] as String,
      deliveryAddress: json['delivery_address'] != null
          ? DeliveryAddress.fromJson(
              json['delivery_address'] as Map<String, dynamic>)
          : null,
    );
  }
}
