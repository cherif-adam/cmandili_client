// lib/screens/ai_chat_screen.dart
//
// Cmandili AI Chat — Full Feature Set
// ✅ Orange Brand Theme
// ✅ Task 1: Keyboard overflow fix (resizeToAvoidBottomInset + scrollable)
// ✅ Task 2: Clickable food cards → RestaurantDetailScreen
// ✅ Task 3: Voice input (Android native speech via MethodChannel)
// ✅ Task 4: Image upload & Vision (image_picker + base64 to Gemini)
//
// Layout, top to bottom: ChatAppBar, ChatCategoryBar, ChatListeningBanner
// (while listening), ChatImagePreviewStrip (photo picked), the messages
// (ChatMessageBubble / ChatTypingIndicator) or ChatEmptyState, ChatSendBar.
// Every widget lives in lib/screens/ai_chat/widgets/.

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

// Import your actual screens/models here:
import '../models/chat_message.dart';
import '../services/ai_chat_service.dart';
import '../features/restaurant/presentation/restaurant_detail_screen.dart';
import '../features/home/data/models/restaurant.dart';
import '../core/data/vendor_repository.dart';
import '../core/models/service_category.dart';
import '../features/vendors/presentation/vendor_detail_screen.dart';
import '../features/courier/presentation/courier_screen.dart';
import '../features/facture/presentation/facture_screen.dart';
import 'ai_chat/chat_palette.dart';
import 'ai_chat/widgets/chat_app_bar.dart';
import 'ai_chat/widgets/chat_category_bar.dart';
import 'ai_chat/widgets/chat_delivery_card.dart';
import 'ai_chat/widgets/chat_empty_state.dart';
import 'ai_chat/widgets/chat_facture_card.dart';
import 'ai_chat/widgets/chat_food_card.dart';
import 'ai_chat/widgets/chat_image_preview_strip.dart';
import 'ai_chat/widgets/chat_listening_banner.dart';
import 'ai_chat/widgets/chat_message_bubble.dart';
import 'ai_chat/widgets/chat_restaurant_card.dart';
import 'ai_chat/widgets/chat_send_bar.dart';
import 'ai_chat/widgets/chat_shop_card.dart';
import 'ai_chat/widgets/chat_typing_indicator.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

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

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController   = ScrollController();
  final List<ChatMessage> _messages          = [];
  final AiChatService _chatService           = AiChatService();
  bool _isLoading = false;
  final List<Map<String, dynamic>> _apiHistory = [];

  // null = still checking; true/false = known. Empty-state chips render
  // (see build()) whether this is null or resolved — null just means the
  // "Suivre ma commande" chip isn't added yet, not that the whole section
  // waits on it; it slots in the moment the check resolves.
  bool? _hasActiveOrder;

  // ── Task 3: Voice — native Android speech via MethodChannel ───────────────
  // Uses Android's built-in SpeechRecognizer (no external package needed).
  // MethodChannel defined in MainActivity.kt (see comment below).
  static const _speechChannel = MethodChannel('com.amana.mobile/speech');
  bool _isListening = false;
  late AnimationController _micPulseController;

  // ── Task 4: Image picker ───────────────────────────────────────────────────
  final ImagePicker _imagePicker   = ImagePicker();
  File? _selectedImage;

  // Typing dots animation
  late AnimationController _typingController;

  @override
  void initState() {
    super.initState();

    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Set up speech result listener from native side
    _speechChannel.setMethodCallHandler((call) async {
      if (call.method == 'onSpeechResult') {
        final text = call.arguments as String? ?? '';
        setState(() {
          _textController.text = text;
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: text.length),
          );
          _isListening = false;
        });
      } else if (call.method == 'onSpeechEnd') {
        setState(() => _isListening = false);
      }
    });

    _loadHistory();
    _checkActiveOrder();
  }

  // ── Context-aware starter chips: is there an order to track right now? ────

  Future<void> _checkActiveOrder() async {
    final active = await _chatService.hasActiveOrder();
    if (!mounted) return;
    setState(() => _hasActiveOrder = active);
  }

  // ── Restore saved conversation on open ─────────────────────────────────────

  Future<void> _loadHistory() async {
    final loaded = await _chatService.loadHistory();
    if (!mounted || loaded.isEmpty) return;
    setState(() {
      // loaded is already newest-first — matches _messages directly.
      _messages.addAll(loaded);
      // _apiHistory needs chronological (oldest-first) order for the LLM.
      _apiHistory.addAll(loaded.reversed.map((m) => {
            'role': m.isUser ? 'user' : 'model',
            'parts': [
              {'text': m.text}
            ],
          }));
    });
  }

  // ── Clear conversation (app bar button) ────────────────────────────────────

  Future<void> _confirmClearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Effacer la conversation ?'),
        content: const Text(
          "Tout l'historique de cette conversation sera supprimé définitivement. Cette action est irréversible.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Effacer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await _chatService.clearHistory();
    if (!mounted) return;

    if (ok) {
      setState(() {
        _messages.clear();
        _apiHistory.clear();
        _selectedImage = null;
      });
      // _hasActiveOrder is intentionally left as-is: clearing the CONVERSATION
      // has no bearing on whether an order is in flight, so the "Suivre ma
      // commande" chip (if it was showing) still shows on the now-empty state.
      _showSnack('Conversation effacée');
    } else {
      _showSnack("Impossible d'effacer la conversation, réessayez", isError: true);
    }
  }

  // ── Task 3: Toggle voice via native Android speech ────────────────────────

  /// Maps the device locale tag to a speech-recognition locale accepted by
  /// Android's SpeechRecognizer. Falls back to fr-FR (app default).
  String _speechLocale() {
    final tag = ui.PlatformDispatcher.instance.locale.toLanguageTag();
    if (tag.startsWith('en')) return 'en-US';
    if (tag.startsWith('ar')) return 'ar-TN';
    return 'fr-FR';
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      try {
        await _speechChannel.invokeMethod('stopListening');
      } catch (_) {}
      setState(() => _isListening = false);
      return;
    }

    // Android 6+ requires runtime RECORD_AUDIO permission before SpeechRecognizer
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _showSnack(
        status.isPermanentlyDenied
            ? 'Permission micro refusée — activez-la dans les Paramètres'
            : 'Permission microphone requise pour la saisie vocale',
        isError: true,
      );
      return;
    }

    setState(() => _isListening = true);
    try {
      await _speechChannel.invokeMethod('startListening', {'locale': _speechLocale()});
    } on PlatformException catch (e) {
      setState(() => _isListening = false);
      _showSnack('Microphone non disponible: ${e.message}', isError: true);
    } on MissingPluginException {
      setState(() => _isListening = false);
      _showSnack('🎙️ Parlez puis tapez votre message manuellement', isError: false);
    }
  }

  // ── Task 4: Image picker ───────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    Navigator.of(context).pop(); // close bottom sheet
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked != null) {
        setState(() => _selectedImage = File(picked.path));
      }
    } catch (e) {
      _showSnack('Impossible d\'accéder à la galerie', isError: true);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kChatOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: kChatOrange),
              ),
              title: const Text('Prendre une photo',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => _pickImage(ImageSource.camera),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kChatOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library_rounded, color: kChatOrange),
              ),
              title: const Text('Choisir depuis la galerie',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Send message ───────────────────────────────────────────────────────────

  Future<void> _handleSubmitted(String text) async {
    final hasText  = text.trim().isNotEmpty;
    final hasImage = _selectedImage != null;
    if (!hasText && !hasImage) return;

    final imageToSend = _selectedImage;
    _textController.clear();
    setState(() {
      _messages.insert(
        0,
        ChatMessage(
          text: hasText ? text : '📷 Image envoyée',
          isUser: true,
          imageFile: imageToSend,
        ),
      );
      _selectedImage = null;
      _isLoading = true;
    });

    final aiResponse = await _chatService.sendMessage(
      text,
      _apiHistory,
      imageFile: imageToSend,
    );

    setState(() {
      _isLoading = false;
      _messages.insert(0, aiResponse);
      _apiHistory
        ..add({'role': 'user', 'parts': [{'text': hasText ? text : '[Image]'}]})
        ..add({'role': 'model', 'parts': [{'text': aiResponse.text}]});
    });
  }

  // ── Starter suggestions (fresh/empty chat only) ────────────────────────────
  // Deliberately no "Sport" chip — the sport/protein health goal still works
  // perfectly fine when TYPED (Rule 4 in the system prompt is unchanged), this
  // only affects which starter prompts are shown up front.
  static const List<(String emoji, String label, String prompt)> _starterSuggestions = [
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
  static const (String, String, String) _trackOrderSuggestion =
      ('📦', 'Suivre ma commande', 'Où est ma commande ?');

  List<(String emoji, String label, String prompt)> get _effectiveSuggestions =>
      _hasActiveOrder == true
          ? [_trackOrderSuggestion, ..._starterSuggestions]
          : _starterSuggestions;

  void _sendSuggestion(String prompt) => _handleSubmitted(prompt);

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade600 : kChatOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _typingController.dispose();
    _micPulseController.dispose();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── Task 1: Keyboard overflow fix ──────────────────────────────────────
      resizeToAvoidBottomInset: true,
      backgroundColor: kChatBg,
      appBar: ChatAppBar(
        statusBarHeight: MediaQuery.of(context).padding.top,
        isTyping: _isLoading,
        onClear: _confirmClearChat,
      ),
      body: Column(
        children: [
          // ── Category bar ──────────────────────────────────────────────────
          // All 9 services live here, NOT in the header: the header row is
          // already at its width limit (see the overflow fix in ChatAppBar),
          // so adding chips up there would bring the overflow straight back.
          // A horizontal scroller has no width ceiling.
          ChatCategoryBar(
            onCategoryTap: (type) =>
                _sendSuggestion(AiChatScreen.starterQueryFor(type)),
          ),

          // ── Listening banner ─────────────────────────────────────────────
          if (_isListening) ChatListeningBanner(controller: _micPulseController),

          // ── Image preview strip ───────────────────────────────────────────
          if (_selectedImage != null) ChatImagePreviewStrip(
            file: _selectedImage!,
            onRemove: () => setState(() => _selectedImage = null),
          ),

          // ── Messages list (or starter suggestions on a fresh chat) ────────
          Expanded(
            child: _messages.isEmpty && !_isLoading
                ? ChatEmptyState(
                    suggestions: _effectiveSuggestions,
                    onSuggestion: _sendSuggestion,
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    // ── Task 1: keyboard avoidance via Scaffold is automatic ──
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isLoading && index == 0) {
                        return ChatTypingIndicator(controller: _typingController);
                      }
                      final msgIndex = _isLoading ? index - 1 : index;
                      return ChatMessageBubble(
                        message: _messages[msgIndex],
                        cardBuilder: _buildCard,
                      );
                    },
                  ),
          ),

          // ── Input bar ─────────────────────────────────────────────────────
          ChatSendBar(
            controller: _textController,
            isListening: _isListening,
            micPulseController: _micPulseController,
            bottomViewPadding: MediaQuery.of(context).viewPadding.bottom,
            onImageTap: _showImageSourceSheet,
            onMicTap: _toggleListening,
            onSubmitted: _handleSubmitted,
          ),
        ],
      ),
    );
  }

  // ─── Product cards ────────────────────────────────────────────────────────

  Widget _buildCard(ProductResult product) {
    switch (product.type) {
      case 'delivery':   return ChatDeliveryCard(product: product, onTap: _openCourier);
      case 'facture':    return ChatFactureCard(product: product, onTap: _openFacture);
      case 'shop':       return ChatShopCard(product: product, onTap: () => _navigateToVendor(product));
      case 'restaurant': return ChatRestaurantCard(product: product, onTap: () => _navigateToRestaurant(product));
      default:           return ChatFoodCard(product: product, onTap: () => _navigateToRestaurant(product));
    }
  }

  // ── Navigate to a shop (any of the 7 catalogues) ──────────────────────────
  // The card only carries the vendor id, so the full row is fetched before
  // pushing — VendorDetailScreen needs a real Vendor, and it is the same
  // screen (and the same cart) the home screen uses for that category.

  Future<void> _navigateToVendor(ProductResult product) async {
    final id = product.sourceId;
    if (id == null || id.isEmpty) {
      _showSnack('Boutique introuvable');
      return;
    }
    final vendor = await VendorRepository().getVendor(id);
    if (!mounted) return;
    if (vendor == null) {
      _showSnack('Boutique introuvable');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VendorDetailScreen(vendor: vendor)),
    );
  }

  void _openCourier() {
    final size = MediaQuery.sizeOf(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourierScreen(
          screenWidth: size.width,
          screenHeight: size.height,
        ),
      ),
    );
  }

  void _openFacture() {
    final size = MediaQuery.sizeOf(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FactureScreen(
          screenWidth: size.width,
          screenHeight: size.height,
        ),
      ),
    );
  }

  // ── Task 2: Navigate to RestaurantDetailScreen ────────────────────────────

  void _navigateToRestaurant(ProductResult product) {
    // Build a minimal Restaurant object from the ProductResult data.
    // The RestaurantDetailScreen will load the full menu via foodItemsProvider.
    if (product.sourceId == null || product.sourceId!.isEmpty) {
      _showSnack('Restaurant introuvable');
      return;
    }

    final restaurant = Restaurant(
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
      ),
    );
  }
}
