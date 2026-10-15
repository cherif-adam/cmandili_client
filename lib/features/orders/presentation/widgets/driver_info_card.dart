import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';

/// "Votre livreur": avatar, name, phone and a 📞 button that calls them.
class DriverInfoCard extends StatelessWidget {
  final String driverName;
  final String? driverPhone;

  const DriverInfoCard({super.key, required this.driverName, this.driverPhone});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.yourCourier,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      driverPhone ?? '',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _callPhone(context, driverPhone),
                icon: const Icon(Icons.phone, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Future<void> _callPhone(BuildContext context, String? phone) async {
    final number = phone?.trim();
    if (number == null || number.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.driverPhoneNotAvailable)),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.unableToStartCall)),
      );
    }
  }
}
