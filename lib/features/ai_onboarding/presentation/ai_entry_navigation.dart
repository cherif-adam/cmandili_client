import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_chat/presentation/ai_chat/ai_chat_screen.dart';
import '../../ai_search/presentation/ai_search/ai_search_screen.dart';
import 'ai_onboarding_controller.dart';

/// Opens the two AI features from their home entry points, with the light
/// haptic both share. Opening the assistant also counts for the teaser rule
/// (it stops after 3 opens).
abstract final class AiEntryNavigation {
  /// Recherche IA; with [query], the text is already searched on arrival.
  static Future<void> openSearch(BuildContext context, {String? query}) {
    HapticFeedback.lightImpact();
    final text = query?.trim();
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AiSearchScreen(initialQuery: (text == null || text.isEmpty) ? null : text),
      ),
    );
  }

  static Future<void> openChat(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    unawaited(ref.read(aiOnboardingControllerProvider.notifier).recordChatOpened());
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AiChatScreen()),
    );
  }
}
