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

  static ThemeData get lightHighContrast {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: Colors.black,
        secondary: primary,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.white,
      dividerColor: Colors.black,
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 13,
          color: Colors.black,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.black, width: 1.5),
        ),
        elevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        indicatorColor: Color(0xFFE0E0E0),
      ),
    );
  }

  static ThemeData get darkHighContrast {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        secondary: primaryLight,
        surface: Colors.black,
      ),
      scaffoldBackgroundColor: Colors.black,
      dividerColor: Colors.white,
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 13,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white, width: 1.5),
        ),
        elevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        indicatorColor: Color(0xFF3A3A3A),
      ),
    );
  }
}
