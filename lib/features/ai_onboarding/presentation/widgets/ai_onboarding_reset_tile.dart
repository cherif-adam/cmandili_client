import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../ai_onboarding_controller.dart';

/// Developer tools of the AI onboarding: on in debug builds, and in any
/// build made with `--dart-define=AMANA_DEV_TOOLS=true` (the phone runs
/// release builds, where a debug-only switch would never appear).
abstract final class AiDevTools {
  static const bool enabled =
      kDebugMode || bool.fromEnvironment('AMANA_DEV_TOOLS');
}

/// "Rejouer la découverte de l'IA (dev)": clears every AI onboarding flag
/// and counter, so the next visit to the home tab replays the first-time
/// experience (coach mark, then shimmer and pulse; badge back; teaser
/// allowed again from the next session). Invisible outside [AiDevTools].
class AiOnboardingResetTile extends ConsumerWidget {
  const AiOnboardingResetTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AiDevTools.enabled) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.aiViolet.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: const Icon(Icons.restart_alt_rounded, color: AppColors.aiViolet),
          title: Text(
            l10n.aiDevResetTitle,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          onTap: () async {
            await ref.read(aiOnboardingControllerProvider.notifier).resetAll();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.aiDevResetDone)),
            );
          },
        ),
      ),
    );
  }
}
