import 'package:cmandili_mobile/features/orders/data/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

/// When the "did you receive your order?" question is asked, and when it is
/// not (Order.awaitsReceiptConfirmation / receiptAutoConfirmed).
void main() {
  Order order({
    required String status,
    String? deliveredAt,
    String? clientConfirmation,
  }) {
    return Order.fromJson({
      'id': 'o1',
      'userId': 'u1',
      'deliveryAddress': <String, dynamic>{},
      'subtotal': 10,
      'deliveryFee': 2,
      'total': 12,
      'status': status,
      'createdAt': '2026-10-11T10:00:00Z',
      'driverId': 'd1',
      'deliveredAt': deliveredAt,
      'clientConfirmation': clientConfirmation,
    });
  }

  test('an order delivered before the feature existed never asks', () {
    // delivered_at is null on every older order, and on every order while
    // the database script has not been run.
    final o = order(status: 'delivered');
    expect(o.deliveredAt, isNull);
    expect(o.awaitsReceiptConfirmation, isFalse);
    expect(o.receiptAutoConfirmed, isFalse);
  });

  test('just delivered by the driver: the question is open', () {
    final o = order(status: 'delivered', deliveredAt: '2026-10-11T10:30:00Z');
    expect(o.awaitsReceiptConfirmation, isTrue);
  });

  test('not asked before the driver has delivered', () {
    for (final s in ['pending', 'confirmed', 'preparing', 'ready', 'onTheWay']) {
      expect(order(status: s).awaitsReceiptConfirmation, isFalse, reason: s);
    }
  });

  test('once the customer answered, it is closed for good', () {
    for (final answer in ['confirmed', 'not_received']) {
      final o = order(
        status: 'delivered',
        deliveredAt: '2026-10-11T10:30:00Z',
        clientConfirmation: answer,
      );
      expect(o.awaitsReceiptConfirmation, isFalse, reason: answer);
      expect(o.receiptAutoConfirmed, isFalse, reason: answer);
    }
  });

  test('confirmed by the 3-minute timer: closed, but can still be disputed',
      () {
    final o = order(
      status: 'delivered',
      deliveredAt: '2026-10-11T10:30:00Z',
      clientConfirmation: 'auto_confirmed',
    );
    expect(o.awaitsReceiptConfirmation, isFalse);
    expect(o.receiptAutoConfirmed, isTrue);
  });

  test('the customer has three minutes', () {
    expect(Order.receiptWindow, const Duration(minutes: 3));
  });

  test('survives a round trip through toJson', () {
    final o = order(
      status: 'delivered',
      deliveredAt: '2026-10-11T10:30:00Z',
      clientConfirmation: 'auto_confirmed',
    );
    final back = Order.fromJson(o.toJson());
    expect(back.deliveredAt, o.deliveredAt);
    expect(back.clientConfirmation, 'auto_confirmed');
  });
}
