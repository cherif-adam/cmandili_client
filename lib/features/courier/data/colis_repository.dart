// Bon de prise en charge Colis — côté expéditeur.
//
// La commande n'est plus insérée dans `orders` directement : elle passe par
// create_colis_order, qui écrit la commande ET sa déclaration dans la même
// transaction. Un colis naît en 'ready' et part aussitôt en broadcast aux
// livreurs ; s'il existait sans valeur déclarée ni mode de remise, un livreur
// pourrait l'accepter et se retrouver devant un colis sans rien pour le
// protéger. Soit les deux, soit rien.

import 'package:supabase_flutter/supabase_flutter.dart';

/// Ce qu'un colis ne peut pas contenir. Affiché avant la case à cocher —
/// l'expéditeur confirme en connaissance de cause, pas en aveugle.
const List<(String, String)> kColisForbiddenItems = [
  ('💵', 'Argent liquide'),
  ('💍', 'Bijoux et métaux précieux'),
  ('📄', 'Documents officiels (passeport, CIN, actes)'),
  ('🚫', 'Produits illégaux ou dangereux'),
];

/// Plafond de repli si `platform_settings` est illisible (migration pas encore
/// appliquée, réseau coupé). Le serveur revalide de toute façon : ce nombre ne
/// sert qu'à éviter un formulaire sans limite affichée.
const double kColisFallbackMaxValue = 300;

enum ColisDeliveryMode { code, noCode }

extension ColisDeliveryModeX on ColisDeliveryMode {
  String get slug => this == ColisDeliveryMode.code ? 'code' : 'no_code';
}

class ColisRepository {
  ColisRepository([SupabaseClient? client])
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const _bucket = 'colis-proofs';

  /// Plafond de valeur déclarée, lu en base pour qu'un admin puisse le changer
  /// sans livrer une nouvelle version.
  Future<double> maxDeclaredValue() async {
    try {
      final row = await _supabase
          .from('platform_settings')
          .select('value')
          .eq('key', 'colis_max_declared_value')
          .maybeSingle();
      final v = double.tryParse((row?['value'] ?? '').toString());
      return v != null && v > 0 ? v : kColisFallbackMaxValue;
    } catch (_) {
      return kColisFallbackMaxValue;
    }
  }

  /// Crée la commande et sa déclaration d'un seul tenant. Renvoie l'id.
  ///
  /// Lève une [PostgrestException] dont le message est destiné à
  /// l'utilisateur : les RPC parlent français, y compris le refus de plafond.
  Future<String> createOrder({
    required Map<String, dynamic> pickupAddress,
    required Map<String, dynamic> deliveryAddress,
    required String senderPhone,
    required String recipientPhone,
    required String packageSize,
    required String description,
    required double declaredValue,
    required double deliveryFee,
    String? recipientName,
    ColisDeliveryMode mode = ColisDeliveryMode.code,
    String? receiverLabel,
    String? packagePhotoUrl,
    DateTime? eta,
  }) async {
    final id = await _supabase.rpc('create_colis_order', params: {
      'p_pickup_address': pickupAddress,
      'p_delivery_address': deliveryAddress,
      'p_sender_phone': senderPhone,
      'p_recipient_phone': recipientPhone,
      'p_package_size': packageSize,
      'p_description': description,
      'p_declared_value': declaredValue,
      'p_delivery_fee': deliveryFee,
      'p_recipient_name': recipientName,
      'p_mode': mode.slug,
      'p_receiver_label': receiverLabel,
      'p_package_photo_url': packagePhotoUrl,
      // .toUtc() — même raison que partout ailleurs : stocker une heure locale
      // décale l'estimation d'une heure en Tunisie.
      'p_eta': (eta ?? DateTime.now().add(const Duration(minutes: 45)))
          .toUtc()
          .toIso8601String(),
    });
    return id.toString();
  }

  /// Le reçu, ou null quand la commande n'est pas un colis — ou quand la
  /// migration n'a pas encore été appliquée. Dans les deux cas l'écran de
  /// suivi doit continuer de s'afficher sans la section preuve.
  Future<Map<String, dynamic>?> loadReceipt(String orderId) async {
    try {
      return await _supabase
          .from('colis_receipts')
          .select()
          .eq('order_id', orderId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  /// Le code à 4 chiffres. Lisible par l'expéditeur seul : la table n'a aucune
  /// policy pour le livreur, qui ne peut donc pas le deviner en lisant la base.
  Future<String?> loadDeliveryCode(String orderId) async {
    try {
      final row = await _supabase
          .from('colis_delivery_codes')
          .select('code')
          .eq('order_id', orderId)
          .maybeSingle();
      return row?['code'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// URL signée : le bucket des preuves est privé, getPublicUrl ne donnerait
  /// rien d'affichable.
  Future<String?> signedProofUrl(String path, {int secondsValid = 3600}) async {
    try {
      return await _supabase.storage
          .from(_bucket)
          .createSignedUrl(path, secondsValid);
    } catch (_) {
      return null;
    }
  }

  /// Fenêtre de litige : 24 h après la livraison. Indépendante de
  /// l'auto-confirmation à 3 minutes — une commande auto-confirmée reste
  /// contestable, c'est tout l'intérêt.
  static const Duration kDisputeWindow = Duration(hours: 24);

  static bool canDispute(DateTime? deliveredAt, {DateTime? now}) {
    if (deliveredAt == null) return false;
    final ref = now ?? DateTime.now().toUtc();
    return ref.difference(deliveredAt.toUtc()) < kDisputeWindow;
  }

  Future<void> openDispute({
    required String orderId,
    required String kind,
    String? message,
  }) async {
    await _supabase.rpc('colis_open_dispute', params: {
      'p_order_id': orderId,
      'p_kind': kind,
      'p_message': message,
    });
  }
}
