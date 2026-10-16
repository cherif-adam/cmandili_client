import 'package:flutter/material.dart';

import '../../../loyalty/data/loyalty_eligibility.dart';
import 'courier_colors.dart';

/// The purple gradient card with the estimated price (struck through +
/// discounted when a loyalty reward applies), the distance, and the
/// "3.500 TND base / +0.500/km" tariff on the right.
class CourierPriceCard extends StatelessWidget {
  final bool isCalculating;
  final double? estimatedPrice;
  final double? estimatedDistanceKm;
  final LoyaltyMilestonePreview? loyaltyPreview;
  final double screenWidth;
  final double screenHeight;

  const CourierPriceCard({
    super.key,
    required this.isCalculating,
    required this.estimatedPrice,
    required this.estimatedDistanceKm,
    required this.loyaltyPreview,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final w = screenWidth;
    final h = screenHeight;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(w * 0.04),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C3DE1), Color(0xFF9C6DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(w * 0.04),
        boxShadow: [
          BoxShadow(
            color: kCourierPurple.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: isCalculating
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            )
          : Row(
              children: [
                Container(
                  padding: EdgeInsets.all(w * 0.03),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.local_shipping_rounded,
                      color: Colors.white, size: w * 0.07),
                ),
                SizedBox(width: w * 0.04),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loyaltyPreview == null
                            ? 'Prix estimé'
                            : loyaltyPreview!.type == 'free'
                                ? 'Prix estimé — fidélité : livraison gratuite'
                                : 'Prix estimé — fidélité : -50%',
                        style: TextStyle(
                            color: Colors.white70, fontSize: w * 0.033),
                      ),
                      SizedBox(height: h * 0.004),
                      if (estimatedPrice != null && loyaltyPreview != null) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${estimatedPrice!.toStringAsFixed(3)} TND',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: w * 0.04,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            SizedBox(width: w * 0.02),
                            Text(
                              '${(estimatedPrice! * (1 - loyaltyPreview!.discountMultiplier)).toStringAsFixed(3)} TND',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: w * 0.06,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ] else
                        Text(
                          estimatedPrice != null
                              ? '${estimatedPrice!.toStringAsFixed(3)} TND'
                              : '...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: w * 0.06,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (estimatedDistanceKm != null)
                        Text(
                          '${estimatedDistanceKm!.toStringAsFixed(1)} km',
                          style: TextStyle(
                              color: Colors.white70, fontSize: w * 0.032),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('3.500 TND base',
                        style: TextStyle(
                            color: Colors.white60, fontSize: w * 0.028)),
                    Text('+0.500/km > 3km',
                        style: TextStyle(
                            color: Colors.white60, fontSize: w * 0.028)),
                  ],
                ),
              ],
            ),
    );
  }
}
