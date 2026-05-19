enum BillCategory {
  internet,
  electricity,
  water,
}

class BillProvider {
  final String id;
  final String name;
  final BillCategory category;
  final String icon;
  final String colorHex;
  final String description;

  const BillProvider({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.colorHex,
    required this.description,
  });

  static const List<BillProvider> providers = [
    // Internet Providers
    BillProvider(
      id: 'ooredoo',
      name: 'Ooredoo',
      category: BillCategory.internet,
      icon: '📱',
      colorHex: '#E30613',
      description: 'Pay your Ooredoo internet bill',
    ),
    BillProvider(
      id: 'telecom',
      name: 'Telecom Tunisia',
      category: BillCategory.internet,
      icon: '📞',
      colorHex: '#0066CC',
      description: 'Pay your Telecom Tunisia internet bill',
    ),
    BillProvider(
      id: 'orange',
      name: 'Orange',
      category: BillCategory.internet,
      icon: '🍊',
      colorHex: '#FF6600',
      description: 'Pay your Orange internet bill',
    ),
    
    // Electricity
    BillProvider(
      id: 'steg',
      name: 'STEG',
      category: BillCategory.electricity,
      icon: '⚡',
      colorHex: '#FFD700',
      description: 'Pay your STEG electricity bill',
    ),

    // Water
    BillProvider(
      id: 'sonede',
      name: 'SONEDE',
      category: BillCategory.water,
      icon: '💧',
      colorHex: '#2196F3',
      description: 'Pay your SONEDE water bill',
    ),
  ];
}
