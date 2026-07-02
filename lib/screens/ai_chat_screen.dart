// lib/screens/ai_chat_screen.dart
//
// Cmandili AI Chat — Full Feature Set
// ✅ Orange Brand Theme
// ✅ Task 1: Keyboard overflow fix (resizeToAvoidBottomInset + scrollable)
// ✅ Task 2: Clickable food cards → RestaurantDetailScreen
// ✅ Task 3: Voice input (Android native speech via MethodChannel)
// ✅ Task 4: Image upload & Vision (image_picker + base64 to Gemini)

import 'dart:io';
import 'dart:math' as math;
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

// ─── Brand palette ─────────────────────────────────────────────────────────
const _kOrange        = Color(0xFFFF9800);
const _kOrangeDark    = Color(0xFFE65100);
const _kOrangeLight   = Color(0xFFFFB74D);
const _kBg            = Color(0xFFF8F9FA);
const _kAiBubble      = Colors.white;
const _kAiBubbleShadow= Color(0x18000000);
const _kUserBubbleTop = Color(0xFFFF9800);
const _kUserBubbleBot = Color(0xFFE65100);
const _kTextDark      = Color(0xFF1C1C1E);
const _kTextMid       = Color(0xFF6E6E73);
const _kGreenDot      = Color(0xFF34C759);

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

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

  // ── Task 3: Voice — native Android speech via MethodChannel ───────────────
  // Uses Android's built-in SpeechRecognizer (no external package needed).
  // MethodChannel defined in MainActivity.kt (see comment below).
  static const _speechChannel = MethodChannel('com.cmandili.mobile/speech');
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
                  color: _kOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: _kOrange),
              ),
              title: const Text('Prendre une photo',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => _pickImage(ImageSource.camera),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library_rounded, color: _kOrange),
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

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade600 : _kOrange,
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
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ── Listening banner ─────────────────────────────────────────────
          if (_isListening) _ListeningBanner(controller: _micPulseController),

          // ── Image preview strip ───────────────────────────────────────────
          if (_selectedImage != null) _ImagePreviewStrip(
            file: _selectedImage!,
            onRemove: () => setState(() => _selectedImage = null),
          ),

          // ── Messages list ─────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              // ── Task 1: keyboard avoidance via Scaffold is automatic ──────
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isLoading && index == 0) {
                  return _TypingIndicator(controller: _typingController);
                }
                final msgIndex = _isLoading ? index - 1 : index;
                return _buildMessage(_messages[msgIndex]);
              },
            ),
          ),

          // ── Input bar ─────────────────────────────────────────────────────
          _buildSendBar(),
        ],
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    final double statusBarH = MediaQuery.of(context).padding.top;
    const double toolbarH   = 68;

    return PreferredSize(
      preferredSize: Size.fromHeight(toolbarH + statusBarH),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kOrangeDark, _kOrange],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x33FF9800),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(top: statusBarH, left: 12, right: 12),
          child: SizedBox(
            height: toolbarH,
            child: Row(
              children: [
                _AppBarBtn(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(child: Text('🤖', style: TextStyle(fontSize: 20))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cmandili Assistant',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      Row(
                        children: [
                          Container(width: 7, height: 7, decoration: const BoxDecoration(color: _kGreenDot, shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          Text(
                            _isLoading ? 'En train d\'écrire...' : 'En ligne',
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const _Pill(emoji: '🍽️', label: 'Food'),
                const SizedBox(width: 6),
                const _Pill(emoji: '📦', label: 'P2P'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Message bubble ───────────────────────────────────────────────────────

  Widget _buildMessage(ChatMessage message) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser)
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 4),
                  child: _AiAvatar(),
                ),
              Flexible(
                child: Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // ── Image preview (if user sent image) ────────────────
                    if (isUser && message.imageFile != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        width: 180,
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: _kOrange.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(message.imageFile!, fit: BoxFit.cover),
                        ),
                      ),

                    // ── Text bubble ───────────────────────────────────────
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.74,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: isUser
                            ? const LinearGradient(
                                colors: [_kUserBubbleTop, _kUserBubbleBot],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isUser ? null : _kAiBubble,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isUser ? 20 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isUser ? _kOrange.withValues(alpha: 0.28) : _kAiBubbleShadow,
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        message.text,
                        style: TextStyle(
                          color: isUser ? Colors.white : _kTextDark,
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Product cards ─────────────────────────────────────────────────
          if (message.products != null && message.products!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 10, left: !isUser ? 46 : 0),
              child: SizedBox(
                height: message.intent == 'delivery_request' ? 210 : 230,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: message.products!.length,
                  itemBuilder: (ctx, i) => _buildCard(message.products![i]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(ProductResult product) {
    switch (product.type) {
      case 'delivery': return _DeliveryCard(product: product);
      case 'shop':     return _ShopCard(product: product);
      default:         return _FoodCard(product: product, onTap: () => _navigateToRestaurant(product));
    }
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

  // ─── Send bar ─────────────────────────────────────────────────────────────

  Widget _buildSendBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).viewPadding.bottom * 0.5,
      ),
      child: Row(
        children: [
          // ── Task 4: Image button ─────────────────────────────────────────
          _InputActionBtn(
            icon: Icons.add_photo_alternate_rounded,
            color: _kOrange,
            onTap: _showImageSourceSheet,
          ),
          const SizedBox(width: 8),

          // ── TextField ────────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _isListening
                      ? Colors.red.shade300
                      : _kOrange.withValues(alpha: 0.5),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isListening ? Colors.red : _kOrange).withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _textController,
                onSubmitted: _handleSubmitted,
                style: const TextStyle(fontSize: 15, color: _kTextDark),
                decoration: InputDecoration(
                  hintText: _isListening
                      ? 'J\'écoute... parlez maintenant 🎙️'
                      : 'Food, livraison, magasin...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: _kOrange.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  border: InputBorder.none,
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── Task 3: Mic button ───────────────────────────────────────────
          _MicButton(
            isListening: _isListening,
            pulseController: _micPulseController,
            onTap: _toggleListening,
          ),
          const SizedBox(width: 8),

          // ── Send button ──────────────────────────────────────────────────
          GestureDetector(
            onTap: () => _handleSubmitted(_textController.text),
            child: Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kOrangeLight, _kOrange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _kOrange.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Small action button in send bar ──────────────────────────────────────────

class _InputActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _InputActionBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

// ─── Mic button with pulse animation ──────────────────────────────────────────

class _MicButton extends StatelessWidget {
  final bool isListening;
  final AnimationController pulseController;
  final VoidCallback onTap;

  const _MicButton({
    required this.isListening,
    required this.pulseController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isListening) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFF9800).withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3), width: 1.5),
          ),
          child: const Icon(Icons.mic_rounded, color: Color(0xFFFF9800), size: 20),
        ),
      );
    }

    return AnimatedBuilder(
      animation: pulseController,
      builder: (_, __) {
        final scale = 1.0 + pulseController.value * 0.15;
        return GestureDetector(
          onTap: onTap,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.4 + pulseController.value * 0.2),
                    blurRadius: 12 + pulseController.value * 6,
                    spreadRadius: pulseController.value * 3,
                  ),
                ],
              ),
              child: const Icon(Icons.mic_off_rounded, color: Colors.white, size: 20),
            ),
          ),
        );
      },
    );
  }
}

// ─── Listening banner ─────────────────────────────────────────────────────────

class _ListeningBanner extends StatelessWidget {
  final AnimationController controller;
  const _ListeningBanner({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.red.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mic_rounded, color: Colors.red.shade600, size: 16),
              const SizedBox(width: 8),
              Text(
                'En écoute... Parlez maintenant',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              // Animated dots
              ...List.generate(3, (i) {
                final t = (controller.value * 3 - i).clamp(0.0, 1.0);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 5, height: 5,
                  decoration: BoxDecoration(
                    color: Colors.red.shade600.withValues(alpha: 0.3 + t * 0.7),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ─── Image preview strip ───────────────────────────────────────────────────────

class _ImagePreviewStrip extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;
  const _ImagePreviewStrip({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(file, width: 60, height: 60, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Image prête à envoyer — L\'IA va identifier le plat ! 🔍',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: Colors.grey.shade500,
          ),
        ],
      ),
    );
  }
}

// ─── AI CircleAvatar ───────────────────────────────────────────────────────────

class _AiAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFF9800).withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Text('🤖', style: TextStyle(fontSize: 16))),
      ),
    );
  }
}

// ─── AppBar back button ────────────────────────────────────────────────────────

class _AppBarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AppBarBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

// ─── Service pill ──────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String emoji;
  final String label;
  const _Pill({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Typing indicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  final AnimationController controller;
  const _TypingIndicator({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(padding: const EdgeInsets.only(right: 8), child: _AiAvatar()),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: _kAiBubble,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [BoxShadow(color: _kAiBubbleShadow, blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (i) => _BouncingDot(controller: controller, delay: i * 0.22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BouncingDot extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  const _BouncingDot({required this.controller, required this.delay});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = (controller.value + delay) % 1.0;
        final offset = -math.sin(t * math.pi) * 6;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          transform: Matrix4.translationValues(0, offset, 0),
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: _kOrange.withValues(alpha: 0.55 + 0.45 * math.sin(t * math.pi)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

// ─── Task 2: Food Card (CLICKABLE) ────────────────────────────────────────────

class _FoodCard extends StatelessWidget {
  final ProductResult product;
  final VoidCallback onTap; // ← triggers restaurant navigation
  const _FoodCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 162,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            // ── Task 2: onTap navigates to RestaurantDetailScreen ──────────
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    SizedBox(
                      height: 112, width: double.infinity,
                      child: _ProductImage(
                        imageUrl: product.imageUrl,
                        iconFallback: '🍽️',
                        bgColor: const Color(0xFFFFF3E0),
                      ),
                    ),
                    Positioned(
                      bottom: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_kOrangeLight, _kOrange]),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: _kOrange.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Text(
                          product.price == 0.0 ? 'Gratuit' : '${product.price.toStringAsFixed(3)} TND',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kTextDark, height: 1.3),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.storefront_rounded, size: 11, color: _kTextMid.withValues(alpha: 0.7)),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                product.sourceName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10, color: _kTextMid.withValues(alpha: 0.7)),
                              ),
                            ),
                          ],
                        ),
                        if (product.rating != null) ...[
                          const SizedBox(height: 4),
                          _StarRating(rating: product.rating!),
                        ],
                        // ── Tap hint ───────────────────────────────────────
                        const Spacer(),
                        const Row(
                          children: [
                            Icon(Icons.touch_app_rounded, size: 11, color: _kOrange),
                            SizedBox(width: 3),
                            Text('Commander', style: TextStyle(fontSize: 10, color: _kOrange, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shop Card ─────────────────────────────────────────────────────────────────

class _ShopCard extends StatelessWidget {
  final ProductResult product;
  const _ShopCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 162,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 112, width: double.infinity,
                  child: _ProductImage(imageUrl: product.imageUrl, iconFallback: '🛍️', bgColor: const Color(0xFFE8F5E9)),
                ),
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      product.sourceName.isEmpty ? 'Magasin' : product.sourceName,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kTextDark)),
                    const SizedBox(height: 4),
                    if (product.price > 0)
                      Text('${product.price.toStringAsFixed(3)} TND',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                    if (product.rating != null) ...[
                      const SizedBox(height: 4),
                      _StarRating(rating: product.rating!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Delivery P2P Card ─────────────────────────────────────────────────────────

class _DeliveryCard extends StatelessWidget {
  final ProductResult product;
  const _DeliveryCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 268,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _kOrange.withValues(alpha: 0.28), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          const Positioned(right: -18, top: -18, child: _DecorCircle(size: 110, opacity: 0.05)),
          const Positioned(right: 20, bottom: -28, child: _DecorCircle(size: 85, opacity: 0.05)),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(color: _kOrange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                      child: const Center(child: Text('📦', style: TextStyle(fontSize: 24))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Livraison P2P', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                          Container(
                            margin: const EdgeInsets.only(top: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [_kOrangeLight, _kOrange]),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('Nouveau 🔥', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Envoyez vos colis à vos proches\nvia nos livreurs. Suivi live ! 🏍️',
                  style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
                ),
                const Spacer(),
                const Row(
                  children: [
                    _Feature(icon: '📍', label: 'Suivi live'),
                    SizedBox(width: 12),
                    _Feature(icon: '⚡', label: 'Express'),
                    SizedBox(width: 12),
                    _Feature(icon: '🔒', label: 'Sécurisé'),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Service P2P — bientôt disponible ! 🚀', style: TextStyle(color: Colors.white)),
                        backgroundColor: _kOrange,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity, height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_kOrangeLight, _kOrangeDark], begin: Alignment.centerLeft, end: Alignment.centerRight),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: _kOrange.withValues(alpha: 0.45), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: const Center(
                      child: Text('Créer une livraison  →', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final String icon;
  final String label;
  const _Feature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}

class _DecorCircle extends StatelessWidget {
  final double size;
  final double opacity;
  const _DecorCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: opacity)),
    );
  }
}

// ─── Star rating ───────────────────────────────────────────────────────────────

class _StarRating extends StatelessWidget {
  final double rating;
  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFFC107)),
        const SizedBox(width: 2),
        Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kTextMid)),
      ],
    );
  }
}

// ─── Product image with fallback ───────────────────────────────────────────────

class _ProductImage extends StatelessWidget {
  final String? imageUrl;
  final String iconFallback;
  final Color? bgColor;

  const _ProductImage({required this.imageUrl, required this.iconFallback, this.bgColor});

  @override
  Widget build(BuildContext context) {
    final isValid = imageUrl != null &&
        imageUrl!.isNotEmpty &&
        (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://'));

    if (!isValid) return _placeholder();

    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return _placeholder(loading: true);
      },
      errorBuilder: (ctx, err, st) => _placeholder(),
    );
  }

  Widget _placeholder({bool loading = false}) {
    return Container(
      color: bgColor ?? const Color(0xFFFFF3E0),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(_kOrange)),
              )
            : Text(iconFallback, style: const TextStyle(fontSize: 36)),
      ),
    );
  }
}