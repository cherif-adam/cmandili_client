import 'package:flutter/material.dart';

import '../../data/bill_type.dart';

/// One bill type in the grid: icon + name, tinted with the bill's color
/// when selected.
class BillTypeCard extends StatelessWidget {
  final BillType type;
  final bool selected;
  final VoidCallback onTap;

  const BillTypeCard({
    super.key,
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected ? type.color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? type.color : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: type.color.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(type.icon, size: 20, color: selected ? type.color : Colors.grey),
            const SizedBox(width: 8),
            Text(
              type.label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: selected ? type.color : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
