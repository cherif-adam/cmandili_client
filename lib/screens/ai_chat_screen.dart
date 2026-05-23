// lib/screens/ai_chat_screen.dart

import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/ai_chat_service.dart';

class AiChatScreen extends StatefulWidget {
  @override
  _AiChatScreenState createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final AiChatService _chatService = AiChatService();
  bool _isLoading = false;

  List<Map<String, dynamic>> _apiHistory = [];

  void _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    _textController.clear();

    setState(() {
      _messages.insert(0, ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });

    final aiResponse = await _chatService.sendMessage(text, _apiHistory);

    setState(() {
      _isLoading = false;
      _messages.insert(0, aiResponse);

      _apiHistory.add({
        "role": "user",
        "parts": [{"text": text}]
      });
      _apiHistory.add({
        "role": "model",
        "parts": [{"text": aiResponse.text}]
      });
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cmandili Assistant')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          _buildTextComposer(),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment:
            message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: message.isUser ? Colors.blue[100] : Colors.grey[200],
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(message.text),
          ),
          if (message.products != null && message.products!.isNotEmpty)
            Container(
              height: 200,
              margin: const EdgeInsets.only(top: 10),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: message.products!.length,
                itemBuilder: (context, index) {
                  return _buildProductCard(message.products![index]);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductResult product) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildProductImage(product.imageUrl)),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${product.price.toStringAsFixed(3)} ${product.currency}',
                    style: const TextStyle(color: Colors.green),
                  ),
                  Text(
                    product.sourceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Safely renders a product image.
  /// - Valid http/https URL  → Image.network with error fallback.
  /// - Null / invalid URL    → grey placeholder with food icon.
  Widget _buildProductImage(String? imageUrl) {
    final isValid = imageUrl != null &&
        imageUrl.isNotEmpty &&
        (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));

    if (!isValid) return _imagePlaceholder();

    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      // Show a placeholder while loading
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _imagePlaceholder(loading: true);
      },
      // Show a placeholder on any network/parse error — no crash
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Image load error for $imageUrl: $error');
        return _imagePlaceholder();
      },
    );
  }

  Widget _imagePlaceholder({bool loading = false}) {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.restaurant, color: Colors.grey[400], size: 32),
      ),
    );
  }

  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Row(
          children: [
            Flexible(
              child: TextField(
                controller: _textController,
                onSubmitted: _handleSubmitted,
                decoration: const InputDecoration.collapsed(
                  hintText: "Demandez-moi quelque chose...",
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => _handleSubmitted(_textController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}