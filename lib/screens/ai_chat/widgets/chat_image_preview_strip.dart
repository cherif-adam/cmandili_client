import 'dart:io';

import 'package:flutter/material.dart';

// ─── Image preview strip ───────────────────────────────────────────────────────

class ChatImagePreviewStrip extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;
  const ChatImagePreviewStrip({super.key, required this.file, required this.onRemove});

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
