/// A customer's pick within one option group, snapshotted at add-to-cart
/// time (name/price are copied, not re-joined from `optionId` later, so a
/// historical order still displays correctly even if a partner later renames
/// or removes the option). `price` is raw — never marked up here.
class SelectedOption {
  final String optionId;
  final String name;
  final double price;

  const SelectedOption({
    required this.optionId,
    required this.name,
    required this.price,
  });

  Map<String, dynamic> toJson() => {
        'optionId': optionId,
        'name': name,
        'price': price,
      };

  factory SelectedOption.fromJson(Map<String, dynamic> json) {
    return SelectedOption(
      optionId: json['optionId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// One [FoodItemOptionGroup]'s selections on a single cart line, e.g.
/// "Sauce au choix" → [Harissa, Gruyère]. Lives alongside [OrderCustomization]
/// as the other order-domain customization model — this one round-trips
/// through cart persistence (it affects price), unlike `customization`.
class SelectedOptionGroup {
  final String groupId;
  final String groupName;
  final List<SelectedOption> selections;

  const SelectedOptionGroup({
    required this.groupId,
    required this.groupName,
    required this.selections,
  });

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'groupName': groupName,
        'selections': selections.map((s) => s.toJson()).toList(),
      };

  factory SelectedOptionGroup.fromJson(Map<String, dynamic> json) {
    return SelectedOptionGroup(
      groupId: json['groupId'] as String? ?? '',
      groupName: json['groupName'] as String? ?? '',
      selections: ((json['selections'] as List?) ?? const [])
          .map((s) => SelectedOption.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
