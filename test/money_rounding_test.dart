// Arrondi à 50 millimes : la règle de public.round_money(x) côté app, les
// frais de livraison et l'aperçu fidélité (5e et 10e commande).
//
// Les montants attendus sont ceux de la migration
// 20261104120000_arrondi_50_millimes.sql et du rapport
// presentation_assets/arrondi_50_millimes.md.

import 'package:flutter_test/flutter_test.dart';

import 'package:cmandili_mobile/core/utils/delivery_fee.dart';
import 'package:cmandili_mobile/core/utils/money.dart';
import 'package:cmandili_mobile/features/checkout/presentation/checkout/checkout_controller.dart';
import 'package:cmandili_mobile/features/loyalty/data/loyalty_eligibility.dart';
import 'package:cmandili_mobile/features/promo/providers/promo_provider.dart';

const _half = LoyaltyMilestonePreview('half', 0.5);
const _free = LoyaltyMilestonePreview('free', 1.0);

/// Vrai si [amount] est un multiple exact de 50 millimes.
bool _isCashAmount(double amount) => (amount * 1000).round() % 50 == 0;

void main() {
  group('roundMoney (même règle que round_money en SQL)', () {
    test('les exemples de la règle', () {
      expect(roundMoney(0.805), 0.800);
      expect(roundMoney(0.4025), 0.400);
      expect(roundMoney(1.035), 1.050);
      expect(roundMoney(2.375), 2.400);
    });

    test('moitié vers le haut, exactement sur la moitié du pas', () {
      expect(roundMoney(0.025), 0.050);
      expect(roundMoney(0.075), 0.100);
      expect(roundMoney(0.0249999), 0.000);
      expect(roundMoney(1.875), 1.900);
    });

    test('le produit en double ne fait pas tomber du mauvais côté', () {
      // 1,75 x 0,23 = 0,4025 ; 4,5 x 0,23 = 1,035 ; 12,9 x 0,85 = 10,965
      expect(roundMoney(1.75 * 0.23), 0.400);
      expect(roundMoney(4.5 * 0.23), 1.050);
      expect(roundMoney(12.9 * 0.85), 10.950);
      expect(roundMoney(3.5 * 0.23), 0.800);
    });

    test('un multiple du pas ne bouge pas', () {
      for (final v in [0.0, 0.05, 1.75, 2.25, 3.5, 4.5, 24.0, 30.0]) {
        expect(roundMoney(v), v);
      }
    });

    test('négatif : symétrique, comme ROUND en SQL', () {
      expect(roundMoney(-0.805), -0.800);
      expect(roundMoney(-2.375), -2.400);
    });

    test('autre pas', () {
      expect(roundMoney(4.25, step: 0.1), 4.3);
      expect(roundMoney(0.4025, step: 0.001), 0.403);
    });

    test('subtractMoney garde le millime exact', () {
      expect(subtractMoney(3.75, 1.9), 1.85);
      expect(subtractMoney(4.2, 2.1), 2.1);
    });
  });

  group('calculateDeliveryFee arrondi', () {
    test('3 km : base 3,500 DT', () {
      expect(calculateDeliveryFee(distanceKm: 3), 3.5);
    });

    test('5 km : 4,500 DT', () {
      expect(calculateDeliveryFee(distanceKm: 5), 4.5);
    });

    test('4,37 km : 4,185 calculé, 4,200 facturé', () {
      expect(3.5 + (4.37 - 3) * 0.5, closeTo(4.185, 1e-9));
      expect(calculateDeliveryFee(distanceKm: 4.37), 4.2);
    });

    test('autres distances : toujours un multiple de 50 millimes', () {
      for (var km = 0.0; km <= 25; km += 0.01) {
        final fee = calculateDeliveryFee(distanceKm: km);
        expect(_isCashAmount(fee), isTrue, reason: '$km km -> $fee');
        expect(fee, greaterThanOrEqualTo(kDeliveryBaseFee));
      }
    });

    test('sans distance, et forfait supermarché/facture', () {
      expect(calculateDeliveryFee(), 3.5);
      expect(
        calculateDeliveryFee(partnerFlatFee: kFlatDeliveryFee, isFlatRate: true),
        5.0,
      );
    });
  });

  group('aperçu fidélité (5e : round_money(frais / 2), 10e : 0)', () {
    test('3 km : 5e commande 1,750 payé, 10e gratuite', () {
      expect(_half.paidFee(3.5), 1.75);
      expect(_half.discountOn(3.5), 1.75);
      expect(_free.paidFee(3.5), 0.0);
      expect(_free.discountOn(3.5), 3.5);
    });

    test('5 km : 5e commande 2,250 payé, 10e gratuite', () {
      expect(_half.paidFee(4.5), 2.25);
      expect(_half.discountOn(4.5), 2.25);
      expect(_free.discountOn(4.5), 4.5);
    });

    test('4,37 km (frais 4,200) : 5e commande 2,100 payé', () {
      final fee = calculateDeliveryFee(distanceKm: 4.37);
      expect(_half.paidFee(fee), 2.1);
      expect(_half.discountOn(fee), 2.1);
    });

    test('3,5 km (frais 3,750) : la moitié 1,875 devient 1,900 payé', () {
      final fee = calculateDeliveryFee(distanceKm: 3.5);
      expect(fee, 3.75);
      expect(_half.paidFee(fee), 1.9);
      expect(_half.discountOn(fee), 1.85);
    });

    test('payé + remise = frais, et le payé est un montant en espèces', () {
      for (var km = 0.0; km <= 25; km += 0.01) {
        final fee = calculateDeliveryFee(distanceKm: km);
        for (final p in [_half, _free]) {
          expect(_isCashAmount(p.paidFee(fee)), isTrue, reason: '$km km');
          expect(
            ((p.paidFee(fee) + p.discountOn(fee)) * 1000).round(),
            (fee * 1000).round(),
            reason: '$km km',
          );
        }
      }
    });
  });

  group('checkoutPreviewTotals', () {
    test('5e commande, repas 30 DT à 3,5 km : 30 + 1,900 = 31,900', () {
      final totals = checkoutPreviewTotals(
        subtotal: 30,
        deliveryFee: calculateDeliveryFee(distanceKm: 3.5),
        promoState: const PromoState(),
        loyaltyPreview: _half,
      );
      expect(totals.loyaltyDiscount, 1.85);
      expect(totals.estimatedTotal, closeTo(31.9, 1e-9));
    });

    test('commande normale à 5 km : 30 + 4,500', () {
      final totals = checkoutPreviewTotals(
        subtotal: 30,
        deliveryFee: calculateDeliveryFee(distanceKm: 5),
        promoState: const PromoState(),
        loyaltyPreview: null,
      );
      expect(totals.loyaltyDiscount, 0.0);
      expect(totals.estimatedTotal, 34.5);
    });
  });
}
