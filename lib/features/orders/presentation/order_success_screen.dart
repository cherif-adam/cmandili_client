import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import 'order_tracking_screen.dart';

/// Shown right after a colis/supermarket/facture order is successfully
/// created — between the form (or checkout) and the tracking screen. Purely
/// a UI hand-off: the loyalty bottom sheet still lives on
/// [OrderTrackingScreen] and fires exactly as before once the user taps the
/// track button.
class OrderSuccessScreen extends StatefulWidget {
  final String orderId;
  final String imageAsset;
  final String title;
  final String trackButtonLabel;

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.imageAsset,
    required this.title,
    required this.trackButtonLabel,
  });

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _entranceFade;
  late final Animation<Offset> _contentSlide;

  late final AnimationController _checkController;
  late final Animation<double> _checkProgress;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _entranceFade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOut));

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _checkProgress = CurvedAnimation(parent: _checkController, curve: Curves.easeInOut);
    _checkController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.lightImpact();
      }
    });

    _entranceController.forward().whenComplete(() {
      if (mounted) _checkController.forward();
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  /// No human-readable order number exists in the schema — fall back to the
  /// last 8 characters of the order UUID as a pragmatic reference.
  String get _shortRef {
    final raw = widget.orderId.replaceAll('-', '');
    final tail = raw.length >= 8 ? raw.substring(raw.length - 8) : raw;
    return tail.toUpperCase();
  }

  void _goToTracking() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(orderId: widget.orderId, justPlaced: true),
      ),
    );
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(
            opacity: _entranceFade,
            child: Image.asset(
              widget.imageAsset,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.primaryGradient),
              ),
            ),
          ),

          // Bottom 45% dark-emerald overlay so content stays readable.
          const Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.45,
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.orderSuccessOverlayGradient),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: FadeTransition(
              opacity: _entranceFade,
              child: SlideTransition(
                position: _contentSlide,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      size.width * 0.08,
                      0,
                      size.width * 0.08,
                      size.height * 0.035,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AnimatedCheckmark(progress: _checkProgress, size: size.width * 0.2),
                        SizedBox(height: size.height * 0.025),
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: size.width * 0.065,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: size.height * 0.008),
                        Text(
                          l10n.orderSuccessTrackingRef(_shortRef),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.orderSuccessSubtitleMint,
                            fontSize: size.width * 0.038,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: size.height * 0.035),
                        SizedBox(
                          width: double.infinity,
                          height: size.height * 0.065,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: AppColors.orderSuccessButtonGradient,
                              borderRadius: BorderRadius.circular(size.width * 0.04),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(size.width * 0.04),
                                onTap: _goToTracking,
                                child: Center(
                                  child: Text(
                                    widget.trackButtonLabel,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: size.width * 0.042,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: size.height * 0.008),
                        TextButton(
                          onPressed: _goHome,
                          child: Text(
                            l10n.backToHome,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: size.width * 0.036,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// White-ringed circle with an emerald checkmark that draws itself as
/// [progress] animates from 0 to 1.
class _AnimatedCheckmark extends AnimatedWidget {
  final double size;

  const _AnimatedCheckmark({required Animation<double> progress, required this.size})
      : super(listenable: progress);

  Animation<double> get _progress => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CheckmarkPainter(progress: _progress.value),
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;

  _CheckmarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, size.width / 2 - ringPaint.strokeWidth / 2, ringPaint);

    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.74, size.height * 0.34);

    final metrics = path.computeMetrics().first;
    final drawnPath = metrics.extractPath(0, metrics.length * progress);

    final checkPaint = Paint()
      ..color = AppColors.primaryLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(drawnPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
