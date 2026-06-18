import 'package:flutter/material.dart';
import 'package:kiblat/models/prayer_settings_model.dart';

class AppTheme {
  // Check if current mode is light
  static bool isLight(PrayerSettings settings, BuildContext context) {
    // Free users are locked to dark mode
    if (!settings.isProUser) return false;
    
    if (settings.displayMode == 'light') return true;
    if (settings.displayMode == 'system') {
      final brightness = MediaQuery.of(context).platformBrightness;
      return brightness == Brightness.light;
    }
    return false;
  }

  // Get background color of Scaffold
  static Color getBackgroundColor(PrayerSettings settings, BuildContext context) {
    if (isLight(settings, context)) {
      return const Color(0xFFF6F6F6);
    }
    // Dark mode backgrounds
    switch (settings.compassTheme) {
      case 'cyber':
        return const Color(0xFF030A12); // Very dark cyber blue
      case 'dark':
        return const Color(0xFF010101); // Pure black
      default:
        return const Color(0xFF050505); // Default dark
    }
  }

  // Get card/container background color
  static Color getCardColor(PrayerSettings settings, BuildContext context) {
    if (isLight(settings, context)) {
      return const Color(0xFFFFFFFF);
    }
    switch (settings.compassTheme) {
      case 'cyber':
        return const Color(0xFF0C1928);
      case 'dark':
        return const Color(0xFF101010);
      default:
        return const Color(0xFF121212);
    }
  }

  // Get primary text color
  static Color getTextColor(PrayerSettings settings, BuildContext context) {
    if (isLight(settings, context)) {
      return const Color(0xFF1A1A1A);
    }
    return const Color(0xFFFFFFFF);
  }

  // Get secondary text color
  static Color getSecondaryTextColor(PrayerSettings settings, BuildContext context) {
    if (isLight(settings, context)) {
      return const Color(0xFF555555);
    }
    return const Color(0xFFB0B0B0);
  }

  // Get accent/primary color (for highlights, buttons, headings)
  static Color getAccentColor(PrayerSettings settings, [BuildContext? context]) {
    final light = context != null && isLight(settings, context);
    switch (settings.compassTheme) {
      case 'gold':
        return light ? const Color(0xFFB58A0D) : const Color(0xFFD4AF37); // Darker Gold vs Gold
      case 'cyber':
        return light ? const Color(0xFF0097A7) : const Color(0xFF00FFFF); // Cyan Teal vs Cyan neon
      case 'dark':
        return light ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF); // Black vs White
      default:
        return light ? const Color(0xFF2E7D32) : const Color(0xFF4CAF50); // Dark Green vs Green (Classic)
    }
  }
  
  // Get border color
  static Color getBorderColor(PrayerSettings settings, BuildContext context) {
    if (isLight(settings, context)) {
      return const Color(0xFFE2E2E2);
    }
    return const Color(0xFF222222);
  }
}
