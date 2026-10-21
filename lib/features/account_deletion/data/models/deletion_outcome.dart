import 'deletion_blocker.dart';

enum DeletionStatus {
  /// Compte supprime : il ne reste qu'a nettoyer l'appareil.
  deleted,

  /// Le serveur a trouve un blocage au dernier moment (une commande arrivee
  /// entre-temps, par exemple). Rien n'a ete modifie.
  blocked,

  /// La re-authentification date de plus de 5 minutes.
  reauthRequired,

  failed,
}

class DeletionOutcome {
  final DeletionStatus status;
  final List<DeletionBlocker> blockers;

  const DeletionOutcome(this.status, [this.blockers = const []]);
}
