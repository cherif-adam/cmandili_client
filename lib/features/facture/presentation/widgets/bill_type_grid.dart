import 'package:flutter/material.dart';

import '../../data/bill_type.dart';
import 'bill_type_card.dart';

/// The 2-column grid of bill types (Topnet, STEG, SONEDE, Autre).
class BillTypeGrid extends StatelessWidget {
  final BillType? selected;
  final ValueChanged<BillType> onSelected;

  const BillTypeGrid({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.8,
      children: BillType.values
          .map((type) => BillTypeCard(
                type: type,
                selected: selected == type,
                onTap: () => onSelected(type),
              ))
          .toList(),
    );
  }
}
