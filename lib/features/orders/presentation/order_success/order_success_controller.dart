/// The order success screen's only logic. It has no state of its own (the
/// animations and the navigation belong to the screen), so this is a plain
/// helper rather than a Riverpod Notifier.
abstract final class OrderSuccessController {
  /// No human-readable order number exists in the schema — fall back to the
  /// last 8 characters of the order UUID as a pragmatic reference.
  static String shortRef(String orderId) {
    final raw = orderId.replaceAll('-', '');
    final tail = raw.length >= 8 ? raw.substring(raw.length - 8) : raw;
    return tail.toUpperCase();
  }
}
