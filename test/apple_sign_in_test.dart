import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import 'package:cmandili_mobile/features/auth/presentation/auth/auth_screen.dart';

/// Apple rejects an iPhone app that offers Google sign-in without Sign in
/// with Apple (App Store guideline 4.8). The login screen shows the Apple
/// button on iPhone, first and the same size as Google, and only there:
/// Android would need a web flow the app does not have.
Future<void> pumpAuth(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AuthScreen(),
    ),
  ));
  // No pumpAndSettle: the background animation repeats forever.
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
      debug: false,
    );
  });

  testWidgets('iPhone: Apple button, before Google and as large',
      (tester) async {
    await pumpAuth(tester);
    final apple = find.byKey(const Key('auth_apple'));
    final google = find.byKey(const Key('auth_google'));
    expect(apple, findsOneWidget);
    expect(google, findsOneWidget);
    expect(tester.getCenter(apple).dx, lessThan(tester.getCenter(google).dx));
    expect(tester.getSize(apple), tester.getSize(google));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android: Google only', (tester) async {
    await pumpAuth(tester);
    expect(find.byKey(const Key('auth_apple')), findsNothing);
    expect(find.byKey(const Key('auth_google')), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  test('the iOS app is entitled to Sign in with Apple', () {
    // Without it the Apple sheet fails at once (error 1000) on the phone.
    final entitlements =
        File('ios/Runner/Runner.entitlements').readAsStringSync();
    expect(entitlements, contains('com.apple.developer.applesignin'));
    final project =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(project, contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements'));
  });
}
