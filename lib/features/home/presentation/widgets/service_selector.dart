import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/service_category.dart';
import '../../../../core/providers/service_provider.dart';

/// The category grid at the top of the home screen.
///
/// Previously a fixed `Row` of four `Expanded` tiles, which worked only
/// because there were exactly four services: at nine it would squeeze each
/// tile to about a finger-width and clip the labels. This lays them out in a
/// wrapping four-per-row grid instead, so categories can keep being added
/// without the layout degrading.
///
/// Each tile is a rounded icon chip over its label — the pattern Glovo,
/// Yassir and Jumia all converged on, because it keeps a large tap target
/// while letting the colour do the work of distinguishing categories.
class ServiceSelector extends ConsumerWidget {
  final double screenWidth;
  final double screenHeight;

  const ServiceSelector({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
  });

  static Color colorFromHex(String hexColor) {
    final cleaned = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedService = ref.watch(selectedServiceProvider);
    const categories = ServiceCategory.categories;

    // Four per row on a normal phone, five once there is room for them. The
    // tile sizes itself from the available width rather than from a fraction
    // of the screen, so it stays correct inside padding and on tablets.
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final perRow = constraints.maxWidth > 420 ? 5 : 4;
        final tileWidth =
            (constraints.maxWidth - spacing * (perRow - 1)) / perRow;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final category in categories)
              SizedBox(
                width: tileWidth,
                child: _CategoryTile(
                  category: category,
                  isSelected: selectedService == category.type,
                  onTap: () => ref
                      .read(selectedServiceProvider.notifier)
                      .selectService(category.type),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final ServiceCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = ServiceSelector.colorFromHex(category.colorHex);
    final locale = Localizations.localeOf(context).languageCode;

    return Semantics(
      button: true,
      selected: isSelected,
      label: _localizedName(locale),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              height: 58,
              decoration: BoxDecoration(
                // Selected tiles fill with the category colour; the rest sit
                // on a soft tint of it, so the whole grid still reads as
                // colour-coded without nine saturated blocks competing.
                gradient: isSelected
                    ? LinearGradient(
                        colors: [color, Color.lerp(color, Colors.black, 0.18)!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                category.icon,
                style: const TextStyle(fontSize: 26),
              ),
            ),
            const SizedBox(height: 6),
            // Une seule ligne, quitte a reduire legerement la taille. A 11.5 px
            // dans une tuile de quart d'ecran, "Supermarche" et "Electronique"
            // debordaient et repassaient a la ligne sur une seule lettre
            // ("Supermarch" / "e"). scaleDown ne retrecit que les libelles qui
            // en ont besoin : les courts gardent leur taille d'origine.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _localizedName(locale),
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? color : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _localizedName(String locale) {
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
