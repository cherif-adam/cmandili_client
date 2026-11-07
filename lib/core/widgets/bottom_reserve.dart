import 'package:flutter/widgets.dart';

/// How much room, from the bottom edge of the screen, a scrolling screen
/// must leave free after its last item: the system navigation bar plus
/// whatever floats above it (the home screen's menu bar and active-order
/// pill).
///
/// The home screen provides it to its tabs. A screen opened on its own
/// (no [BottomReserve] above it) gets the system bar plus a small margin,
/// so the last item is never under the system bar either way.
class BottomReserve extends InheritedWidget {
  const BottomReserve({super.key, required this.bottom, required super.child});

  /// From the bottom edge of the screen, system bar included.
  final double bottom;

  /// Room after the last item of a list on this screen.
  static double of(BuildContext context) {
    final reserve = context.dependOnInheritedWidgetOfExactType<BottomReserve>();
    return reserve?.bottom ?? MediaQuery.paddingOf(context).bottom + 16;
  }

  @override
  bool updateShouldNotify(BottomReserve oldWidget) => oldWidget.bottom != bottom;
}
