import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../orders/data/models/order.dart';
import '../../orders/providers/order_provider.dart';

/// Minimal post-delivery "rate your order" bottom sheet — 1-5 stars plus an
/// optional comment. Deliberately small in scope: write-once (matches the
/// DB's write-once RLS policy in 20260915090000_order_ratings.sql), no
/// photo/tag/per-item rating, food orders only.
///
/// Dismissing without submitting isn't tracked anywhere, so the prompt can
/// reappear the next time this same delivered order's tracking screen is
/// reopened (OrderRepository.hasRating is the only durable gate, and it
/// only turns false->true once a rating is actually submitted). Accepted
/// trade-off for a minimal first version: the prompt only ever appears when
/// the customer themselves reopens that specific order, never unprompted
/// elsewhere, so the ceiling on how "spammy" it can be is already low.
class RatingPromptSheet extends ConsumerStatefulWidget {
  final Order order;

  const RatingPromptSheet({super.key, required this.order});

  /// Shows the sheet — or does nothing if the order isn't rating-eligible
  /// (not a delivered food order) or already has a rating. Must never throw
  /// and must never block the caller's own navigation.
  static Future<void> maybeShow(
    BuildContext context, {
    required WidgetRef ref,
    required Order order,
  }) async {
    if (order.type != OrderType.food || order.status != OrderStatus.delivered) return;

    try {
      final alreadyRated = await ref.read(orderRepositoryProvider).hasRating(order.id);
      if (alreadyRated || !context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => RatingPromptSheet(order: order),
      );
    } catch (_) {
      // Fail silently -- rating is a nice-to-have, never worth interrupting
      // or erroring out of the order tracking flow.
    }
  }

  @override
  ConsumerState<RatingPromptSheet> createState() => _RatingPromptSheetState();
}

class _RatingPromptSheetState extends ConsumerState<RatingPromptSheet> {
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

    final success = await ref.read(orderRepositoryProvider).submitRating(
          orderId: widget.order.id,
          restaurantId: widget.order.restaurantId,
          rating: _stars,
          comment: _commentController.text,
        );

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Merci pour votre avis !'
              : 'Impossible d\'envoyer votre avis pour le moment.',
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'Comment était votre commande ?',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              const SizedBox(height: 4),
              Text(
                widget.order.restaurantName,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 18),
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
                  hintText: 'Un commentaire ? (facultatif)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Envoyer', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              TextButton(
                onPressed: _submitting ? null : () => Navigator.pop(context),
                child: Text('Plus tard', style: TextStyle(color: Colors.grey[600])),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
