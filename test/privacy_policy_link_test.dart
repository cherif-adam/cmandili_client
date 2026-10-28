import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cmandili_mobile/core/utils/privacy_policy.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

/// The privacy policy must be one tap away in the profile (Google Play), in
/// the three languages, and opening it must never crash the app.
void main() {
  test('the link is the policy given to Google Play', () {
    expect(kPrivacyPolicyUrl, 'https://sites.google.com/view/amana-kairouan-privacy');
  });

  test('the profile shows the link', () {
    final profile = File('lib/features/profile/presentation/profile/profile_screen.dart').readAsStringSync();
    expect(profile.contains('openPrivacyPolicy(context)'), isTrue);
    expect(profile.contains('privacyPolicy'), isTrue);
  });

  for (final locale in ['fr', 'en', 'ar']) {
    testWidgets('$locale: the row reads well, and a failure to open is said', (tester) async {
      final l = await AppLocalizations.delegate.load(Locale(locale));
      expect(l.privacyPolicy.trim(), isNotEmpty);
      await tester.pumpWidget(MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openPrivacyPolicy(context),
              child: Text(l.privacyPolicy),
            ),
          ),
        ),
      ));
      await tester.tap(find.text(l.privacyPolicy));
      // The browser plugin answers on a real platform channel, outside the
      // test's fake clock: let real time pass so its "no plugin" reply lands.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
      // No browser in a widget test: the app must say so, not throw.
      expect(find.text(l.privacyPolicyOpenFailed), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
