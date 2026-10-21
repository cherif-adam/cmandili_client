// lib/features/ai_chat/presentation/ai_chat/ai_chat_screen.dart
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
// Every widget lives in widgets/. UI only: the conversation, sending and the
// starter prompts live in [AiChatController]; this screen keeps the text
// field, the animations, the microphone channel, the photo picker, the
// messages and the navigation.

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../models/chat_message.dart';
import '../../../restaurant/presentation/restaurant_detail/restaurant_detail_screen.dart';
import '../../../../core/models/service_category.dart';
import '../../../vendors/presentation/vendor_detail/vendor_detail_screen.dart';
import '../../../courier/presentation/courier/courier_screen.dart';
import '../../../facture/presentation/facture/facture_screen.dart';
import 'ai_chat_controller.dart';
import 'chat_palette.dart';
import 'widgets/chat_app_bar.dart';
import 'widgets/chat_category_bar.dart';
import 'widgets/chat_delivery_card.dart';
import 'widgets/chat_empty_state.dart';
import 'widgets/chat_facture_card.dart';
import 'widgets/chat_food_card.dart';
import 'widgets/chat_image_preview_strip.dart';
import 'widgets/chat_image_source_sheet.dart';
import 'widgets/chat_listening_banner.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/chat_restaurant_card.dart';
import 'widgets/chat_send_bar.dart';
import 'widgets/chat_shop_card.dart';
import 'widgets/chat_typing_indicator.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  /// The message a category chip sends (see [AiChatController.starterQueryFor]).
  static String starterQueryFor(ServiceType type) =>
      AiChatController.starterQueryFor(type);

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen>
    with TickerProviderStateMixin {
  /// This screen's own controller (see [aiChatControllerProvider]).
  late final _provider = aiChatControllerProvider(Object());

  AiChatController get _controller => ref.read(_provider.notifier);

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController   = ScrollController();

  // ── Task 3: Voice — native Android speech via MethodChannel ───────────────
  // Uses Android's built-in SpeechRecognizer (no external package needed).
  // MethodChannel defined in MainActivity.kt (see comment below).
  static const _speechChannel = MethodChannel('com.amana.mobile/speech');
  bool _isListening = false;
  late AnimationController _micPulseController;

  // ── Task 4: Image picker ───────────────────────────────────────────────────
  final ImagePicker _imagePicker   = ImagePicker();

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

    _controller.loadHistory();
    _controller.checkActiveOrder();
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

    final ok = await _controller.clearHistory();
    if (!mounted) return;

    if (ok) {
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
        _controller.selectImage(File(picked.path));
      }
    } catch (e) {
      _showSnack('Impossible d\'accéder à la galerie', isError: true);
    }
  }

  // ── Send message ───────────────────────────────────────────────────────────

  Future<void> _handleSubmitted(String text) async {
    if (!_controller.canSend(text)) return;
    _textController.clear();
    await _controller.send(text);
  }

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
    final s = ref.watch(_provider);
    return Scaffold(
      // ── Task 1: Keyboard overflow fix ──────────────────────────────────────
      resizeToAvoidBottomInset: true,
      backgroundColor: kChatBg,
      appBar: ChatAppBar(
        statusBarHeight: MediaQuery.of(context).padding.top,
        isTyping: s.isLoading,
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
          if (s.selectedImage != null) ChatImagePreviewStrip(
            file: s.selectedImage!,
            onRemove: () => _controller.removeImage(),
          ),

          // ── Messages list (or starter suggestions on a fresh chat) ────────
          Expanded(
            child: s.messages.isEmpty && !s.isLoading
                ? ChatEmptyState(
                    suggestions: _controller.effectiveSuggestions,
                    onSuggestion: _sendSuggestion,
                  )
                : _MessagesList(
                    scrollController: _scrollController,
                    typingController: _typingController,
                    messages: s.messages,
                    isLoading: s.isLoading,
                    cardBuilder: _buildCard,
                  ),
          ),

          // ── Input bar ─────────────────────────────────────────────────────
          ChatSendBar(
            controller: _textController,
            isListening: _isListening,
            micPulseController: _micPulseController,
            bottomViewPadding: MediaQuery.of(context).viewPadding.bottom,
            onImageTap: () => showChatImageSourceSheet(context, onPick: _pickImage),
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
    final vendor = await _controller.vendorFor(id);
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
    if (product.sourceId == null || product.sourceId!.isEmpty) {
      _showSnack('Restaurant introuvable');
      return;
    }

    final restaurant = AiChatController.restaurantFor(product);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
      ),
    );
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// The conversation, newest at the bottom, with the typing dots while the
/// assistant answers.
class _MessagesList extends StatelessWidget {
  const _MessagesList({
    required this.scrollController,
    required this.typingController,
    required this.messages,
    required this.isLoading,
    required this.cardBuilder,
  });

  final ScrollController scrollController;
  final AnimationController typingController;
  final List<ChatMessage> messages;
  final bool isLoading;
  final Widget Function(ProductResult product) cardBuilder;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      reverse: true,
      // ── Task 1: keyboard avoidance via Scaffold is automatic ──
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      itemCount: messages.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (isLoading && index == 0) {
          return ChatTypingIndicator(controller: typingController);
        }
        final msgIndex = isLoading ? index - 1 : index;
        return ChatMessageBubble(
          message: messages[msgIndex],
          cardBuilder: cardBuilder,
        );
      },
    );
  }
}
