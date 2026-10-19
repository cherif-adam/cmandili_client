import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// The floating white menu bar at the bottom of the home screen:
/// Home · Favorites · Orders · Cart (with item count) · Profile.
///
/// Returns a [Positioned], so it must be a direct child of a [Stack].
class HomeBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final int cartItemCount;
  final ValueChanged<int> onSelect;
  final double screenWidth;
  final double screenHeight;

  const HomeBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.cartItemCount,
    required this.onSelect,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: screenHeight * 0.03,
      left: screenWidth * 0.06,
      right: screenWidth * 0.06,
      child: Container(
        height: screenHeight * 0.085,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(screenWidth * 0.06),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: screenWidth * 0.05,
              offset: Offset(0, screenHeight * 0.012),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _navItem(0, Icons.home_rounded, Icons.home_outlined),
            _navItem(1, Icons.favorite_rounded, Icons.favorite_border_rounded),
            _navItem(2, Icons.receipt_long_rounded, Icons.receipt_long_outlined),
            _CartNavItem(
              isSelected: selectedIndex == 3,
              count: cartItemCount,
              onTap: () => onSelect(3),
              screenWidth: screenWidth,
              screenHeight: screenHeight,
            ),
            _navItem(4, Icons.person_rounded, Icons.person_outline_rounded),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData activeIcon, IconData inactiveIcon) {
    return _NavItem(
      isSelected: selectedIndex == index,
      activeIcon: activeIcon,
      inactiveIcon: inactiveIcon,
      onTap: () => onSelect(index),
      screenWidth: screenWidth,
    );
  }
}

/// One icon of the menu bar, tinted green with a soft background when selected.
class _NavItem extends StatelessWidget {
  final bool isSelected;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final VoidCallback onTap;
  final double screenWidth;

  const _NavItem({
    required this.isSelected,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.onTap,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.all(screenWidth * 0.03),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
        ),
        child: Icon(
          isSelected ? activeIcon : inactiveIcon,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          size: screenWidth * 0.07,
        ),
      ),
    );
  }
}

/// The cart icon of the menu bar, with a red badge showing the item count.
class _CartNavItem extends StatelessWidget {
  final bool isSelected;
  final int count;
  final VoidCallback onTap;
  final double screenWidth;
  final double screenHeight;

  const _CartNavItem({
    required this.isSelected,
    required this.count,
    required this.onTap,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.all(screenWidth * 0.03),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(screenWidth * 0.04),
            ),
            child: Icon(
              isSelected ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: screenWidth * 0.07,
            ),
          ),
          if (count > 0)
            Positioned(
              top: screenHeight * 0.01,
              right: screenWidth * 0.02,
              child: Container(
                padding: EdgeInsets.all(screenWidth * 0.01),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                constraints: BoxConstraints(
                  minWidth: screenWidth * 0.04,
                  minHeight: screenWidth * 0.04,
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.025,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
