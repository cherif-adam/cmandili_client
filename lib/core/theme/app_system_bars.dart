import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The Android/iOS system bars: the app draws edge-to-edge, behind
/// transparent bars, without the grey "contrast" scrim Android adds behind
/// 3-button navigation. Only the icon colour changes per screen:
///
///   [onLight]  dark icons — light screens (most of the app)
///   [onDark]   light icons — the orange login and password screens, and
///              the dark theme
///
/// MaterialApp.builder applies the theme's default to the whole app; a
/// screen with another background wraps itself in
/// `AnnotatedRegion<SystemUiOverlayStyle>`. App bars pick their own status
/// bar icons from their background colour.
abstract final class AppSystemBars {
  static const onLight = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // Android
    statusBarBrightness: Brightness.light, // iOS: light background
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );

  static const onDark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );

  /// The style for a screen whose background has this brightness.
  static SystemUiOverlayStyle forBackground(Brightness background) =>
      background == Brightness.dark ? onDark : onLight;

  /// Once, before runApp. Android 15+ already forces edge-to-edge for
  /// targetSdk 35+; this makes every Android version behave the same.
  static Future<void> enableEdgeToEdge() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(onLight);
  }
}
