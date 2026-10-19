import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';

/// The reasons offered when cancelling. The value SENT to the server stays a
/// stable key; only the label follows the customer's language, otherwise a
/// cancellation in Arabic would arrive unreadable in the dashboard.
const cancelReasonKeys = [
  'wrong_order',
  'too_long',
  'changed_mind',
  'other',
];

String cancelReasonLabel(AppLocalizations l, String key) {
  switch (key) {
    case 'wrong_order':
      return l.cancelReasonWrongOrder;
    case 'too_long':
      return l.cancelReasonTooLong;
    case 'changed_mind':
      return l.cancelReasonChangedMind;
    default:
      return l.cancelReasonOther;
  }
}

/// "Annuler la commande ?" — a warning when a driver is already assigned,
/// one reason to pick, then Retour / Confirmer (enabled once a reason is
/// picked). Returns the reason key, or null if the customer backed out.
Future<String?> showCancelOrderDialog(BuildContext context, {required bool hasDriver}) {
  String? selectedReason;
  final l = AppLocalizations.of(context)!;

  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            l.cancelOrderTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: RadioGroup<String>(
              groupValue: selectedReason,
              onChanged: (val) => setDlgState(() => selectedReason = val),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasDriver) const _DriverAssignedWarning(),
                  Text(
                    l.cancelReasonLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  for (final r in cancelReasonKeys)
                    RadioListTile<String>(
                      title: Text(cancelReasonLabel(l, r), style: const TextStyle(fontSize: 14)),
                      value: r,
                      dense: true,
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.backAction),
            ),
            ElevatedButton(
              onPressed: selectedReason == null
                  ? null
                  : () => Navigator.pop(ctx, selectedReason),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(l.confirmAction),
            ),
          ],
        );
      },
    ),
  );
}

/// Orange note: a driver is already on it.
class _DriverAssignedWarning extends StatelessWidget {
  const _DriverAssignedWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.cancelDriverAssigned,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
