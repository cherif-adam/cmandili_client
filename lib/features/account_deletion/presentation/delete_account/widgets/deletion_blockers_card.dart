import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../profile/presentation/help_support/help_support_screen.dart';
import '../../../data/models/deletion_blocker.dart';
import 'blocker_text.dart';

/// Ce qui empêche la suppression, chaque ligne disant quoi faire, et un
/// accès direct au support.
class DeletionBlockersCard extends StatelessWidget {
  final List<DeletionBlocker> blockers;

  const DeletionBlockersCard({super.key, required this.blockers});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;

    return Container(
      padding: EdgeInsets.all(width * 0.045),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(width * 0.04),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.block_rounded, color: AppColors.warning, size: width * 0.06),
              SizedBox(width: width * 0.025),
              Expanded(
                child: Text(
                  l.deleteAccountBlockedTitle,
                  style: TextStyle(fontSize: width * 0.04, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: width * 0.035),
          for (final b in blockers)
            Padding(
              padding: EdgeInsets.only(bottom: width * 0.025),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: TextStyle(fontSize: width * 0.038)),
                  Expanded(
                    child: Text(blockerText(l, b), style: TextStyle(fontSize: width * 0.036)),
                  ),
                ],
              ),
            ),
          SizedBox(height: width * 0.02),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.support_agent_rounded),
              label: Text(l.deleteAccountContactTeam),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
