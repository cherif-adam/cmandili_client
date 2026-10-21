import 'package:flutter/material.dart';

import '../../../../../core/models/service_category.dart';
import '../../../../home/presentation/widgets/service_selector.dart'
    show ServiceSelector;
import 'chat_category_chip.dart';

/// The white strip of service chips under the header.
///
/// Reads the same ServiceCategory.categories list the home screen's
/// ServiceSelector uses, so the chat offers exactly the services the app
/// offers — the 7 shop catalogues plus Colis and Facture — and a category
/// added there shows up here with no extra work.
class ChatCategoryBar extends StatelessWidget {
  final ValueChanged<ServiceType> onCategoryTap;

  const ChatCategoryBar({super.key, required this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    const categories = ServiceCategory.categories;
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0x11000000))),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = categories[i];
          return ChatCategoryChip(
            emoji: c.icon,
            label: c.nameFr,
            color: ServiceSelector.colorFromHex(c.colorHex),
            onTap: () => onCategoryTap(c.type),
          );
        },
      ),
    );
  }
}
