/// Result returned by every payment gateway after a processing attempt.
class PaymentResult {
  final bool success;
  final String? gatewayRef;    // transaction ID from gateway
  final String? errorMessage;
  final Map<String, dynamic>? rawPayload; // full gateway response for audit

  const PaymentResult({
    required this.success,
    this.gatewayRef,
    this.errorMessage,
    this.rawPayload,
  });
}

/// Common interface every payment gateway must implement.
abstract class PaymentGateway {
  /// Human-readable name shown in the UI (e.g. "Cash on Delivery").
  String get displayName;

  /// Short method key stored in the database (e.g. "cash").
  String get methodKey;

  /// Process a payment for [amount] DT tied to [orderId].
  /// Returns a [PaymentResult] — never throws.
  Future<PaymentResult> processPayment({
    required String orderId,
    required double amount,
  });
}
