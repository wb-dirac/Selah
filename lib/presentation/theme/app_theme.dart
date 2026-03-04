import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF1A2B4A);
  static const Color primaryLight = Color(0xFF2E4A7A);
  static const Color primarySubtle = Color(0xFFEEF2F8);

  static const Color bgBase = Color(0xFFF7F6F4);
  static const Color bgSurface = Color(0xFFFFFFFF);
  static const Color bgElevated = Color(0xFFFDFCFB);
  static const Color border = Color(0xFFE8E4DE);

  static const Color textPrimary = Color(0xFF1C1A18);
  static const Color textSecondary = Color(0xFF6B6560);
  static const Color textMuted = Color(0xFFA09890);

  static const Color bgBaseDark = Color(0xFF141210);
  static const Color bgSurfaceDark = Color(0xFF1E1C19);
  static const Color borderDark = Color(0xFF3A3530);
  static const Color textPrimaryDark = Color(0xFFF0EDE8);
  static const Color textSecondaryDark = Color(0xFFC0BAB2);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: primaryLight,
        surface: bgSurface,
      ),
      scaffoldBackgroundColor: bgBase,
      dividerColor: border,
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 15,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 13,
          color: textSecondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
        elevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        indicatorColor: primarySubtle,
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: primaryLight,
        secondary: primary,
        surface: bgSurfaceDark,
      ),
      scaffoldBackgroundColor: bgBaseDark,
      dividerColor: borderDark,
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 15,
          color: textPrimaryDark,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 13,
          color: textSecondaryDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: bgSurfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark),
        ),
        elevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        indicatorColor: primary,
      ),
    );
  }
}
