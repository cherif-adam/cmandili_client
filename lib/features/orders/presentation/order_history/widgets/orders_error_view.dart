import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';

/// "Failed to load orders", the error, and a Réessayer button.
class OrdersErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final double sw;
  final double sh;

  const OrdersErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    required this.sw,
    required this.sh,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(sw * 0.1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: sw * 0.15, color: AppColors.error),
            SizedBox(height: sh * 0.02),
            Text(
              AppLocalizations.of(context)!.ordersLoadError,
              style: TextStyle(
                fontSize: sw * 0.045,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: sh * 0.01),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: sw * 0.035,
              ),
            ),
            SizedBox(height: sh * 0.03),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.retry),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
