import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'living_ai_icon.dart';

/// The Amana Assistant button in the AI gradient: extended with [label]
/// at the top of the home list, a round icon once the list scrolls down
/// (Material 3 extended FAB pattern). The label slides in and out with the
/// width; with [reduceMotion] it switches at once and the icon stays still.
class AiAssistantButton extends StatelessWidget {
  const AiAssistantButton({
    super.key,
    required this.extended,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.reduceMotion = false,
  });

  static const double height = 56;

  final bool extended;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          elevation: 6,
          shadowColor: AppColors.aiViolet.withValues(alpha: 0.5),
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: const BoxDecoration(gradient: AppColors.aiGradient),
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                height: height,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LivingAiIcon(size: 24, animate: !reduceMotion),
                      AnimatedSize(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        alignment: AlignmentDirectional.centerStart,
                        child: extended
                            ? Padding(
                                padding: const EdgeInsetsDirectional.only(start: 10, end: 4),
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              )
                            : const SizedBox(height: height),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
