import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import 'deletion_info_section.dart';

/// Ce qui sera supprimé et ce qui sera gardé, dit simplement.
class DeletionInfoCard extends StatelessWidget {
  const DeletionInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;

    return Container(
      padding: EdgeInsets.all(width * 0.045),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(width * 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.deleteAccountIntro,
            style: TextStyle(fontSize: width * 0.038, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: width * 0.05),
          DeletionInfoSection(
            title: l.deleteAccountDeletedTitle,
            color: AppColors.error,
            icon: Icons.remove_circle_outline_rounded,
            lines: [
              l.deleteAccountDeletedContact,
              l.deleteAccountDeletedAddresses,
              l.deleteAccountDeletedOrderDetails,
              l.deleteAccountDeletedPayment,
              l.deleteAccountDeletedChat,
              l.deleteAccountDeletedDevices,
            ],
          ),
          SizedBox(height: width * 0.04),
          DeletionInfoSection(
            title: l.deleteAccountKeptTitle,
            color: AppColors.textSecondary,
            icon: Icons.inventory_2_outlined,
            lines: [
              l.deleteAccountKeptOrders,
              l.deleteAccountKeptColis,
            ],
          ),
          SizedBox(height: width * 0.02),
          Text(
            l.deleteAccountKeptWhy,
            style: TextStyle(
              fontSize: width * 0.033,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
