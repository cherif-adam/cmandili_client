import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/providers/location_provider.dart';
import '../../../profile/presentation/saved_addresses_screen.dart';

/// "Livrer à  📍 <current address> ⌄" in the home header.
/// Tapping it opens the saved addresses.
class DeliverToButton extends ConsumerWidget {
  final double screenWidth;
  final double screenHeight;

  const DeliverToButton({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(locationProvider);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SavedAddressesScreen(),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.deliverTo,
            style: TextStyle(
              color: Colors.white70,
              fontSize: screenWidth * 0.035,
            ),
          ),
          SizedBox(height: screenHeight * 0.005),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on,
                color: Colors.white,
                size: screenWidth * 0.05,
              ),
              SizedBox(width: screenWidth * 0.01),
              // Flexible: long address won't overflow
              Flexible(
                child: Text(
                  loc == 'Current Location'
                      ? AppLocalizations.of(context)!.currentLocation
                      : loc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.04,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: screenWidth * 0.01),
              Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white.withValues(alpha: 0.8),
                size: screenWidth * 0.05,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
