import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../data/models/supermarket.dart';

/// The supermarket's photo at the top of its page, with a round white
/// ← back button. Green bar once collapsed.
///
/// Returns a [SliverAppBar], so it goes in a [CustomScrollView]'s slivers.
class SupermarketDetailAppBar extends StatelessWidget {
  final Supermarket supermarket;

  const SupermarketDetailAppBar({super.key, required this.supermarket});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: const Color(0xFF4CAF50),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: (supermarket.imageUrl.isNotEmpty &&
                supermarket.imageUrl.startsWith('http'))
            ? CachedNetworkImage(
                imageUrl: supermarket.imageUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: const Icon(Icons.storefront, size: 50, color: Colors.grey),
                ),
              )
            : Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: const Icon(Icons.storefront, size: 50, color: Colors.grey),
              ),
      ),
    );
  }
}
