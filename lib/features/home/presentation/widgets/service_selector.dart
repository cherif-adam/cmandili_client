import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/service_category.dart';
import '../../../../core/providers/service_provider.dart';

class ServiceSelector extends ConsumerWidget {
  final double screenWidth;
  final double screenHeight;

  const ServiceSelector({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
  });

  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedService = ref.watch(selectedServiceProvider);

    return Container(
      height: screenHeight * 0.12,
      margin: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05,
        vertical: screenHeight * 0.015,
      ),
      child: Row(
        children: ServiceCategory.categories.map((category) {
          final isSelected = selectedService == category.type;
          final color = _getColorFromHex(category.colorHex);

          return Expanded(
            child: GestureDetector(
              onTap: () {
                ref.read(selectedServiceProvider.notifier).selectService(category.type);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [color, color.withValues(alpha: 0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(screenWidth * 0.04),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : Colors.grey.shade300,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? color.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.05),
                      blurRadius: isSelected ? 12 : 8,
                      offset: Offset(0, isSelected ? 6 : 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      category.icon,
                      style: TextStyle(
                        fontSize: screenWidth * 0.08,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.005),
                    Text(
                      _getLocalizedName(context, category),
                      style: TextStyle(
                        fontSize: screenWidth * 0.028,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
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
      ),
    );
  }

  String _getLocalizedName(BuildContext context, ServiceCategory category) {
    final locale = Localizations.localeOf(context).languageCode;
    switch (locale) {
      case 'ar':
        return category.nameAr;
      case 'fr':
        return category.nameFr;
      default:
        return category.nameEn;
    }
  }
}
