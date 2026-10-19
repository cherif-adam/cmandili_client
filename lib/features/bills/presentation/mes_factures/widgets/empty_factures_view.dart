import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

/// "Aucune facture payée" with an orange receipt icon.
class EmptyFacturesView extends StatelessWidget {
  final double sw;
  final double sh;

  const EmptyFacturesView({super.key, required this.sw, required this.sh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(sw * 0.06),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_outlined, size: sw * 0.15, color: const Color(0xFFFF9500)),
          ),
          SizedBox(height: sh * 0.03),
          Text(AppLocalizations.of(context)!.billsEmptyTitle, style: TextStyle(fontSize: sw * 0.055, fontWeight: FontWeight.bold)),
          SizedBox(height: sh * 0.01),
          Text(
            AppLocalizations.of(context)!.billsEmptySubtitle,
            style: TextStyle(fontSize: sw * 0.038, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
