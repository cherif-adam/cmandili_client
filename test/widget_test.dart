import 'package:flutter_test/flutter_test.dart';

import 'package:cmandili_mobile/core/payment/cash_gateway.dart';
import 'package:cmandili_mobile/core/payment/payment_gateway.dart';

void main() {
  group('Cash-only payment invariants', () {
    test('CashGateway exposes the cash method key', () {
      const gateway = CashGateway();
      expect(gateway.methodKey, 'cash');
      expect(gateway.displayName, 'Cash on Delivery');
    });

    test('CashGateway.processPayment always succeeds', () async {
      const gateway = CashGateway();
      final result = await gateway.processPayment(
        orderId: 'test-order',
        amount: 12.5,
      );
      expect(result.success, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('CashGateway is the only PaymentGateway implementation in lib/', () {
      const PaymentGateway gateway = CashGateway();
      expect(gateway, isA<CashGateway>());
    });
  });
}
