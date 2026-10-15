import 'package:flutter/material.dart';

/// The bills a driver can go and pay for the customer.
enum BillType { topnet, steg, sonede, autre }

extension BillTypeX on BillType {
  String get label => switch (this) {
        BillType.topnet => 'Topnet',
        BillType.steg => 'STEG',
        BillType.sonede => 'SONEDE',
        BillType.autre => 'Autre',
      };

  IconData get icon => switch (this) {
        BillType.topnet => Icons.wifi_rounded,
        BillType.steg => Icons.bolt_rounded,
        BillType.sonede => Icons.water_drop_rounded,
        BillType.autre => Icons.receipt_long_rounded,
      };

  Color get color => switch (this) {
        BillType.topnet => const Color(0xFF1565C0),
        BillType.steg => const Color(0xFFF57F17),
        BillType.sonede => const Color(0xFF00695C),
        BillType.autre => const Color(0xFF616161),
      };

  String get dbValue => name; // 'topnet' | 'steg' | 'sonede' | 'autre'
}
