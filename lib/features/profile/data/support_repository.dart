import 'package:supabase_flutter/supabase_flutter.dart';

/// Support tickets opened from the "Aide & support" screen.
class SupportRepository {
  final _supabase = Supabase.instance.client;

  /// Opens a ticket for the signed-in user (`user_id` stays null when signed
  /// out). Errors propagate: the screen shows its own message.
  Future<void> createTicket({
    required String subject,
    required String message,
  }) async {
    await _supabase.from('support_tickets').insert({
      'user_id': _supabase.auth.currentUser?.id,
      'subject': subject,
      'message': message,
      'status': 'open',
    });
  }
}
