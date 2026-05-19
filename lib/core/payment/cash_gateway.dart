import 'payment_gateway.dart';

/// Cash on Delivery — always succeeds immediately (no network call).
class CashGateway implements PaymentGateway {
  const CashGateway();

  @override
  String get displayName => 'Cash on Delivery';

  @override
  String get methodKey => 'cash';

  @override
  Future<PaymentResult> processPayment({
    required String orderId,
    required double amount,
  }) async {
    return const PaymentResult(
      success: true,
      gatewayRef: null,
      rawPayload: {'method': 'cash'},
    );
  }
}
