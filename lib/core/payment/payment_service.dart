import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'payment_gateway.dart';
import 'cash_gateway.dart';

/// Orchestrates payment processing:
///   1. Delegates to the correct [PaymentGateway]
///   2. On success, inserts a row into the `payments` table
///   3. Returns the [PaymentResult]
class PaymentService {
  final _supabase = Supabase.instance.client;

  /// Build the gateway instance for [methodKey]. MVP supports cash only.
  PaymentGateway gatewayFor(String methodKey, BuildContext context) {
    return const CashGateway();
  }

  /// Process payment and, on success, persist a `payments` row.
  Future<PaymentResult> processAndRecord({
    required String orderId,
    required double amount,
    required String methodKey,
    required BuildContext context,
  }) async {
    final gateway = gatewayFor(methodKey, context);
    final result = await gateway.processPayment(
      orderId: orderId,
      amount: amount,
    );

    if (result.success) {
      try {
        final userId = _supabase.auth.currentUser?.id;
        // Cash on delivery is recorded as `pending` — it becomes `paid`
        // only when the driver marks the order as delivered and collects.
        await _supabase.from('payments').insert({
          'order_id': orderId,
          'user_id': userId,
          'amount': amount,
          'method': 'cash',
          'status': 'pending',
          'gateway_ref': result.gatewayRef,
          'gateway_payload': result.rawPayload,
        });
      } catch (e) {
        // Best-effort audit insert; order flow continues if it fails.
        debugPrint('Failed to record payment row: $e');
      }
    }

    return result;
  }
}
