import 'package:flutter/material.dart';

import '../../../../checkout/data/models/delivery_address.dart';
import 'facture_colors.dart';

/// A tappable address box: grey placeholder + chevron when empty, tinted
/// with the address text + a check mark once an address is chosen.
class FactureAddressTile extends StatelessWidget {
  final DeliveryAddress? address;
  final String placeholder;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const FactureAddressTile({
    super.key,
    required this.address,
    required this.placeholder,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hasAddress = address != null;
    final label = hasAddress
        ? (address!.fullAddress.isNotEmpty ? address!.fullAddress : address!.label)
        : placeholder;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: hasAddress ? color.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasAddress ? color : Colors.grey.shade300,
            width: hasAddress ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: hasAddress ? color : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: hasAddress ? kFactureTextDark : Colors.grey,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              hasAddress ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              color: hasAddress ? color : Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
