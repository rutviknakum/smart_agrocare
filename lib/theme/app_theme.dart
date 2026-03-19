import 'package:flutter/material.dart';

class AppTheme {
  // 🌱 Primary Colors
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color primaryDarkGreen = Color(0xFF1B5E20);
  static const Color primaryLightGreen = Color(0xFF4CAF50);

  // 💳 Card Colors
  static const Color cardGreen = Color(0xFFE8F5E8);
  static const Color cardBlue = Color(0xFFE3F2FD);
  static const Color cardHeader = Colors.white;

  // 📝 Text Colors
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Colors.black54;
  static const Color textSuccess = Color(0xFF2E7D32);
  static const Color textWarning = Color(0xFFF57C00);

  // 🌤️ Weather Colors
  static const Color weatherSunny = Color(0xFFFFB300);
  static const Color weatherCloudy = Color(0xFF90A4AE);
  static const Color weatherRainy = Color(0xFF42A5F5);

  static ThemeData buildTheme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: primaryLightGreen,
        surface: Colors.grey.shade50,
      ),
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      // 🎨 Typography - Material 3 Scale
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 57,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 64 / 57,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 40 / 32,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 36 / 28,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ).apply(bodyColor: textPrimary, displayColor: textPrimary),

      // 🃏 Cards - Perfect for WeatherScreen
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // 🔘 Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // 📱 AppBar
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.25,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        toolbarHeight: 72,
      ),

      // 🏷️ Chips
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey.shade100,
        labelStyle: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // 📊 Filled Buttons (Analyze, etc.)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      // 🎨 ColorScheme extensions
      colorScheme: base.colorScheme.copyWith(
        primary: primaryGreen,
        secondary: primaryLightGreen,
        surface: Colors.grey.shade50,
        surfaceVariant: Colors.grey.shade100,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        primaryContainer: cardGreen,
        secondaryContainer: cardBlue,
      ),

      // 📏 Input Fields
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryGreen, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  // 🌤️ Weather-specific gradients
  static LinearGradient weatherGradient(String? iconCode) {
    if (iconCode == null) {
      return const LinearGradient(
        colors: [primaryGreen, primaryDarkGreen],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    switch (iconCode[2]) {
      case 'd':
        return LinearGradient(
          colors: [weatherSunny, Colors.orange.shade300],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 'n':
        return LinearGradient(
          colors: [Colors.indigo.shade500, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return LinearGradient(
          colors: [primaryGreen, primaryLightGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  // 🎯 Status colors
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'healthy':
      case 'normal':
        return Colors.green.shade500;
      case 'warning':
      case 'medium':
        return Colors.orange.shade500;
      case 'error':
      case 'danger':
        return Colors.red.shade500;
      default:
        return primaryGreen;
    }
  }
}
