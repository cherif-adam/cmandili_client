import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import 'animated_icon_button.dart';

/// The white search box: 🔍 + text field + camera button + purple send
/// button (grey while a search is running).
class AiSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSubmit;
  final VoidCallback onCameraTap;

  const AiSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSubmit,
    required this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C3DE1).withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(Icons.search_rounded,
                color: Color(0xFF6C3DE1), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onSubmitted: (_) => onSubmit(),
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: l10n.aiSearchPlaceholder,
                  hintStyle: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
            // Camera / image button
            AnimatedIconButton(
              icon: Icons.camera_alt_rounded,
              color: const Color(0xFF6C3DE1),
              onTap: onCameraTap,
              tooltip: l10n.aiSearchCameraTooltip,
            ),
            const SizedBox(width: 8),
            // Send button
            GestureDetector(
              onTap: isLoading ? null : onSubmit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isLoading
                      ? const LinearGradient(
                          colors: [Colors.grey, Colors.grey])
                      : const LinearGradient(
                          colors: [Color(0xFF6C3DE1), Color(0xFF8F57FB)],
                        ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
