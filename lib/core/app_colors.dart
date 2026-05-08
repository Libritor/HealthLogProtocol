import 'package:flutter/material.dart';

/// HealthLog Protocol palette — Solana-native dark theme.
class AppColors {
  AppColors._();

  // Solana brand
  static const solanaPurple = Color(0xFF9945FF);
  static const solanaTeal = Color(0xFF14F195);

  // Surfaces
  static const ink = Color(0xFF0E0E11);
  static const surface = Color(0xFF16171C);
  static const surfaceHigh = Color(0xFF1F2128);
  static const surfaceLow = Color(0xFF0A0B0E);
  static const outline = Color(0xFF2A2C36);
  static const outlineSoft = Color(0xFF1B1D26);

  // Foregrounds
  static const onSurface = Color(0xFFF5F5F7);
  static const onSurfaceMuted = Color(0xFF9DA0AE);
  static const onSurfaceDim = Color(0xFF6B6E7C);

  // Status
  static const success = Color(0xFF14F195);
  static const danger = Color(0xFFFF6B6B);
  static const warning = Color(0xFFFFC857);
  static const info = Color(0xFF59A5FF);

  // Brand gradient — use sparingly: title, primary CTA, hero accents only.
  static const brandGradient = LinearGradient(
    colors: [solanaPurple, solanaTeal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Subtle surface gradient for hero cards.
  static const heroGradient = LinearGradient(
    colors: [Color(0xFF1A1535), Color(0xFF0E1B1A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData buildTheme() {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: ink,
      colorScheme: const ColorScheme.dark(
        primary: solanaPurple,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF2B1A4D),
        onPrimaryContainer: Color(0xFFE7DBFF),
        secondary: solanaTeal,
        onSecondary: Colors.black,
        secondaryContainer: Color(0xFF0F3A2E),
        onSecondaryContainer: Color(0xFFB6F5DA),
        surface: surface,
        onSurface: onSurface,
        surfaceContainerLowest: surfaceLow,
        surfaceContainerLow: Color(0xFF131419),
        surfaceContainer: Color(0xFF181A21),
        surfaceContainerHigh: surfaceHigh,
        surfaceContainerHighest: Color(0xFF24262F),
        onSurfaceVariant: onSurfaceMuted,
        outline: outline,
        outlineVariant: outlineSoft,
        error: danger,
        onError: Colors.white,
      ),
    );

    return base.copyWith(
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: outlineSoft, width: 1),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: surfaceHigh,
        side: BorderSide(color: outline),
        labelStyle: TextStyle(color: onSurface, fontSize: 12),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: solanaPurple,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: const BorderSide(color: outline),
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: solanaPurple, width: 1.6),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: surfaceLow,
        indicatorColor: Color(0xFF2B1A4D),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: const TextStyle(color: onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: outlineSoft,
    );
  }
}
