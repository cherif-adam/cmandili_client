import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../favorites/providers/favorites_provider.dart';
import '../../../../home/data/models/restaurant.dart';

/// The big photo at the top of a restaurant's page, with three round
/// white buttons over it: ← back · ♡ favourite · share.
///
/// Returns a [SliverAppBar], so it goes in a [CustomScrollView]'s slivers.
class RestaurantDetailAppBar extends StatelessWidget {
  final Restaurant restaurant;

  const RestaurantDetailAppBar({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.background,
      leading: _RoundButton(
        icon: Icons.arrow_back,
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        _FavoriteButton(restaurant: restaurant),
        _RoundButton(
          icon: Icons.share_outlined,
          onPressed: () {
            Share.share(
              'Check out ${restaurant.name}!\n'
              '${restaurant.description}\n'
              'Rating: ${restaurant.rating} ⭐\n'
              'Delivery: ${restaurant.deliveryTime} min',
              subject: restaurant.name,
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Hero(
          tag: 'restaurant_image_${restaurant.id}',
          child: Stack(
            fit: StackFit.expand,
            children: [
              (restaurant.imageUrl.isNotEmpty && restaurant.imageUrl.startsWith('http'))
                  ? CachedNetworkImage(
                      imageUrl: restaurant.imageUrl,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: const Icon(Icons.restaurant, size: 50, color: Colors.grey),
                    ),
              // Darkens the bottom of the photo.
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round white button over the photo.
class _RoundButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onPressed;

  const _RoundButton({
    required this.icon,
    required this.onPressed,
    this.iconColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor),
        onPressed: onPressed,
      ),
    );
  }
}

/// ♡ / ♥ — adds or removes the restaurant from the favourites.
class _FavoriteButton extends ConsumerWidget {
  final Restaurant restaurant;

  const _FavoriteButton({required this.restaurant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(isFavoriteProvider(restaurant.id));
    return _RoundButton(
      icon: isFav ? Icons.favorite : Icons.favorite_border,
      iconColor: isFav ? AppColors.error : Colors.black,
      onPressed: () {
        ref.read(favoritesProvider.notifier).toggleFavorite(restaurant);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFav
                  ? AppLocalizations.of(context)!.removedFromFavorites
                  : AppLocalizations.of(context)!.addedToFavorites,
            ),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }
}
