import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/colis_repository.dart';

/// The light-orange box "Interdit dans un colis": the list of forbidden
/// items, then the checkbox the sender must tick.
class ForbiddenItemsCard extends StatelessWidget {
  final bool confirmed;
  final ValueChanged<bool> onConfirmedChanged;
  final double screenWidth;
  final double screenHeight;

  const ForbiddenItemsCard({
    super.key,
    required this.confirmed,
    required this.onConfirmedChanged,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final w = screenWidth;
    final h = screenHeight;
    return Container(
      padding: EdgeInsets.all(w * 0.04),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD9A0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.courierForbiddenTitle,
            style: TextStyle(
                fontSize: w * 0.038, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: h * 0.012),
          ...kColisForbiddenItems.map((item) => Padding(
                padding: EdgeInsets.only(bottom: h * 0.006),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$1, style: TextStyle(fontSize: w * 0.038)),
                    SizedBox(width: w * 0.025),
                    Expanded(
                      child: Text(item.$2,
                          style: TextStyle(
                              fontSize: w * 0.034,
                              color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              )),
          SizedBox(height: h * 0.004),
          // La case vient APRÈS la liste : on ne confirme pas à l'aveugle.
          CheckboxListTile(
            value: confirmed,
            onChanged: (v) => onConfirmedChanged(v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: AppColors.primary,
            title: Text(
              AppLocalizations.of(context)!.courierForbiddenConfirm,
              style: TextStyle(fontSize: w * 0.034),
            ),
          ),
        ],
      ),
    );
  }
}
