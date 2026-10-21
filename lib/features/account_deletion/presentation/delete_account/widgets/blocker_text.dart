import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../data/models/deletion_blocker.dart';

/// La phrase a montrer pour un blocage : ce qui bloque, et quoi faire.
String blockerText(AppLocalizations l, DeletionBlocker b) {
  final count = b.count ?? 1;
  switch (b.code) {
    case 'admin_account':
      return l.deleteAccountBlockerAdmin;
    case 'active_orders':
      return l.deleteAccountBlockerActiveOrders(count);
    case 'open_disputes':
      return l.deleteAccountBlockerOpenDisputes;
    case 'driver_active_orders':
      return l.deleteAccountBlockerDriverOrders(count);
    case 'driver_open_disputes':
      return l.deleteAccountBlockerDriverDisputes;
    case 'driver_payouts_pending':
      return l.deleteAccountBlockerDriverPayouts;
    case 'shop_active_orders':
      return l.deleteAccountBlockerShopOrders(count);
    case 'wallet_balance':
      return l.deleteAccountBlockerWallet((b.amount ?? 0).toStringAsFixed(3));
    case 'settlements_pending':
      return l.deleteAccountBlockerSettlements;
    default:
      return l.deleteAccountBlockerUnknown;
  }
}
