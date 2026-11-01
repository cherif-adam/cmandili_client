// The searched dish on a shop's page: brought into view and lit a moment
// (DishSpotlight). The list is lazy, so a dish far down is not even built
// until the spotlight scrolls near it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cmandili_mobile/core/widgets/dish_spotlight.dart';

/// A lazy menu of 60 dishes, 100 px each, like a long restaurant page.
class _Menu extends StatefulWidget {
  const _Menu({required this.spotlight, required this.scroll});

  final DishSpotlight spotlight;
  final ScrollController scroll;

  @override
  State<_Menu> createState() => _MenuState();
}

class _MenuState extends State<_Menu> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.spotlight.reveal(widget.scroll));
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: widget.scroll,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => widget.spotlight.frame(
              'dish-$i',
              SizedBox(height: 100, child: Text('Dish $i')),
            ),
            childCount: 60,
          ),
        ),
      ],
    );
  }
}

Future<ScrollController> _pumpMenu(WidgetTester tester, DishSpotlight spotlight) async {
  final scroll = ScrollController();
  addTearDown(scroll.dispose);
  addTearDown(spotlight.dispose);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: _Menu(spotlight: spotlight, scroll: scroll))));
  return scroll;
}

/// Frames until the dish glows (or a generous bound).
Future<void> _pumpUntilLit(WidgetTester tester, DishSpotlight spotlight) async {
  for (var i = 0; i < 40 && !spotlight.lit.value; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('a dish far down the menu is scrolled into view and glows, then stops', (tester) async {
    final spotlight = DishSpotlight('dish-50');
    await _pumpMenu(tester, spotlight);
    expect(find.text('Dish 50'), findsNothing, reason: 'not built yet: the list is lazy');

    await _pumpUntilLit(tester, spotlight);
    expect(spotlight.lit.value, isTrue);
    expect(find.text('Dish 50').hitTestable(), findsOneWidget, reason: 'on screen');
    // Only the searched dish has the frame.
    expect(find.byType(SpotlightFrame), findsOneWidget);
    expect(
      find.ancestor(of: find.text('Dish 50'), matching: find.byType(SpotlightFrame)),
      findsOneWidget,
    );

    await tester.pump(DishSpotlight.glow);
    await tester.pump(const Duration(milliseconds: 400));
    expect(spotlight.lit.value, isFalse);
  });

  testWidgets('a dish that is not on the page: nothing glows and the list goes back to the top',
      (tester) async {
    final spotlight = DishSpotlight('sold-out');
    final scroll = await _pumpMenu(tester, spotlight);

    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(SpotlightFrame), findsNothing);
    expect(spotlight.lit.value, isFalse);
    expect(scroll.offset, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a page opened normally (no dish) does not move', (tester) async {
    final spotlight = DishSpotlight(null);
    final scroll = await _pumpMenu(tester, spotlight);
    await tester.pump(const Duration(milliseconds: 500));
    expect(scroll.offset, 0);
    expect(find.byType(SpotlightFrame), findsNothing);
  });
}
