import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que la porte d'authentification NE fait PAS.
///
/// On a soupconne `MaterialApp.home` deux fois, dans deux sessions
/// differentes : « le Navigator ne consulte `home` qu'une fois, changer ce
/// widget ensuite ne remplace pas la route deja construite ». C'est FAUX, et
/// ce test existe pour que personne ne reparte sur cette piste.
///
/// Echanger `MaterialApp.home` met bien l'ecran a jour. La vraie cause du
/// symptome « connecte mais toujours sur l'ecran de connexion » etait
/// ailleurs : la deconnexion empilait un AuthScreen PAR-DESSUS la route
/// racine et la supprimait. Voir test/logout_navigation_test.dart.
void main() {
  testWidgets('changer MaterialApp.home met bien l ecran a jour',
      (tester) async {
    final signedIn = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: signedIn,
        builder: (context, value, _) => MaterialApp(
          home: value ? const Text('HOME') : const Text('AUTH'),
        ),
      ),
    );
    expect(find.text('AUTH'), findsOneWidget);

    signedIn.value = true; // la connexion reussit
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget,
        reason: 'la route initiale SUIT bien le changement de home');
    expect(find.text('AUTH'), findsNothing);
  });
}
