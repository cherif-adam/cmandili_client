import 'package:flutter/material.dart';

/// A placeholder that types [phrases] one by one: letter by letter, a pause
/// of [hold], erased, a short gap, then the next phrase, forever.
///
/// One [AnimationController] per phrase, so it stops by itself when the
/// screen is covered by another route or the app is in the background
/// (tickers are muted), and only this Text repaints on each frame.
/// The parent decides when it shows at all: not focused, nothing typed, and
/// animations allowed (reduced motion uses a fixed hint instead).
class TypewriterHint extends StatefulWidget {
  const TypewriterHint({
    super.key,
    required this.phrases,
    required this.style,
    this.typeStep = const Duration(milliseconds: 65),
    this.eraseStep = const Duration(milliseconds: 30),
    this.hold = const Duration(milliseconds: 2500),
    this.gap = const Duration(milliseconds: 400),
  });

  final List<String> phrases;
  final TextStyle? style;
  final Duration typeStep;
  final Duration eraseStep;
  final Duration hold;
  final Duration gap;

  @override
  State<TypewriterHint> createState() => _TypewriterHintState();
}

class _TypewriterHintState extends State<TypewriterHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this)
    ..addStatusListener(_onStatus);
  int _index = 0;

  List<String> get _phrases =>
      widget.phrases.where((p) => p.isNotEmpty).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(TypewriterHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A language change brings new phrases: start over with them.
    if (!_samePhrases(oldWidget.phrases, widget.phrases)) {
      _index = 0;
      _start();
    }
  }

  static bool _samePhrases(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  int get _length {
    final phrases = _phrases;
    if (phrases.isEmpty) return 0;
    return phrases[_index % phrases.length].characters.length;
  }

  Duration get _phraseDuration =>
      widget.typeStep * _length + widget.hold + widget.eraseStep * _length + widget.gap;

  void _start() {
    if (_phrases.isEmpty) return;
    _controller.duration = _phraseDuration;
    _controller.forward(from: 0);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _index++;
    _start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// How many characters show at [elapsed] into the current phrase.
  int _visibleAt(Duration elapsed, int length) {
    final typing = widget.typeStep * length;
    if (elapsed < typing) {
      return (elapsed.inMicroseconds ~/ widget.typeStep.inMicroseconds + 1)
          .clamp(0, length);
    }
    final held = typing + widget.hold;
    if (elapsed < held) return length;
    final erasing = held + widget.eraseStep * length;
    if (elapsed < erasing) {
      final erased =
          (elapsed - held).inMicroseconds ~/ widget.eraseStep.inMicroseconds + 1;
      return (length - erased).clamp(0, length);
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final phrases = _phrases;
    if (phrases.isEmpty) return const SizedBox.shrink();
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final phrase = phrases[_index % phrases.length].characters;
          final total = _controller.duration ?? Duration.zero;
          final elapsed = total * _controller.value;
          final shown = phrase.take(_visibleAt(elapsed, phrase.length));
          return Text(
            shown.toString(),
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          );
        },
      ),
    );
  }
}
