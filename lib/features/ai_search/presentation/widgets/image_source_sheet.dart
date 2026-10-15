import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';

/// The floating white bottom sheet "Rechercher avec une photo": two big
/// tiles, Caméra and Galerie.
class ImageSourceSheet extends StatelessWidget {
  final void Function(ImageSource) onSelect;

  const ImageSourceSheet({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.aiSearchModalTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.aiSearchModalHint(l10n.city),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _SourceTile(
                  icon: Icons.camera_alt_rounded,
                  label: l10n.aiSearchCameraLabel,
                  onTap: () => onSelect(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SourceTile(
                  icon: Icons.photo_library_rounded,
                  label: l10n.aiSearchGalleryLabel,
                  onTap: () => onSelect(ImageSource.gallery),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One big purple-tinted tile: icon over label.
class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF6C3DE1).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFF6C3DE1).withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF6C3DE1), size: 32),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6C3DE1))),
          ],
        ),
      ),
    );
  }
}
