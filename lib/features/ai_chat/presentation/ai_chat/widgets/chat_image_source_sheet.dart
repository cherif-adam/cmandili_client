import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../chat_palette.dart';

/// Camera or gallery; [onPick] gets the choice (the caller closes the
/// sheet).
void showChatImageSourceSheet(BuildContext context, {required ValueChanged<ImageSource> onPick}) {
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
            onTap: () => onPick(ImageSource.camera),
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
            onTap: () => onPick(ImageSource.gallery),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}
