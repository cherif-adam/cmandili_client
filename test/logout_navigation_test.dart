import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Why a successful sign-in left the user on the login screen until they
/// restarted the app.
///
/// main.dart swaps MaterialApp.home between the login screen and Home as the
/// session changes, and that swap works. What broke it was Profile > Logout:
/// it did pushAndRemoveUntil(AuthScreen, (route) => false) and never signed
/// out. That removed the root route (the one showing `home`) and left a
/// pushed login screen on top. The next sign-in switched `home` to Home, but
/// nothing displayed it any more.
///
/// The fix: pop back to the root route and really sign out, so the root
/// itself turns into the login screen and later into Home.
void main() {
  Widget app(ValueListenable<bool> signedIn) {
    return ValueListenableBuilder<bool>(
      valueListenable: signedIn,
      builder: (context, value, _) => MaterialApp(
        home: value ? const _Screen('HOME') : const _Screen('AUTH'),
      ),
    );
  }

  testWidgets('BUG: old logout pushes a login screen and never signs out',
      (tester) async {
    final signedIn = ValueNotifier<bool>(true);
    await tester.pumpWidget(app(signedIn));
    expect(find.text('HOME'), findsOneWidget);

    // Old Logout button.
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const _Screen('AUTH')),
      (route) => false,
    );
    await tester.pumpAndSettle();
    expect(find.text('AUTH'), findsOneWidget);

    // The user signs in again (the session never ended, it is renewed).
    signedIn.value = false;
    signedIn.value = true;
    await tester.pumpAndSettle();

    expect(find.text('AUTH'), findsOneWidget,
        reason: 'the pushed login screen is still what is shown');
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('FIX: pop to root and sign out, then sign-in shows Home',
      (tester) async {
    final signedIn = ValueNotifier<bool>(true);
    await tester.pumpWidget(app(signedIn));

    // New Logout button: popUntil(isFirst) + signOut().
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .popUntil((route) => route.isFirst);
    signedIn.value = false;
    await tester.pumpAndSettle();
    expect(find.text('AUTH'), findsOneWidget);

    // Sign in.
    signedIn.value = true;
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('AUTH'), findsNothing);
  });
}

class _Screen extends StatelessWidget {
  final String label;
  const _Screen(this.label);

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(label));
}
