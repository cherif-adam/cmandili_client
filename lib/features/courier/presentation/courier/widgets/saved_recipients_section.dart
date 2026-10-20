import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../data/saved_recipient.dart';
import 'courier_colors.dart';
import 'saved_recipient_chip.dart';

/// "Destinataires enregistrés": a small title, then a horizontal row of
/// SavedRecipientChip (or a spinner while they load).
class SavedRecipientsSection extends StatelessWidget {
  final bool isLoading;
  final List<SavedRecipient> recipients;
  final ValueChanged<SavedRecipient> onSelect;
  final ValueChanged<SavedRecipient> onDelete;
  final double screenWidth;
  final double screenHeight;

  const SavedRecipientsSection({
    super.key,
    required this.isLoading,
    required this.recipients,
    required this.onSelect,
    required this.onDelete,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final w = screenWidth;
    final h = screenHeight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bookmarks_outlined, color: kCourierPurple, size: 16),
            SizedBox(width: w * 0.015),
            Text(
              AppLocalizations.of(context)!.courierSavedRecipients,
              style: TextStyle(
                fontSize: w * 0.035,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        SizedBox(height: h * 0.01),
        if (isLoading)
          const SizedBox(
            height: 36,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: kCourierPurple),
              ),
            ),
          )
        else
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recipients.length,
              separatorBuilder: (_, __) => SizedBox(width: w * 0.02),
              itemBuilder: (context, i) {
                final r = recipients[i];
                return SavedRecipientChip(
                  recipient: r,
                  onTap: () => onSelect(r),
                  onDelete: () => onDelete(r),
                  screenWidth: w,
                  screenHeight: h,
                );
              },
            ),
          ),
        SizedBox(height: h * 0.02),
      ],
    );
  }
}
