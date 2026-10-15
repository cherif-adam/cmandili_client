import 'package:flutter/material.dart';

import '../../../../core/models/service_category.dart';
import '../../../../core/theme/app_colors.dart';
import 'deliver_to_button.dart';
import 'home_search_field.dart';
import 'notification_bell_button.dart';

/// The coloured top of the home tab (orange for restaurants, green for the
/// rest), pinned while scrolling:
///
///   Row:  DeliverToButton ............ NotificationBellButton
///   HomeSearchField   (stays visible when the header collapses)
///
/// Returns a [SliverAppBar], so it goes in a [CustomScrollView]'s slivers.
class HomeHeader extends StatelessWidget {
  final ServiceType selectedService;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final double screenWidth;
  final double screenHeight;

  const HomeHeader({
    super.key,
    required this.selectedService,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: screenHeight * 0.18,
      floating: true,
      pinned: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: selectedService == ServiceType.foodDelivery
                ? AppColors.foodHeaderGradient
                : AppColors.primaryGradient,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(screenWidth * 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Flexible: lets the address column shrink when
                      // the notification bell needs space → no overflow
                      Flexible(
                        child: DeliverToButton(
                          screenWidth: screenWidth,
                          screenHeight: screenHeight,
                        ),
                      ),
                      NotificationBellButton(
                        screenWidth: screenWidth,
                        screenHeight: screenHeight,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(screenHeight * 0.1),
        child: HomeSearchField(
          controller: searchController,
          query: searchQuery,
          onChanged: onSearchChanged,
          onCleared: onSearchCleared,
          screenWidth: screenWidth,
          screenHeight: screenHeight,
        ),
      ),
    );
  }
}
