// Edge-to-edge (2026-11-07): the floating menu bar, the active-order pill and
// the AI assistant button sit above the Android system navigation bar, with
// 3-button navigation (48 dp) and gesture navigation (~20 dp) alike; lists
// leave room for all of it; the system bars are transparent, without the grey
// contrast scrim.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cmandili_mobile/core/theme/app_system_bars.dart';
import 'package:cmandili_mobile/core/widgets/bottom_reserve.dart';
import 'package:cmandili_mobile/features/ai_onboarding/presentation/ai_onboarding_controller.dart';
import 'package:cmandili_mobile/features/home/presentation/home/home_controller.dart';

void main() {
  group('HomeBottomLayout', () {
    const navHeight = 72.0;

    for (final (name, system) in [('3-button', 48.0), ('gesture', 20.0), ('none', 0.0)]) {
      test('$name navigation: everything stacks above the system bar', () {
        final layout = HomeBottomLayout(
            systemBottom: system, navHeight: navHeight, pillShowing: false);
        expect(layout.navBottom, system + 10, reason: 'menu bar 10 dp above the system bar');
        expect(layout.navTop, system + 10 + navHeight);
        expect(layout.pillBottom, greaterThan(layout.navTop), reason: 'pill above the menu bar');
        // The Scaffold puts its button at system bar + 16: the lift brings it
        // onto the pill's row, above the menu bar.
        expect(system + kFloatingActionButtonMargin + layout.fabLift, layout.pillBottom);
        expect(layout.contentBottom, greaterThan(layout.navTop),
            reason: 'the last item of a list clears the menu bar');
      });
    }

    test('lists leave room for the pill too while it shows', () {
      const without = HomeBottomLayout(systemBottom: 48, navHeight: navHeight, pillShowing: false);
      const withPill = HomeBottomLayout(systemBottom: 48, navHeight: navHeight, pillShowing: true);
      expect(withPill.contentBottom - without.contentBottom,
          HomeBottomLayout.pillHeight + HomeBottomLayout.stackGap);
    });

    test('the cart panel, already in a SafeArea, does not count the system bar twice', () {
      const layout = HomeBottomLayout(systemBottom: 48, navHeight: navHeight, pillShowing: true);
      expect(layout.floatingRoom, layout.contentBottom - 48);
    });
  });

  group('assistant button vs active-order pill', () {
    ProviderContainer container({required bool pill}) {
      final c = ProviderContainer(overrides: [
        activeOrderPillShowingProvider.overrideWith((ref) => pill),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

    test('extended at the top of the list when no order is in progress', () {
      final c = container(pill: false);
      expect(c.read(aiFabExtendedProvider), isTrue);
    });

    test('round while the pill shows: they share a row', () {
      final c = container(pill: true);
      expect(c.read(aiFabExtendedProvider), isFalse);
    });

    test('round when scrolled down, whatever the pill', () {
      final c = container(pill: false);
      c.read(aiOnboardingControllerProvider.notifier).onHomeScrolled(offset: 300, delta: 20);
      expect(c.read(aiFabExtendedProvider), isFalse);
    });
  });

  group('BottomReserve', () {
    Future<double> reserveIn(WidgetTester tester, {required Widget Function(Widget) wrap}) async {
      late double value;
      await tester.pumpWidget(wrap(Builder(builder: (context) {
        value = BottomReserve.of(context);
        return const SizedBox();
      })));
      return value;
    }

    testWidgets('a home tab gets the home layout room', (tester) async {
      final value = await reserveIn(tester,
          wrap: (child) => BottomReserve(bottom: 166, child: child));
      expect(value, 166);
    });

    testWidgets('a screen on its own clears the system bar', (tester) async {
      final value = await reserveIn(tester,
          wrap: (child) => MediaQuery(
                data: const MediaQueryData(padding: EdgeInsets.only(bottom: 48)),
                child: child,
              ));
      expect(value, 48 + 16);
    });
  });

  group('system bars', () {
    test('transparent bars, no contrast scrim, both styles', () {
      for (final style in [AppSystemBars.onLight, AppSystemBars.onDark]) {
        expect(style.systemNavigationBarColor, Colors.transparent);
        expect(style.statusBarColor, Colors.transparent);
        expect(style.systemNavigationBarContrastEnforced, isFalse);
        expect(style.systemStatusBarContrastEnforced, isFalse);
      }
    });

    test('dark icons on light screens, light icons on dark/orange ones', () {
      expect(AppSystemBars.onLight.systemNavigationBarIconBrightness, Brightness.dark);
      expect(AppSystemBars.onLight.statusBarIconBrightness, Brightness.dark);
      expect(AppSystemBars.onDark.systemNavigationBarIconBrightness, Brightness.light);
      expect(AppSystemBars.onDark.statusBarIconBrightness, Brightness.light);
      expect(AppSystemBars.forBackground(Brightness.dark), AppSystemBars.onDark);
      expect(AppSystemBars.forBackground(Brightness.light), AppSystemBars.onLight);
    });

    test('the Android launch theme matches from the first frame', () async {
      // Read as text: transparent bars and no contrast scrim in both modes.
      for (final path in [
        'android/app/src/main/res/values/styles.xml',
        'android/app/src/main/res/values-night/styles.xml',
      ]) {
        final xml = await _read(path);
        expect('android:navigationBarColor">@android:color/transparent'.allMatches(xml).length, 2,
            reason: '$path: LaunchTheme and NormalTheme');
        expect('android:enforceNavigationBarContrast" tools:targetApi="29">false'.allMatches(xml).length, 2,
            reason: path);
      }
    });
  });
}

/// Tests run from the package root.
Future<String> _read(String path) => File(path).readAsString();
