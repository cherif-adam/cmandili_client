import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/deletion_blocker.dart';
import 'models/deletion_outcome.dart';

/// Suppression du compte client.
///
/// Rien n'est supprime depuis l'app : la verification des blocages, la
/// suppression des donnees personnelles et l'anonymisation du profil se
/// font cote serveur (fonction SQL + Edge Function delete-account, avec la
/// cle service_role). L'app ne fait que demander.
class AccountDeletionRepository {
  AccountDeletionRepository(this._supabase);

  final SupabaseClient _supabase;

  /// Le mot attendu par le serveur, quelle que soit la langue de l'ecran :
  /// l'utilisateur tape le mot de sa langue, l'app envoie celui-ci.
  static const _serverConfirmWord = 'SUPPRIMER';
  static const _app = 'client';

  /// Ce qui empeche aujourd'hui la suppression. Liste vide : rien ne bloque.
  Future<List<DeletionBlocker>> fetchBlockers() async {
    final res = await _supabase.rpc('account_deletion_check');
    return DeletionBlocker.listFrom(res is Map ? res['blockers'] : null);
  }

  /// A appeler juste apres une re-authentification reussie.
  Future<DeletionOutcome> deleteAccount() async {
    try {
      final res = await _supabase.functions.invoke(
        'delete-account',
        body: {'confirm': _serverConfirmWord, 'app': _app},
      );
      final data = res.data;
      if (data is Map && data['status'] == 'deleted') {
        return const DeletionOutcome(DeletionStatus.deleted);
      }
      return const DeletionOutcome(DeletionStatus.failed);
    } on FunctionException catch (e) {
      final details = e.details;
      if (e.status == 409 && details is Map) {
        return DeletionOutcome(
          DeletionStatus.blocked,
          DeletionBlocker.listFrom(details['blockers']),
        );
      }
      if (e.status == 403) {
        return const DeletionOutcome(DeletionStatus.reauthRequired);
      }
      debugPrint('deleteAccount: ${e.status} ${e.details}');
      return const DeletionOutcome(DeletionStatus.failed);
    } catch (e) {
      debugPrint('deleteAccount: $e');
      return const DeletionOutcome(DeletionStatus.failed);
    }
  }
}
