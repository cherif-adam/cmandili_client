import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../rating/presentation/driver_rating_sheet.dart';
import '../../../data/models/order.dart';
import '../../../providers/order_provider.dart';

/// "Did you receive your order?" -- shown on the tracking screen once the
/// driver has marked the order delivered.
///
/// Until now delivery was the driver's word alone. The customer now gets
/// three minutes to say yes or no; with no answer the server confirms for
/// them, and they can still report afterwards that the order never came.
/// A "yes" leads straight into rating the driver.
///
/// Renders nothing for an order with no `deliveredAt` -- every order from
/// before this feature, and every order while the database script behind it
/// has not been run.
class ReceiptConfirmationCard extends ConsumerStatefulWidget {
  final Order order;

  /// Called when the customer's part is over (answered, and any rating
  /// sheet closed), so the screen can go on to what it was holding back.
  final VoidCallback? onFlowFinished;

  const ReceiptConfirmationCard({
    super.key,
    required this.order,
    this.onFlowFinished,
  });

  /// True while this card has a dialog or the rating sheet open. The
  /// tracking screen reads it to avoid stacking its own shop-rating sheet on
  /// top.
  static bool flowBusy = false;

  @override
  ConsumerState<ReceiptConfirmationCard> createState() =>
      _ReceiptConfirmationCardState();
}

class _ReceiptConfirmationCardState
    extends ConsumerState<ReceiptConfirmationCard> {
  Timer? _ticker;
  bool _saving = false;

  /// A parcel is sent TO someone: the customer answering here is the sender,
  /// who did not receive anything. Same question, asked the right way round.
  bool get _isParcel => widget.order.type == OrderType.courier;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant ReceiptConfirmationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// The countdown only needs a tick while the question is open.
  void _syncTicker() {
    if (widget.order.awaitsReceiptConfirmation) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Duration get _remaining {
    final deadline = widget.order.deliveredAt!.add(Order.receiptWindow);
    final left = deadline.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> _answer(bool received) async {
    if (_saving) return;
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    ReceiptConfirmationCard.flowBusy = true;

    try {
      if (!received) {
        final sure = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.receiptReportTitle),
            content: Text(
                _isParcel ? l.receiptReportBodyParcel : l.receiptReportBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.rateDriverLater),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  l.receiptReportConfirm,
                  style: const TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
        if (sure != true || !mounted) return;
      }

      setState(() => _saving = true);
      final state = await ref
          .read(orderRepositoryProvider)
          .confirmReceipt(widget.order.id, received: received);
      // The home-screen reminder for this order can go now.
      ref.invalidate(receiptPendingOrderProvider);
      if (!mounted) return;
      setState(() => _saving = false);

      if (state == null) {
        messenger.showSnackBar(SnackBar(
          content: Text(l.receiptSaveFailed),
          backgroundColor: AppColors.error,
        ));
        return;
      }
      messenger.showSnackBar(SnackBar(
        content: Text(received ? l.receiptConfirmed : l.receiptReported),
        backgroundColor: received ? AppColors.success : AppColors.warning,
      ));

      if (received) {
        await DriverRatingSheet.maybeShow(context, ref: ref, order: widget.order);
      }
    } finally {
      ReceiptConfirmationCard.flowBusy = false;
      if (mounted) setState(() => _saving = false);
      widget.onFlowFinished?.call();
    }
  }

  Future<void> _rateDriver() async {
    ReceiptConfirmationCard.flowBusy = true;
    try {
      await DriverRatingSheet.maybeShow(context, ref: ref, order: widget.order);
    } finally {
      ReceiptConfirmationCard.flowBusy = false;
      widget.onFlowFinished?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    if (order.status != OrderStatus.delivered || order.deliveredAt == null) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context)!;

    if (order.awaitsReceiptConfirmation) {
      return _ReceiptQuestion(
        isParcel: _isParcel,
        remaining: _remaining,
        saving: _saving,
        onAnswer: _answer,
      );
    }

    final hasDriver = order.driverId != null && order.driverId!.isNotEmpty;
    final canRate = hasDriver &&
        order.clientConfirmation != 'not_received' &&
        (ref.watch(canRateDriverProvider(order.id)).valueOrNull ?? false);

    switch (order.clientConfirmation) {
      case 'not_received':
        return _ReceiptNotice(
          icon: Icons.support_agent_rounded,
          color: AppColors.warning,
          text: l.receiptReported,
        );
      case 'auto_confirmed':
        return _ReceiptNotice(
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.success,
          text: l.receiptAutoConfirmed,
          actions: [
            if (canRate)
              TextButton.icon(
                onPressed: _rateDriver,
                icon: const Icon(Icons.star_rounded, size: 18),
                label: Text(l.rateDriverButton),
              ),
            // Nobody answered in time: the customer can still say it never
            // came.
            TextButton(
              onPressed: _saving ? null : () => _answer(false),
              child: Text(
                _isParcel
                    ? l.receiptNotDeliveredParcelLink
                    : l.receiptNotReceivedLink,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      default: // 'confirmed'
        if (!canRate) return const SizedBox.shrink();
        return _ReceiptNotice(
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
          text: l.receiptConfirmed,
          actions: [
            TextButton.icon(
              onPressed: _rateDriver,
              icon: const Icon(Icons.star_rounded, size: 18),
              label: Text(l.rateDriverButton),
            ),
          ],
        );
    }
  }
}

/// The open question: "Avez-vous reçu votre commande ?", a bar and
/// "auto-confirmed in 2:41", then No / Yes (a spinner while saving).
class _ReceiptQuestion extends StatelessWidget {
  final bool isParcel;
  final Duration remaining;
  final bool saving;
  final ValueChanged<bool> onAnswer;

  const _ReceiptQuestion({
    required this.isParcel,
    required this.remaining,
    required this.saving,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final left = remaining;
    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${left.inMinutes}:${two(left.inSeconds % 60)}';
    final fraction =
        left.inMilliseconds / Order.receiptWindow.inMilliseconds;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isParcel ? l.receiptQuestionParcel : l.receiptQuestion,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.receiptAutoIn(time),
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 14),
          if (saving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onAnswer(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isParcel ? l.receiptNoParcel : l.receiptNo,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => onAnswer(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isParcel ? l.receiptYesParcel : l.receiptYes,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A colored box with an icon and a sentence (reported / confirmed),
/// and optional buttons under it.
class _ReceiptNotice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final List<Widget> actions;

  const _ReceiptNotice({
    required this.icon,
    required this.color,
    required this.text,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (actions.isEmpty)
            const SizedBox(height: 6)
          else
            Wrap(spacing: 4, children: actions),
        ],
      ),
    );
  }
}
