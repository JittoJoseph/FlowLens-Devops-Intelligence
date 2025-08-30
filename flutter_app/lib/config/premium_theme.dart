import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Premium Cream/White Color Palette
  static const Color primaryColor = Color(0xFF8B7355); // Warm Brown
  static const Color primaryLightColor = Color(0xFFA67C52); // Light Brown
  static const Color secondaryColor = Color(0xFF6B8E23); // Olive Green
  static const Color accentColor = Color(0xFFD4AF37); // Gold
  static const Color errorColor = Color(0xFFD2691E); // Chocolate Orange
  static const Color warningColor = Color(0xFFDAA520); // Goldenrod
  static const Color successColor = Color(0xFF228B22); // Forest Green

  // Additional Colors
  static const Color infoColor = Color(0xFF6B8E23); // Olive Green

  // Background Colors - Premium Cream Theme
  static const Color backgroundColor = Color(0xFFFFFDF7); // Cream White
  static const Color surfaceColor = Color(0xFFFAF8F3); // Light Cream
  static const Color cardColor = Color(0xFFFFFFFF); // Pure White
  static const Color dividerColor = Color(0xFFE8E2D4); // Light Beige

  // Text Colors - Premium Typography
  static const Color textPrimaryColor = Color(0xFF2C1810); // Dark Brown
  static const Color textSecondaryColor = Color(0xFF5D4E37); // Medium Brown
  static const Color textTertiaryColor = Color(0xFF8B7D6B); // Light Brown
  static const Color textHintColor = Color(0xFFB8A082); // Very Light Brown

  // Risk Level Colors - Redesigned for cream theme
  static const Color lowRiskColor = Color(0xFF228B22); // Forest Green
  static const Color mediumRiskColor = Color(0xFFDAA520); // Goldenrod
  static const Color highRiskColor = Color(0xFFD2691E); // Chocolate Orange

  // Premium Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF8B7355), Color(0xFFA67C52)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFFAF8F3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFFFFDF7), Color(0xFFF5F2EA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Premium Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      surface: surfaceColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimaryColor,
    ),
    scaffoldBackgroundColor: backgroundColor,
    textTheme: GoogleFonts.poppinsTextTheme().copyWith(
      headlineLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textPrimaryColor,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: textPrimaryColor,
        letterSpacing: -0.25,
      ),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textPrimaryColor,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimaryColor,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: textSecondaryColor,
      ),
      titleSmall: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textSecondaryColor,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textSecondaryColor,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textTertiaryColor,
        height: 1.4,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textHintColor,
        height: 1.3,
      ),
      labelLarge: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textSecondaryColor,
        letterSpacing: 0.1,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 8,
        shadowColor: primaryColor.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 12,
      shadowColor: Color(0x1A8B7355),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      color: cardColor,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: textPrimaryColor,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textPrimaryColor,
        letterSpacing: -0.25,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: cardColor,
      selectedItemColor: primaryColor,
      unselectedItemColor: textTertiaryColor,
      elevation: 20,
      type: BottomNavigationBarType.fixed,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
  );

  // Dark Theme (keeping simple for now)
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFA67C52),
      secondary: Color(0xFF6B8E23),
      error: errorColor,
      surface: Color(0xFF1E1611),
    ),
    scaffoldBackgroundColor: const Color(0xFF0F0C08),
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFA67C52),
        foregroundColor: Colors.white,
        elevation: 8,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      color: Color(0xFF1E1611),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: const Color(0xFFFAF8F3),
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFFAF8F3),
      ),
    ),
  );

  // Helper methods for risk level colors
  static Color getRiskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return lowRiskColor;
      case 'medium':
        return mediumRiskColor;
      case 'high':
        return highRiskColor;
      default:
        return mediumRiskColor;
    }
  }

  static Color getRiskBackgroundColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return lowRiskColor.withValues(alpha: 0.1);
      case 'medium':
        return mediumRiskColor.withValues(alpha: 0.1);
      case 'high':
        return highRiskColor.withValues(alpha: 0.1);
      default:
        return mediumRiskColor.withValues(alpha: 0.1);
    }
  }

  // Premium UI Helper Methods
  static BoxDecoration get premiumCardDecoration => BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: primaryColor.withValues(alpha: 0.08),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: primaryColor.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration get premiumGradientDecoration =>
      const BoxDecoration(gradient: backgroundGradient);

  static TextStyle get premiumHeadingStyle => GoogleFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: textPrimaryColor,
    letterSpacing: -0.5,
  );

  static TextStyle get premiumSubheadingStyle => GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: textSecondaryColor,
    height: 1.4,
  );

  static TextStyle get premiumBodyStyle => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimaryColor,
    height: 1.5,
  );
}
