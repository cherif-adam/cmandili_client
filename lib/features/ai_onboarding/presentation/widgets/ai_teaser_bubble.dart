import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';

/// A small speech bubble above the assistant button, its tail pointing down
/// at it. Tapping the text opens the chat ([onTap]); the ✕ closes it
/// ([onClose]); after [lifetime] of being on screen it asks to go away
/// ([onTimeout]). The lifetime runs on a ticker, so time spent under another
/// screen or in the background does not count.
class AiTeaserBubble extends StatefulWidget {
  const AiTeaserBubble({
    super.key,
    required this.text,
    required this.onTap,
    required this.onClose,
    required this.onTimeout,
    this.reduceMotion = false,
    this.lifetime = const Duration(seconds: 6),
  });

  final String text;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback onTimeout;
  final bool reduceMotion;
  final Duration lifetime;

  @override
  State<AiTeaserBubble> createState() => _AiTeaserBubbleState();
}

class _AiTeaserBubbleState extends State<AiTeaserBubble>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: widget.reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
  );
  late final AnimationController _life =
      AnimationController(vsync: this, duration: widget.lifetime)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onTimeout();
        });
  late final CurvedAnimation _pop =
      CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack);
  late final Animation<double> _scale = Tween(begin: 0.85, end: 1.0).animate(_pop);

  @override
  void initState() {
    super.initState();
    _entrance.forward();
    _life.forward();
  }

  @override
  void dispose() {
    _pop.dispose();
    _entrance.dispose();
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FadeTransition(
      opacity: _entrance,
      child: ScaleTransition(
        scale: _scale,
        alignment: AlignmentDirectional.bottomEnd.resolve(Directionality.of(context)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Material(
                color: Theme.of(context).cardColor,
                elevation: 4,
                shadowColor: AppColors.aiViolet.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: widget.onTap,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 6, 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            widget.text,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Semantics(
                          button: true,
                          label: l10n.aiTeaserClose,
                          excludeSemantics: true,
                          child: InkResponse(
                            onTap: widget.onClose,
                            radius: 18,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 22),
                child: CustomPaint(
                  size: const Size(14, 8),
                  painter: _TailPainter(color: Theme.of(context).cardColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The little downward triangle under the bubble.
class _TailPainter extends CustomPainter {
  const _TailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawShadow(path, AppColors.aiViolet.withValues(alpha: 0.35), 2, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter oldDelegate) => oldDelegate.color != color;
}
