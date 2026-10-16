import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:cmandili_mobile/l10n/app_localizations.dart';

/// One deal in the Happy Hour / promos list, top to bottom: the photo
/// with the -40% badge and the countdown, then name, description, units
/// left, the prices and the "Je prends" button.
class HappyHourCard extends StatefulWidget {
  final String imageUrl;
  final String name;
  final String description;
  final double originalPrice;
  final double discountPrice;
  /// Null for a deal with no end date (it runs until the shop stops it or
  /// its quantity sells out); the countdown badge is hidden then.
  final DateTime? discountEndTime;
  final int? discountQuantity;
  final VoidCallback onTap;
  final VoidCallback onGrab;

  /// Couleur d'accent de la carte : orange pour le Happy Hour, bleu pour les
  /// promotions en pourcentage. Une seule carte pour les deux écrans, donc
  /// une correction d'affichage profite aux deux.
  final Color accentColor;

  const HappyHourCard({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.description,
    required this.originalPrice,
    required this.discountPrice,
    this.discountEndTime,
    this.discountQuantity,
    required this.onTap,
    required this.onGrab,
    this.accentColor = Colors.deepOrange,
  });

  @override
  State<HappyHourCard> createState() => _HappyHourCardState();
}

class _HappyHourCardState extends State<HappyHourCard> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.discountEndTime == null) return; // no end: nothing to count
    _timeLeft = _remaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = _remaining();
      setState(() => _timeLeft = left);
      if (left == Duration.zero) _timer?.cancel();
    });
  }

  Duration _remaining() {
    final left = widget.discountEndTime!.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final discountPercent = ((widget.originalPrice - widget.discountPrice) / widget.originalPrice * 100).round();

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Stack(
              children: [
                _DealPhoto(imageUrl: widget.imageUrl),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _DiscountBadge(
                    percent: discountPercent,
                    color: widget.accentColor,
                  ),
                ),
                // Timer Badge (only for deals that have an end)
                if (widget.discountEndTime != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _CountdownBadge(text: _formatDuration(_timeLeft)),
                  ),
              ],
            ),
            // Details Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  if (widget.discountQuantity != null)
                    _UnitsLeftChip(
                      quantity: widget.discountQuantity!,
                      color: widget.accentColor,
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _DealPrices(
                        originalPrice: widget.originalPrice,
                        discountPrice: widget.discountPrice,
                        color: widget.accentColor,
                      ),
                      _GrabButton(onTap: widget.onGrab, color: widget.accentColor),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 180px photo across the top of the card (grey while loading).
class _DealPhoto extends StatelessWidget {
  final String imageUrl;

  const _DealPhoto({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(height: 180, color: Colors.grey[200]),
        errorWidget: (context, url, error) => Container(
          height: 180,
          color: Colors.grey[200],
          child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
        ),
      ),
    );
  }
}

/// "-40%" pill on the photo.
class _DiscountBadge extends StatelessWidget {
  final int percent;
  final Color color;

  const _DiscountBadge({required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '-$percent%',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

/// Dark "⏱ 01:59:30" pill on the photo.
class _CountdownBadge extends StatelessWidget {
  final String text;

  const _CountdownBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// "📦 Plus que 5" chip.
class _UnitsLeftChip extends StatelessWidget {
  final int quantity;
  final Color color;

  const _UnitsLeftChip({required this.quantity, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context)!
                .happyHourUnitsLeft(quantity),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Old price struck through, deal price big under it.
class _DealPrices extends StatelessWidget {
  final double originalPrice;
  final double discountPrice;
  final Color color;

  const _DealPrices({
    required this.originalPrice,
    required this.discountPrice,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${originalPrice.toStringAsFixed(2)} DT',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        Text(
          '${discountPrice.toStringAsFixed(2)} DT',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// The gradient "Je prends" button.
class _GrabButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;

  const _GrabButton({required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.85),
              color,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color:
                  color.withValues(alpha: 0.4),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          AppLocalizations.of(context)!.happyHourGrab,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
