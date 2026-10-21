import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/service_category.dart';
import '../../../../core/providers/vendor_provider.dart';
import '../../../../models/chat_message.dart';
import '../../../home/data/models/restaurant.dart';
import '../../../../core/models/vendor.dart';
import '../../data/ai_chat_service.dart';

/// One controller per chat screen on display (the argument is a key the
/// screen creates for itself), auto-disposed with it like the State it
/// replaces: the conversation lives as long as the screen.
final aiChatControllerProvider = NotifierProvider.autoDispose
    .family<AiChatController, AiChatState, Object>(AiChatController.new);

@immutable
class AiChatState {
  const AiChatState({
    this.messages = const [],
    this.isLoading = false,
    this.hasActiveOrder,
    this.selectedImage,
  });

  /// Newest first, as the reversed list shows them.
  final List<ChatMessage> messages;
  final bool isLoading;

  /// null = still checking; true/false = known. The starter chips render
  /// whether this is null or resolved — null just means the "Suivre ma
  /// commande" chip isn't added yet, not that the whole section waits on it;
  /// it slots in the moment the check resolves.
  final bool? hasActiveOrder;

  /// The photo picked to go with the next message.
  final File? selectedImage;
}

class AiChatController extends AutoDisposeFamilyNotifier<AiChatState, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _disposed = false;
  late AiChatService _chatService;

  /// What the model is told of the conversation, oldest first.
  final List<Map<String, dynamic>> _apiHistory = [];

  @override
  AiChatState build(Object screenKey) {
    ref.onDispose(() => _disposed = true);
    _chatService = AiChatService();
    return const AiChatState();
  }

  void _set({
    List<ChatMessage>? messages,
    bool? isLoading,
    ValueGetter<bool?>? hasActiveOrder,
    ValueGetter<File?>? selectedImage,
  }) {
    if (_disposed) return;
    state = AiChatState(
      messages: messages ?? state.messages,
      isLoading: isLoading ?? state.isLoading,
      hasActiveOrder: hasActiveOrder != null ? hasActiveOrder() : state.hasActiveOrder,
      selectedImage: selectedImage != null ? selectedImage() : state.selectedImage,
    );
  }

  // ── Opening the screen ────────────────────────────────────────────────────

  /// Context-aware starter chips: is there an order to track right now?
  Future<void> checkActiveOrder() async {
    final active = await _chatService.hasActiveOrder();
    _set(hasActiveOrder: () => active);
  }

  /// Restores the saved conversation.
  Future<void> loadHistory() async {
    final loaded = await _chatService.loadHistory();
    if (loaded.isEmpty) return;
    // loaded is already newest-first — matches messages directly.
    _set(messages: [...state.messages, ...loaded]);
    if (_disposed) return;
    // _apiHistory needs chronological (oldest-first) order for the LLM.
    _apiHistory.addAll(loaded.reversed.map((m) => {
          'role': m.isUser ? 'user' : 'model',
          'parts': [
            {'text': m.text}
          ],
        }));
  }

  // ── User actions ──────────────────────────────────────────────────────────

  /// Deletes the saved conversation. On success the screen starts empty
  /// again (and the picked photo goes). Returns whether it worked.
  Future<bool> clearHistory() async {
    final ok = await _chatService.clearHistory();
    if (ok) {
      _set(messages: const [], selectedImage: () => null);
      if (!_disposed) _apiHistory.clear();
      // hasActiveOrder is intentionally left as-is: clearing the CONVERSATION
      // has no bearing on whether an order is in flight, so the "Suivre ma
      // commande" chip (if it was showing) still shows on the now-empty state.
    }
    return ok;
  }

  void selectImage(File file) => _set(selectedImage: () => file);

  void removeImage() => _set(selectedImage: () => null);

  /// Whether there is anything to send: some text, or a picture.
  bool canSend(String text) => text.trim().isNotEmpty || state.selectedImage != null;

  /// Sends [text] (and the picked photo): the user's bubble shows at once,
  /// the assistant's answer when it arrives. Call [canSend] first.
  Future<void> send(String text) async {
    final hasText = text.trim().isNotEmpty;
    final imageToSend = state.selectedImage;
    _set(
      messages: [
        ChatMessage(
          text: hasText ? text : '📷 Image envoyée',
          isUser: true,
          imageFile: imageToSend,
        ),
        ...state.messages,
      ],
      selectedImage: () => null,
      isLoading: true,
    );

    final aiResponse = await _chatService.sendMessage(
      text,
      _apiHistory,
      imageFile: imageToSend,
    );

    _set(isLoading: false, messages: [aiResponse, ...state.messages]);
    if (_disposed) return;
    _apiHistory
      ..add({'role': 'user', 'parts': [{'text': hasText ? text : '[Image]'}]})
      ..add({'role': 'model', 'parts': [{'text': aiResponse.text}]});
  }

  /// The shop behind a card, for its page; null when it cannot be found.
  Future<Vendor?> vendorFor(String id) => ref.read(shopRepositoryProvider).getVendor(id);

  // ── Starter suggestions (fresh/empty chat only) ───────────────────────────
  // Deliberately no "Sport" chip — the sport/protein health goal still works
  // perfectly fine when TYPED (Rule 4 in the system prompt is unchanged), this
  // only affects which starter prompts are shown up front.
  static const List<(String emoji, String label, String prompt)> starterSuggestions = [
    ('🥗', 'Manger léger', 'Je veux manger léger, propose-moi quelque chose de sain'),
    ('🌙', 'Repas Iftar', "Je cherche un repas pour l'iftar"),
    ('🌱', 'Végétarien', 'Je suis végétarien, propose-moi des plats'),
    ('✨', 'Découvrir', 'Fais-moi découvrir des plats populaires'),
  ];

  // Prepended (not swapped in) when the user has an order in flight — food
  // discovery is still something they might want, but tracking is very
  // likely the actual reason they opened the chat right now, so it leads.
  // Phrase matches the system prompt's own track_order few-shot example
  // verbatim for reliable intent extraction.
  static const (String, String, String) trackOrderSuggestion =
      ('📦', 'Suivre ma commande', 'Où est ma commande ?');

  List<(String emoji, String label, String prompt)> get effectiveSuggestions =>
      state.hasActiveOrder == true
          ? [trackOrderSuggestion, ...starterSuggestions]
          : starterSuggestions;

  /// The message a category chip sends. Phrased the way a customer would ask,
  /// so it goes through the ordinary intent classification rather than a
  /// special path — a chip is just a shortcut for typing.
  static String starterQueryFor(ServiceType type) {
    switch (type) {
      case ServiceType.foodDelivery:
        return 'Montre-moi les restaurants disponibles';
      case ServiceType.supermarket:
        return 'Montre-moi ce qu\'il y a au supermarché';
      case ServiceType.bakery:
        return 'Montre-moi les pâtisseries disponibles';
      case ServiceType.flowers:
        return 'Montre-moi les fleurs disponibles';
      case ServiceType.pets:
        return 'Montre-moi les produits d\'animalerie';
      case ServiceType.gifts:
        return 'Montre-moi des idées cadeaux';
      case ServiceType.electronics:
        return 'Montre-moi les produits électroniques';
      case ServiceType.courier:
        return 'Je veux envoyer un colis';
      case ServiceType.billPayments:
        return 'Je veux payer une facture';
    }
  }

  /// Builds a minimal Restaurant object from the card's data. The
  /// RestaurantDetailScreen will load the full menu via foodItemsProvider.
  static Restaurant restaurantFor(ProductResult product) => Restaurant(
        id: product.sourceId!,
        name: product.sourceName,
        description: product.description ?? '',
        imageUrl: product.imageUrl ?? '',
        rating: product.rating ?? 0.0,
        reviewCount: 0,
        deliveryTime: product.deliveryTime ?? 30,
        deliveryFee: product.deliveryFee ?? 0.0,
        minimumOrder: 0.0,
        categories: const [],
        isOpen: true,
        latitude: 0,
        longitude: 0,
      );
}
