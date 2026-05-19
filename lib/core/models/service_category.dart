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
      nameFr: 'Livraison de nourriture',
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
  ];
}
