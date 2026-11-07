// The client's orange login (2026-11-07): every colour that carries white
// text or white icons, and the orange text on the white card, must keep its
// WCAG contrast. A lighter orange swapped in later fails here, not on a
// customer's phone.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cmandili_mobile/core/theme/app_colors.dart';

/// WCAG 2.x relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const white = Colors.white;

  test('white text on the buttons and the active tab: AA (4.5:1)', () {
    expect(_contrast(white, AppColors.brandOrangeDeep), greaterThanOrEqualTo(4.5));
    expect(_contrast(white, AppColors.brandOrangeDark), greaterThanOrEqualTo(4.5));
    for (final c in AppColors.brandButtonGradient.colors) {
      expect(_contrast(white, c), greaterThanOrEqualTo(4.5), reason: '$c');
    }
  });

  test('white title and subtitle on the top of the background: AA (4.5:1)', () {
    // The logo header sits in the top third, which stays deep orange.
    const gradient = AppColors.brandBackgroundGradient;
    expect(gradient.stops![1], greaterThanOrEqualTo(0.3));
    expect(_contrast(white, gradient.colors[0]), greaterThanOrEqualTo(4.5));
    expect(_contrast(white, gradient.colors[1]), greaterThanOrEqualTo(4.5));
  });

  test('white system-bar icons at the bottom of the background: 3:1', () {
    final bottom = AppColors.brandBackgroundGradient.colors.last;
    expect(_contrast(white, bottom), greaterThanOrEqualTo(3.0));
  });

  test('orange links and labels on the white card: AA (4.5:1)', () {
    expect(_contrast(AppColors.brandOrangeDeep, white), greaterThanOrEqualTo(4.5));
  });

  test('why the existing food oranges were not used for text', () {
    expect(_contrast(white, AppColors.foodPrimary), lessThan(4.5));
    expect(_contrast(white, AppColors.foodPrimaryDark), lessThan(4.5));
  });
}
