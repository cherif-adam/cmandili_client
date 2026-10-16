import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

/// Name and phone fields the driver uses to reach the customer.
class CheckoutContactCard extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;

  const CheckoutContactCard({
    super.key,
    required this.nameController,
    required this.phoneController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.fullNameHint,
              prefixIcon: const Icon(Icons.person_outline,
                  color: AppColors.textLight),
              border: InputBorder.none,
            ),
          ),
          const Divider(height: 1),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]')),
            ],
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.phoneHint,
              prefixIcon:
                  const Icon(Icons.phone_outlined, color: AppColors.textLight),
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }
}
