import 'package:flutter/foundation.dart';

/// Identifie le binaire qui tourne reellement sur l'appareil.
///
/// Sans cette etiquette, rien ne distingue un telephone qui execute le
/// correctif qu'on vient de pousser d'un telephone reste sur une vieille
/// installation : les deux ecrans sont identiques. On a perdu des heures a
/// chercher un bug dans du code que l'appareil n'executait pas.
///
/// Les valeurs sont injectees a la compilation, par exemple :
///
///   flutter run --dart-define=BUILD_COMMIT=$(git rev-parse --short HEAD)
///               --dart-define=BUILD_TIME="$(date '+%Y-%m-%d %H:%M')"
///
/// Sans elles, l'etiquette affiche « local ».
class BuildInfo {
  const BuildInfo._();

  static const String commit =
      String.fromEnvironment('BUILD_COMMIT', defaultValue: '');
  static const String builtAt =
      String.fromEnvironment('BUILD_TIME', defaultValue: '');

  /// `null` hors mode debug : cette etiquette ne doit jamais atteindre un
  /// utilisateur final.
  static String? get label {
    if (!kDebugMode) return null;
    final c = commit.isEmpty ? 'local' : commit;
    return builtAt.isEmpty ? 'build $c' : 'build $c - $builtAt';
  }
}
