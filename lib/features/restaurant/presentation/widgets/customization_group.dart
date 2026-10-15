/// One row in the customization sheet's unified group list — either the
/// single "Type au choix" variants slot or a real option group (key == its
/// DB id). Unifying the two keeps rendering/validation generic; the data
/// layer keeps variants and option groups as separate lists.
class CustomizationGroup {
  final String key;
  final String title;
  final int minSelections;
  final int maxSelections;
  final bool isRequired;
  final List<CustomizationOption> options;

  const CustomizationGroup({
    required this.key,
    required this.title,
    required this.minSelections,
    required this.maxSelections,
    required this.isRequired,
    required this.options,
  });
}

/// One choice inside a [CustomizationGroup] (a variant or an option).
class CustomizationOption {
  final String id;
  final String name;
  final double price;

  const CustomizationOption({
    required this.id,
    required this.name,
    required this.price,
  });
}
