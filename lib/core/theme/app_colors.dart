import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors - Vibrant food-themed palette
  static const primary = Color(0xFFFF6B35);
  static const primaryDark = Color(0xFFE85A2B);
  static const primaryLight = Color(0xFFFF8C61);
  
  // Secondary Colors
  static const secondary = Color(0xFFF7931E);
  static const secondaryDark = Color(0xFFE07B0A);
  static const secondaryLight = Color(0xFFFFA94D);
  
  // Accent Colors
  static const accent = Color(0xFF4ECDC4);
  static const accentDark = Color(0xFF3AB8AF);
  static const accentLight = Color(0xFF6FD9D1);
  
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
    colors: [primary, secondaryDark],
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
}
