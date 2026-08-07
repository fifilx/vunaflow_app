import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// VunaFlow Design System Tokens — Redesign Concept
class AppColors {
  static const Color shamba900 = Color(0xFF122318);
  static const Color shamba800 = Color(0xFF1E3B29);
  static const Color shamba700 = Color(0xFF2B5A3F);
  static const Color shamba600 = Color(0xFF3A7255);

  static const Color parchment = Color(0xFFF5F2E7);
  static const Color parchment2 = Color(0xFFECE6D3);

  static const Color ink = Color(0xFF22241E);
  static const Color inkSoft = Color(0xFF5C5E4F);
  static const Color inkFaint = Color(0xFF8C8D77);

  static const Color gold = Color(0xFFD6A23D);
  static const Color goldDark = Color(0xFFA97A22);
  static const Color goldPale = Color(0xFFF1DDAF);

  static const Color sky = Color(0xFF3E7C8A);
  static const Color brick = Color(0xFFB03F2E);
  static const Color line = Color(0xFFDCD5BE);
  static const Color lineOnDark = Color(0x28F5F2E7);

  // Aliases for compatibility
  static const Color primary = shamba700;
  static const Color primaryDark = shamba900;
  static const Color primaryLight = shamba600;
  static const Color accent = gold;
  static const Color accentDark = goldDark;

  static const Color background = parchment;
  static const Color surface = Colors.white;
  static const Color textPrimary = ink;
  static const Color textSecondary = inkSoft;
  static const Color border = line;

  static const Color success = shamba700;
  static const Color warning = gold;
  static const Color danger = brick;
  static const Color info = sky;

  // Status colors mapped to loan lifecycle
  static const Map<String, Color> statusColors = {
    'submitted': sky,
    'under_review': goldDark,
    'documents_verified': Color(0xFF6B52AE),
    'approved': shamba700,
    'rejected': brick,
    'disbursed': shamba900,
  };
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.shamba700,
        primary: AppColors.shamba700,
        secondary: AppColors.gold,
        surface: AppColors.surface,
        error: AppColors.brick,
      ),
      scaffoldBackgroundColor: AppColors.parchment,
      fontFamily: GoogleFonts.publicSans().fontFamily,
    );

    return base.copyWith(
      textTheme: GoogleFonts.publicSansTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.fraunces(
          fontSize: 48,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          height: 1.05,
        ),
        displayMedium: GoogleFonts.fraunces(
          fontSize: 36,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          height: 1.1,
        ),
        headlineMedium: GoogleFonts.fraunces(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        titleLarge: GoogleFonts.fraunces(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        bodyLarge: GoogleFonts.publicSans(fontSize: 16, color: AppColors.ink, height: 1.6),
        bodyMedium: GoogleFonts.publicSans(fontSize: 14.5, color: AppColors.inkSoft, height: 1.5),
        labelSmall: GoogleFonts.ibmPlexMono(fontSize: 12, color: AppColors.goldDark, fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.parchment,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.ink,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          textStyle: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.ink, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          textStyle: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.shamba700, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brick),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.line),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
    );
  }
}

/// Human-friendly labels for loan status enum values from the backend.
String statusLabel(String status) {
  switch (status) {
    case 'submitted':
      return 'Submitted';
    case 'under_review':
      return 'Under Review';
    case 'documents_verified':
      return 'Documents Verified';
    case 'approved':
      return 'Approved';
    case 'rejected':
      return 'Rejected';
    case 'disbursed':
      return 'Disbursed';
    default:
      return status;
  }
}
