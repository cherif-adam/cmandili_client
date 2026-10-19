import 'package:supabase_flutter/supabase_flutter.dart';

/// Writes the "pay a bill for me" orders (order_type 'facture').
class FactureRepository {
  final _supabase = Supabase.instance.client;

  /// Inserts the facture order and returns its id. Errors propagate.
  ///
  /// The order starts in 'ready', not 'pending': no partner has to accept a
  /// bill payment, it goes straight to the drivers.
  Future<String> createBillOrder({
    required String userId,
    required Map<String, dynamic> pickupAddress,
    required Map<String, dynamic> deliveryAddress,
    required String billType,
    required String billReference,
    required double billAmount,
    String? billPhotoUrl,
    required String senderPhone,
    required double serviceFee,
  }) async {
    final result = await _supabase
        .from('orders')
        .insert({
          'user_id': userId,
          'order_type': 'facture',
          'status': 'ready',
          'pickup_address': pickupAddress,
          'delivery_address': deliveryAddress,
          'bill_type': billType,
          'bill_reference': billReference,
          'bill_amount': billAmount,
          if (billPhotoUrl != null) 'bill_photo_url': billPhotoUrl,
          'sender_phone': senderPhone,
          'delivery_fee': serviceFee,
          'subtotal': 0,
          'total': serviceFee,
          'payment_method': 'cash',
        })
        .select('id')
        .single();
    return result['id'] as String;
  }
}
