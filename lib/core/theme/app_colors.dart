import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors - Amana emerald palette (trust + freshness)
  static const primary = Color(0xFF059669);
  static const primaryDark = Color(0xFF047857);
  static const primaryLight = Color(0xFF34D399);

  // Secondary Colors - warm amber accent from the logo dot
  static const secondary = Color(0xFFF59E0B);
  static const secondaryDark = Color(0xFFD97706);
  static const secondaryLight = Color(0xFFFBBF24);

  // Accent Colors - deep teal companion
  static const accent = Color(0xFF14B8A6);
  static const accentDark = Color(0xFF0D9488);
  static const accentLight = Color(0xFF2DD4BF);
  
  // Neutral Colors
  static const background = Color(0xFFF8F9FA);
  static const surface = Colors.white;
  static const surfaceDark = Color(0xFF1A1A1A);
  static const backgroundDark = Color(0xFF121212);
  
  // Text Colors
  static const textPrimary = Color(0xFF2D3436);
  static const textSecondary = Color(0xFF636E72);
  static const textLight = Color(0xFFB2BEC3);
  static const textWhite = Colors.white;
  
  // Status Colors
  static const success = Color(0xFF00B894);
  static const error = Color(0xFFD63031);
  static const warning = Color(0xFFFDCB6E);
  static const info = Color(0xFF74B9FF);
  
  // Rating
  static const star = Color(0xFFFFC107);
  
  // Gradients
  static const primaryGradient = LinearGradient(
    colors: [primary, accentDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const accentGradient = LinearGradient(
    colors: [accent, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const darkGradient = LinearGradient(
    colors: [Color(0xFF2D3436), Color(0xFF1A1A1A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Loyalty card ("Carte de fidélité") ────────────────────────────────────
  static const loyaltySheetBarrier = Color(0x73042C26); // rgba(4,44,38,.45)

  static const loyaltyHeaderGradient = LinearGradient(
    begin: Alignment(-0.8, -0.6),
    end: Alignment(0.8, 0.6),
    colors: [
      Color(0xFF04342C),
      Color(0xFF0F6E56),
      Color(0xFF1D9E75),
      Color(0xFFE8890C),
    ],
    stops: [0.0, 0.42, 0.72, 1.0],
  );
  static const loyaltyDecorCircleAmber = Color(0x38F59E0B); // rgba(245,158,11,.22)
  static const loyaltyDecorCircleWhite = Color(0x0FFFFFFF); // rgba(255,255,255,.06)
  static const loyaltyPendingSubtitleColor = Color(0xFFFAC775);
  static const loyaltyProgressLabelColor = Color(0xFFE1F5EE);
  static const loyaltyProgressTrack = Color(0x38FFFFFF); // rgba(255,255,255,.22)
  static const loyaltyProgressFillGradient = LinearGradient(
    colors: [Color(0xFF5DCAA5), Color(0xFFF59E0B)],
  );

  static const loyaltyStampEarnedBg = Color(0xFFE1F5EE);
  static const loyaltyStampEarnedBorder = Color(0xFF1D9E75);
  static const loyaltyStampPendingBg = Color(0xFFFAEEDA);
  static const loyaltyStampPendingBorder = Color(0xFFF59E0B);
  static const loyaltyStampPendingIcon = Color(0xFFE8890C);
  static const loyaltyStampEmptyBorder = Color(0xFFC9C7BE);
  static const loyaltyStampRemovedBg = Color(0xFFFAECE7);
  static const loyaltyStampRemovedBorder = Color(0xFFD85A30);

  static const loyaltyButtonGradient = LinearGradient(
    colors: [Color(0xFF0F6E56), Color(0xFF1D9E75), Color(0xFF2AA87F)],
  );

  static const loyaltyDialogBackdropGradient = LinearGradient(
    begin: Alignment(-0.3, -1),
    end: Alignment(0.3, 1),
    colors: [Color(0x8C042C26), Color(0x59783F0A)], // rgba(4,44,38,.55) → rgba(120,63,10,.35)
  );
  static const loyaltyCancelAccentGradient = LinearGradient(
    colors: [Color(0xFF0F6E56), Color(0xFF1D9E75), Color(0xFFF59E0B)],
  );
  static const loyaltyCancelIconGradient = LinearGradient(
    colors: [Color(0xFFE1F5EE), Color(0xFFFAEEDA)],
  );
  static const loyaltyCancelIconColor = Color(0xFFD8722C);
  static const loyaltyCancelTitleColor = Color(0xFF04342C);
  static const loyaltyCancelNoteColor = Color(0xFF888780);
  static const loyaltyCancelMiniCardBg = Color(0xFFF6F8F7);
  static const loyaltyCancelMiniCardBorder = Color(0xFFE5E7E4);
  static const loyaltyCancelButtonGradient = LinearGradient(
    colors: [Color(0xFF0F6E56), Color(0xFF1D9E75), Color(0xFFF59E0B)],
  );

  // Rewards screen milestone cards (achieved reuses stamp-earned colors,
  // current-target reuses stamp-pending colors — kept visually consistent
  // with the stamp grid itself).
  static const loyaltyMilestoneAchievedBg = loyaltyStampEarnedBg;
  static const loyaltyMilestoneAchievedBorder = loyaltyStampEarnedBorder;
  static const loyaltyMilestoneCurrentBg = loyaltyStampPendingBg;
  static const loyaltyMilestoneCurrentBorder = loyaltyStampPendingBorder;
  static const loyaltyMilestoneLockedBg = Color(0xFFF2F2F0);
  static const loyaltyMilestoneLockedBorder = Color(0xFFDCDBD6);
  static const loyaltyMilestoneLockedIcon = Color(0xFFAFAEA8);

  // ── Order success screens + emerald form banners (colis/supermarket/facture) ─
  // Reuses the loyalty deep-emerald (#04342C) and button-emerald (#0F6E56 →
  // #1D9E75) tones so these flows stay visually consistent with the loyalty
  // card sheet they hand off to. Shared across all non-food order types.
  static const orderSuccessOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xEB04342C)], // ~92% opacity at bottom
  );
  static const orderSuccessButtonGradient = LinearGradient(
    colors: [Color(0xFF0F6E56), Color(0xFF1D9E75)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const orderSuccessSubtitleMint = Color(0xFF9FE1CB);
  static const emeraldBannerGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xD904342C), Color(0x3304342C)], // 85% → 20% opacity
  );

  // ── Orange form banner (food hero) ──────────────────────────────────────────
  static const orangeBannerGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xD9B4530A), Color(0x33B4530A)], // 85% → 20% opacity
  );

  // ── Happy Hour banner (home screen) ────────────────────────────────────────
  // Left-to-right readability overlay over the banner photo — dark on the
  // left where the white title/subtitle/button sit, fading out on the right
  // so the food in the image stays visible.
  static const happyHourOverlayGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    // ~65% opacity at the left edge, fully transparent by 55% width —
    // the right side (food) stays completely untinted.
    colors: [Color(0xA6B4530A), Color(0x00B4530A)],
    stops: [0.0, 0.55],
  );
}
