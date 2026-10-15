import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/package_size.dart';
import 'courier_colors.dart';

/// Three cards side by side — Petit 📄 / Moyen 📦 / Grand 🧳 — the selected
/// one is filled purple.
class PackageSizeSelector extends StatelessWidget {
  final PackageSize selected;
  final ValueChanged<PackageSize> onSelected;
  final double screenWidth;
  final double screenHeight;

  const PackageSizeSelector({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final w = screenWidth;
    final h = screenHeight;
    final sizes = [
      (PackageSize.petit, 'Petit', '📄', 'Documents, petits objets'),
      (PackageSize.moyen, 'Moyen', '📦', 'Vêtements, accessoires'),
      (PackageSize.grand, 'Grand', '🧳', 'Bagages, gros colis'),
    ];

    return Row(
      children: sizes.map((entry) {
        final (size, label, icon, desc) = entry;
        final isSelected = selected == size;

        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(size),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: w * 0.01),
              padding: EdgeInsets.symmetric(
                  vertical: h * 0.015, horizontal: w * 0.01),
              decoration: BoxDecoration(
                color: isSelected ? kCourierPurple : Colors.white,
                borderRadius: BorderRadius.circular(w * 0.03),
                border: Border.all(
                  color:
                      isSelected ? kCourierPurple : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? kCourierPurple.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: isSelected ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(icon, style: TextStyle(fontSize: w * 0.07)),
                  SizedBox(height: h * 0.005),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: w * 0.033,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: h * 0.003),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: w * 0.025,
                      color: isSelected
                          ? Colors.white70
                          : AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
