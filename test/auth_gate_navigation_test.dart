import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pourquoi une connexion reussie laissait l'utilisateur sur l'ecran de
/// connexion, MEME une fois le flux d'authentification repare.
///
/// `MaterialApp.home` n'est pas une fenetre reactive : c'est la recette de la
/// route initiale. Le `Navigator` la construit UNE fois. Lui donner un autre
/// widget plus tard ne remplace pas ce que la route affiche deja.
///
/// Le premier test fige le comportement FAUTIF (celui de l'app), le second
/// montre la forme qui marche : un `home` constant, et tout le branchement
/// a l'interieur.
void main() {
  Widget buggy(ValueListenable<bool> signedIn) {
    return ValueListenableBuilder<bool>(
      valueListenable: signedIn,
      builder: (context, value, _) => MaterialApp(
        home: value ? const Text('HOME') : const Text('AUTH'),
      ),
    );
  }

  Widget fixed(ValueListenable<bool> signedIn) {
    return MaterialApp(
      home: ValueListenableBuilder<bool>(
        valueListenable: signedIn,
        builder: (context, value, _) =>
            value ? const Text('HOME') : const Text('AUTH'),
      ),
    );
  }

  testWidgets('FAUTIF: changer MaterialApp.home ne change pas l ecran affiche',
      (tester) async {
    final signedIn = ValueNotifier<bool>(false);
    await tester.pumpWidget(buggy(signedIn));
    expect(find.text('AUTH'), findsOneWidget);

    signedIn.value = true; // la connexion reussit
    await tester.pumpAndSettle();

    expect(find.text('AUTH'), findsOneWidget,
        reason: 'l ecran de connexion reste affiche');
    expect(find.text('HOME'), findsNothing,
        reason: 'la route initiale ne se reconstruit pas');
  });

  testWidgets('CORRIGE: un home constant, branchement a l interieur',
      (tester) async {
    final signedIn = ValueNotifier<bool>(false);
    await tester.pumpWidget(fixed(signedIn));
    expect(find.text('AUTH'), findsOneWidget);

    signedIn.value = true;
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('AUTH'), findsNothing);
  });
}
