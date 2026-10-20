import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../core/theme/app_colors.dart';
import '../../orders/data/models/order.dart';
import '../../orders/providers/order_provider.dart';

/// Lets the customer rate the driver who delivered [order]: 1-5 stars and an
/// optional comment. One rating per order; the driver sees it in their
/// profile, and a database trigger keeps their average.
///
/// The twin of [RatingPromptSheet], which rates the shop. Kept separate
/// because the two are different questions, written to different tables,
/// and an order can have a driver without being a "food" order (parcels,
/// boutiques, bills).
class DriverRatingSheet extends ConsumerStatefulWidget {
  final Order order;

  const DriverRatingSheet({super.key, required this.order});

  /// Shows the sheet if this order has a driver who has not been rated yet.
  /// Does nothing -- and never throws -- when it does not apply, when the
  /// rating was already given, or when ratings are not available yet (the
  /// database script has not been run).
  static Future<void> maybeShow(
    BuildContext context, {
    required WidgetRef ref,
    required Order order,
  }) async {
    final driverId = order.driverId;
    if (order.status != OrderStatus.delivered ||
        driverId == null ||
        driverId.isEmpty) {
      return;
    }
    try {
      final canRate =
          await ref.read(orderRatingRepositoryProvider).canRateDriver(order.id);
      if (!canRate || !context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DriverRatingSheet(order: order),
      );
    } catch (_) {
      // A rating is a nice-to-have: never worth interrupting the order flow.
    }
  }

  @override
  ConsumerState<DriverRatingSheet> createState() => _DriverRatingSheetState();
}

class _DriverRatingSheetState extends ConsumerState<DriverRatingSheet> {
  int _stars = 0;
  bool _submitting = false;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0 || _submitting) return;
    setState(() => _submitting = true);
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final success = await ref.read(orderRatingRepositoryProvider).submitDriverRating(
          orderId: widget.order.id,
          driverId: widget.order.driverId!,
          rating: _stars,
          comment: _commentController.text,
        );
    // The "rate the driver" button elsewhere reads this.
    ref.invalidate(canRateDriverProvider(widget.order.id));

    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(success ? l.rateDriverThanks : l.rateDriverFailed),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final driverName = widget.order.driverName;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Icon(Icons.delivery_dining_rounded,
                  color: AppColors.primary, size: 34),
              const SizedBox(height: 8),
              Text(
                l.rateDriverTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              if (driverName != null && driverName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  driverName,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final filled = i < _stars;
                  return IconButton(
                    onPressed: () => setState(() => _stars = i + 1),
                    icon: Icon(
                      filled ? Icons.star_rounded : Icons.star_border_rounded,
                      color: AppColors.star,
                      size: 36,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentController,
                maxLines: 2,
                maxLength: 240,
                decoration: InputDecoration(
                  hintText: l.rateDriverHint,
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _stars == 0 || _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(l.rateDriverSend,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              TextButton(
                onPressed: _submitting ? null : () => Navigator.pop(context),
                child: Text(l.rateDriverLater,
                    style: TextStyle(color: Colors.grey[600])),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
