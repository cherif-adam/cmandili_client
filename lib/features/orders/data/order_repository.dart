import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/order.dart';
import 'order_row_mapper.dart';

/// One-off reads of the customer's orders: history, one order with its
/// lines, the active order, bills, the order awaiting confirmation and the
/// loyalty count. Writes, live streams, ratings and reorder have their own
/// repositories next to this one.
class OrderRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Order>> getUserOrders() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('orders')
        // The venue embed has to answer two separate problems.
        //
        // Naming the constraint: since `restaurants` became a view over the
        // generic `vendors` table, PostgREST sees TWO paths from orders to it
        // — orders.restaurant_id and orders.supermarket_id both land there —
        // and refuses to guess, failing the whole history with PGRST201.
        //
        // Embedding `vendors` rather than the `restaurants` view: that view
        // is filtered to category = 'food', so going through it returns NULL
        // for an order placed at a florist, pet shop, bakery, gift or
        // electronics store — the history would show the order with no shop
        // name. Verified live: the same three orders come back
        // "Digital House | Boutique Nour | Boutique Nour" through vendors and
        // "NULL | NULL | NULL" through the view. The alias keeps the JSON key
        // the mappers below expect. Same form as the driver app's
        // driver_orders_provider.dart.
        //
        // Join each line's product row so the history/tracking screens can
        // show "2x Pizza Margherita" instead of a blank name. `food_items`
        // and `grocery_items` are now views over `vendors`, so PostgREST
        // can't resolve an embed through them — point the embed at the
        // underlying tables (same aliases the partner app uses) and keep
        // the view's name as the alias so the mapping below is unchanged.
        .select(kOrderWithDetails)
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Order.fromJson(mapOrderFromDb(json)))
        .toList();
  }

  /// Une commande AVEC ses lignes, son commerce et la catégorie de celui-ci.
  ///
  /// L'écran de suivi ne peut pas obtenir ça de son flux temps réel :
  /// `.stream()` renvoie les lignes BRUTES de la table `orders` et ne sait pas
  /// porter de jointure PostgREST. `order_items` et `restaurants` n'y
  /// figuraient donc jamais, et le « Récapitulatif » était vide pour TOUTES
  /// les catégories, restaurants compris — ce n'était pas un problème d'embed
  /// propre aux boutiques génériques.
  ///
  /// Lu une seule fois : les lignes d'une commande ne changent plus après sa
  /// création. Le flux continue de porter ce qui bouge — statut, livreur,
  /// position.
  Future<Order?> getOrderWithDetails(String orderId) async {
    try {
      final row = await _supabase
          .from('orders')
          .select(kOrderWithDetails)
          .eq('id', orderId)
          .maybeSingle();
      return row == null ? null : Order.fromJson(mapOrderFromDb(row));
    } catch (e) {
      // Une jointure peut échouer sur une dérive de schéma. Le suivi doit
      // rester lisible sans elle : le flux porte déjà l'essentiel.
      debugPrint('getOrderWithDetails error: $e');
      return null;
    }
  }

  /// The customer's newest order that is not yet delivered or cancelled, or
  /// null. Deliberately a bare `select('*')` with no embeds: the history
  /// query's joins can fail on schema drift, and this call is the only way
  /// back into tracking, so it must not share that failure mode.
  Future<Order?> getActiveOrder() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _supabase
        .from('orders')
        .select('*')
        .eq('user_id', userId)
        .not('status', 'in', '(delivered,cancelled)')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return Order.fromJson(mapOrderFromDb(row));
  }

  /// The customer's most recent order that the driver has delivered and that
  /// is still waiting for their confirmation, or null. Backs the home-screen
  /// reminder: once an order is delivered it is no longer "active", so
  /// without this the question would only ever be seen by someone who
  /// happened to be on the tracking screen.
  ///
  /// Returns null on any error -- including the columns not existing yet.
  Future<Order?> getOrderAwaitingReceipt() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final row = await _supabase
          .from('orders')
          .select('*')
          .eq('user_id', userId)
          .eq('status', 'delivered')
          .isFilter('client_confirmation', null)
          .not('delivered_at', 'is', null)
          .order('delivered_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return Order.fromJson(mapOrderFromDb(row));
    } catch (e) {
      return null;
    }
  }

  /// Customer's lifetime delivered-order count for the loyalty program
  /// (unified across food/courier/facture). Returns 0 if the customer has
  /// no qualifying delivered order yet (no row exists).
  Future<int> getLoyaltyDeliveredCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;
    try {
      final row = await _supabase
          .from('loyalty_customer_progress')
          .select('delivered_count')
          .eq('customer_id', userId)
          .maybeSingle();
      return (row?['delivered_count'] as int?) ?? 0;
    } catch (e) {
      debugPrint('Error fetching loyalty progress: $e');
      return 0;
    }
  }

  Future<List<Order>> getBillOrders() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('orders')
        .select('*')
        .eq('user_id', userId)
        .eq('order_type', 'facture')
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Order.fromJson(mapOrderFromDb(json)))
        .toList();
  }
}
