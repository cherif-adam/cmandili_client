enum ServiceType {
  foodDelivery,
  supermarket,
  billPayments,
  courier,
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

  static const List<ServiceCategory> categories = [
    ServiceCategory(
      id: 'food',
      type: ServiceType.foodDelivery,
      nameEn: 'Food Delivery',
      nameAr: 'توصيل الطعام',
      nameFr: 'Livraison',
      icon: '🍕',
      colorHex: '#FF6B35',
    ),
    ServiceCategory(
      id: 'supermarket',
      type: ServiceType.supermarket,
      nameEn: 'Supermarket',
      nameAr: 'سوبر ماركت',
      nameFr: 'Supermarché',
      icon: '🛒',
      colorHex: '#4CAF50',
    ),
    ServiceCategory(
      id: 'courier',
      type: ServiceType.courier,
      nameEn: 'Send Parcel',
      nameAr: 'إرسال طرد',
      nameFr: 'Colis',
      icon: '📦',
      colorHex: '#6C3DE1',
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
