import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/delivery_address.dart';

/// The delivery address card of the checkout: the chosen address, or a
/// prompt to choose one. Tap to open the address picker.
class CheckoutAddressPicker extends StatelessWidget {
  final DeliveryAddress? selectedAddress;
  final VoidCallback onTap;

  /// Highlights the card in red (order tapped without an address).
  final bool hasError;

  const CheckoutAddressPicker({
    super.key,
    required this.selectedAddress,
    required this.onTap,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: hasError && selectedAddress == null
              ? AppColors.error.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (hasError && selectedAddress == null
                      ? AppColors.error
                      : Colors.black)
                  .withValues(alpha: hasError && selectedAddress == null ? 0.18 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: selectedAddress != null
                ? AppColors.primary
                : (hasError ? AppColors.error : Colors.transparent),
            width: 1.5,
          ),
        ),
        child: selectedAddress == null
            ? Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: hasError
                          ? AppColors.error.withValues(alpha: 0.12)
                          : AppColors.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_location_alt_outlined,
                      color: hasError ? AppColors.error : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.selectDeliveryAddress,
                      style: TextStyle(
                        color: hasError ? AppColors.error : AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textLight,
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedAddress!.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedAddress!.fullAddress,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_outlined, color: AppColors.primary),
                ],
              ),
      ),
    );
  }
}
