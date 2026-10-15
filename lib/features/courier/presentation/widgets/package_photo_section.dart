import 'dart:io';

import 'package:flutter/material.dart';

/// The optional parcel photo: a grey "Ajouter une photo du colis" box, or
/// — once picked — the photo with a × (remove) and "Changer" on top.
class PackagePhotoSection extends StatelessWidget {
  final File? photo;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final double screenWidth;
  final double screenHeight;

  const PackagePhotoSection({
    super.key,
    required this.photo,
    required this.onPick,
    required this.onRemove,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final w = screenWidth;
    final h = screenHeight;
    if (photo != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(w * 0.04),
            child: Image.file(
              photo!,
              width: double.infinity,
              height: h * 0.22,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: GestureDetector(
              onTap: onPick,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Changer',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: onPick,
      child: Container(
        width: double.infinity,
        height: h * 0.14,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(w * 0.04),
          border: Border.all(
            color: Colors.grey.shade300,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              size: w * 0.1,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: h * 0.008),
            Text(
              'Ajouter une photo du colis',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: w * 0.035,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: h * 0.004),
            Text(
              'Appuyer pour prendre/choisir une photo',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: w * 0.03,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
