import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// What the assistant adds from the customer's own account: their usual
/// parcel recipient, their usual bill, the status of their order in flight.
/// Best-effort reads: any failure leaves the model's sentence as it was (or
/// says the status could not be read).
class AccountHints {
  AccountHints(this._supabase);

  final SupabaseClient _supabase;

  // ── Colis personalization (delivery_request) ──────────────────────────────
  // Light touch, not a search: mention the user's most recently saved
  // recipient (courier_screen.dart already lets a driver save one after
  // delivery) so "how do I send a package" isn't purely generic when we
  // already know who they usually send to. No new intent, no cards — one
  // extra sentence appended to the existing explanation.
  Future<String> appendRecipientHint(String leadIn) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return leadIn;
    try {
      final row = await _supabase
          .from('saved_recipients')
          .select('name')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final name = (row?['name'] as String?)?.trim();
      if (name == null || name.isEmpty) return leadIn;
      return "$leadIn\n\nD'ailleurs, tu as déjà $name enregistré comme destinataire — tu peux lui "
          'renvoyer un colis en un clic depuis la section Colis 📦';
    } catch (e) {
      debugPrint('AiChatService – recipient hint error: $e');
      return leadIn;
    }
  }

  // ── Facture personalization (general intent, facture-shaped text) ─────────
  // There's no "saved bill references" table (unlike saved_recipients for
  // colis), so this infers a pattern from past facture orders' bill_type
  // instead of a dedicated saved list. With only test data in the DB today
  // this mostly has nothing to say yet — it silently falls back to the plain
  // explanation, which is the correct behaviour, not a bug.
  bool looksLikeFactureQuestion(String text) {
    final t = text.toLowerCase();
    const triggers = ['facture', 'fatoura', 'steg', 'sonede', 'topnet', 'bill', 'invoice'];
    return triggers.any(t.contains);
  }

  Future<String> appendBillTypeHint(String leadIn) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return leadIn;
    try {
      final rows = await _supabase
          .from('orders')
          .select('bill_type')
          .eq('user_id', userId)
          .eq('order_type', 'facture')
          .not('bill_type', 'is', null)
          .order('created_at', ascending: false)
          .limit(20) as List<dynamic>;
      if (rows.isEmpty) return leadIn;

      // Most frequent bill_type in the last 20 factures; ties favour the more
      // recent one since rows arrive newest-first and reduce() keeps the
      // earlier-seen entry on a tie (b.value > a.value is false, so a wins).
      final counts = <String, int>{};
      for (final r in rows.cast<Map<String, dynamic>>()) {
        final bt = (r['bill_type'] as String?)?.trim();
        if (bt != null && bt.isNotEmpty) counts[bt] = (counts[bt] ?? 0) + 1;
      }
      if (counts.isEmpty) return leadIn;
      final topType =
          counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;

      return '$leadIn\n\nTu payes souvent ta facture ${_billTypeLabel(topType)} par ici — dis-moi '
          "si c'est celle-ci 👍";
    } catch (e) {
      debugPrint('AiChatService – bill type hint error: $e');
      return leadIn;
    }
  }

  static String _billTypeLabel(String billType) => switch (billType.toLowerCase()) {
        'steg' => 'STEG',
        'sonede' => 'SONEDE',
        'topnet' => 'Topnet',
        _ => billType,
      };

  // ── Order tracking (track_order intent) ───────────────────────────────────
  // Client-side, same pattern as the food/shop queries above: plain
  // RLS-guarded reads against the customer's own session, no secret needed.
  // Deliberately does NOT attempt to resolve driver name/phone: profiles' RLS
  // only allows reading your OWN row (auth.uid() = id), so a customer-session
  // query for a driver's profile always returns nothing — the same reason
  // OrderRepository._mapOrderFromDb hardcodes driverName/driverPhone to null
  // today. Not attempting it here avoids a query that would just silently
  // fail; showing status + venue is what's actually reliable to promise.

  static const Set<String> _terminalOrderStatuses = {'delivered', 'cancelled'};

  /// The user's most recent NON-terminal order, or null if signed out, on any
  /// read error, or if their most recent orders are all delivered/cancelled.
  /// Shared by buildOrderStatusReply and hasActiveOrder (chip context) so
  /// there's exactly one place that defines "what counts as active."
  Future<Map<String, dynamic>?> _fetchActiveOrderRow() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final rows = await _supabase
          .from('orders')
          .select('id, status, order_type, restaurant_id, supermarket_id')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(10) as List<dynamic>;

      final active = rows.cast<Map<String, dynamic>>().firstWhere(
            (o) => !_terminalOrderStatuses.contains(o['status']),
            orElse: () => const {},
          );
      return active.isEmpty ? null : active;
    } catch (e) {
      debugPrint('AiChatService – active order lookup error: $e');
      return null;
    }
  }

  /// Whether the user currently has an order in flight — used by the chat
  /// screen to decide whether to show a "Suivre ma commande" starter chip.
  /// Best-effort: any failure (including signed-out) reads as "no", which is
  /// the safe default — worst case a chip that would have been useful is
  /// simply not shown, never a chip promising a tracking result that isn't
  /// really there.
  Future<bool> hasActiveOrder() async => (await _fetchActiveOrderRow()) != null;

  Future<String> buildOrderStatusReply(String leadIn) async {
    try {
      final active = await _fetchActiveOrderRow();
      if (active == null) {
        return "$leadIn\n\nVous n'avez pas de commande en cours actuellement 🙂";
      }

      final shortId = (active['id'] as String).substring(0, 8).toUpperCase();
      final status = (active['status'] ?? '') as String;
      final isFacture = active['order_type'] == 'facture';

      String? venueName;
      final restaurantId = active['restaurant_id'] as String?;
      final supermarketId = active['supermarket_id'] as String?;
      if (restaurantId != null) {
        final r = await _supabase
            .from('restaurants')
            .select('name')
            .eq('id', restaurantId)
            .maybeSingle();
        venueName = r?['name'] as String?;
      } else if (supermarketId != null) {
        final s = await _supabase
            .from('supermarkets')
            .select('name')
            .eq('id', supermarketId)
            .maybeSingle();
        venueName = s?['name'] as String?;
      }

      final buffer = StringBuffer(leadIn)
        ..write(isFacture ? '\n\n🧾 Facture #$shortId' : '\n\n📦 Commande #$shortId');
      if (venueName != null && venueName.isNotEmpty) buffer.write(' — $venueName');
      buffer.write('\nStatut : ${_orderStatusLabel(status, isFacture: isFacture)}');

      return buffer.toString();
    } catch (e) {
      debugPrint('AiChatService – order status lookup error: $e');
      return "$leadIn\n\nImpossible de récupérer le statut de votre commande pour le moment 😕";
    }
  }

  // isFacture branches the mid-lifecycle labels to match what the driver app
  // itself shows for a facture (order_tracking_screen.dart: "Espèces
  // collectées" at pickedUp) — a generic "Récupérée par le livreur 🛵" reads
  // like a package, which is confusing when nothing physical was picked up.
  static String _orderStatusLabel(String status, {bool isFacture = false}) => switch (status) {
        'pending' => 'En attente de confirmation ⏳',
        'confirmed' => 'Confirmée, en préparation 👨‍🍳',
        'preparing' => 'En préparation 👨‍🍳',
        'ready' => isFacture
            ? "En attente qu'un livreur se charge de votre facture 🧾"
            : "Prête, en attente d'un livreur 📦",
        'pickedUp' => isFacture
            ? 'Espèces collectées par le livreur 💵'
            : 'Récupérée par le livreur 🛵',
        'onTheWay' => isFacture
            ? 'Le livreur est en route pour payer votre facture 🧾'
            : 'En route vers vous 🛵',
        _ => status,
      };
}
