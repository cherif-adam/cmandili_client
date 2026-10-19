import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../../core/models/vendor.dart';
import '../../../../../core/theme/app_colors.dart';

/// The shop's photo at the top of its page (a shop icon when there is none).
///
/// Returns a [SliverAppBar], so it goes in a [CustomScrollView]'s slivers.
class VendorDetailAppBar extends StatelessWidget {
  final Vendor vendor;

  const VendorDetailAppBar({super.key, required this.vendor});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 210,
      pinned: true,
      backgroundColor: Theme.of(context).cardColor,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      flexibleSpace: FlexibleSpaceBar(
        background: vendor.imageUrl.isEmpty
            ? Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: const Icon(Icons.storefront_rounded,
                    size: 56, color: AppColors.textLight),
              )
            : CachedNetworkImage(
                imageUrl: vendor.imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: const Icon(Icons.storefront_rounded,
                      size: 56, color: AppColors.textLight),
                ),
              ),
      ),
    );
  }
}
