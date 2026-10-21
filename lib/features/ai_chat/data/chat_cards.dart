import '../../../core/utils/delivery_fee.dart';
import '../../../models/chat_message.dart';

/// The two fixed cards: send a parcel, pay a bill.
class ChatCards {
  ChatCards._();

  // ── Delivery P2P card ─────────────────────────────────────────────────────

  static ProductResult delivery() => ProductResult(
        type: 'delivery',
        id: 'p2p_delivery',
        name: 'Livraison P2P',
        description:
            'Envoyez vos colis à vos proches via nos livreurs. Suivi en temps réel !',
        price: 0.0,
        currency: 'TND',
        imageUrl: null,
        sourceName: 'Amana Courier',
        rating: null,
      );

  // ── Facture card ──────────────────────────────────────────────────────────
  // Opens the Facture flow. The fee is read from kFlatDeliveryFee — the same
  // constant facture_screen.dart uses — rather than retyped, so the figure
  // the assistant quotes cannot drift from the one the user is charged. It is
  // existing fee logic, not a price this assistant invents.

  static ProductResult facture() => ProductResult(
        type: 'facture',
        id: 'facture_payment',
        name: 'Payer une facture',
        description:
            'STEG, SONEDE, Topnet… un livreur collecte le montant et paie '
            'pour vous. Frais de service : '
            '${kFlatDeliveryFee.toStringAsFixed(3)} TND.',
        price: 0.0,
        currency: 'TND',
        imageUrl: null,
        sourceName: 'Amana Facture',
        rating: null,
      );
}
