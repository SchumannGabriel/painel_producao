import 'package:flutter/material.dart';

class AppTheme {
  // Paleta industrial/produção
  static const Color background = Color(0xFF0F1117);
  static const Color surface = Color(0xFF1A1D27);
  static const Color surfaceElevated = Color(0xFF22263A);
  static const Color border = Color(0xFF2E3347);

  // Acentos
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentYellow = Color(0xFFF59E0B);
  static const Color accentRed = Color(0xFFEF4444);

  // Texto
  static const Color textPrimary = Color(0xFFE8EAF0);
  static const Color textSecondary = Color(0xFF8B90A8);
  static const Color textMuted = Color(0xFF4B5168);

  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          background: background,
          surface: surface,
          primary: accentBlue,
        ),
        fontFamily: 'Inter',
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -1,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: -0.5,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textSecondary,
            letterSpacing: 0.5,
          ),
          bodyMedium: TextStyle(
            fontSize: 13,
            color: textSecondary,
            height: 1.5,
          ),
          labelSmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textMuted,
            letterSpacing: 1.0,
          ),
        ),
      );

  /// Cor de status baseada no % da meta
  static Color colorParaPercentual(double pct) {
    if (pct >= 100) return accentGreen;
    if (pct >= 80) return accentBlue;
    if (pct >= 50) return accentYellow;
    return accentRed;
  }
}
