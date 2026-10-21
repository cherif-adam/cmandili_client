/// Une raison pour laquelle le compte ne peut pas encore etre supprime.
///
/// Les codes viennent de la fonction SQL account_deletion_blockers ; l'ecran
/// les traduit. Un code inconnu (ajoute cote serveur plus tard) s'affiche
/// avec un message generique plutot que de laisser passer la suppression.
class DeletionBlocker {
  final String code;
  final int? count;
  final num? amount;

  const DeletionBlocker({required this.code, this.count, this.amount});

  static List<DeletionBlocker> listFrom(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => DeletionBlocker(
              code: '${m['code']}',
              count: (m['count'] as num?)?.toInt(),
              amount: m['amount'] as num?,
            ))
        .toList();
  }
}
