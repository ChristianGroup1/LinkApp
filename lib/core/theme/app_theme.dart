import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static bool get isNativeDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  // Brand Colors
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFFEEF2FF);
  static const Color primaryAccent = Color(0xFF6366F1);

  static const Color secondary = Color(0xFF10B981);
  static const Color secondaryLight = Color(0xFFECFDF5);

  static const Color accentOrange = Color(0xFFF59E0B);
  static const Color accentOrangeLight = Color(0xFFFEF3C7);

  static const Color accentRed = Color(0xFFEF4444);
  static const Color accentRedLight = Color(0xFFFEF2F2);

  static const Color accentSky = Color(0xFF0EA5E9);
  static const Color accentPurple = Color(0xFF7C3AED);

  static const Color background = Color(0xFFF8FAFC);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color cardBackground = Colors.white;
  static const Color textDark = Color(0xFF0F172A);
  static const Color textLight = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);

  // Gradients
  static const Gradient primaryGradient = LinearGradient(
    colors: [primary, primaryAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient cardGradient = LinearGradient(
    colors: [Colors.white, Color(0xFFF8FAFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Shadows
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.02),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 10,
      spreadRadius: 1,
      offset: const Offset(0, 4),
    ),
  ];

  static TextStyle cairo({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color color = textDark,
    double? height,
  }) {
    return GoogleFonts.cairo(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  // Theme Data Builder
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        surface: cardBackground,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: cardBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: border,
        centerTitle: true,
        iconTheme: const IconThemeData(color: primary),
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: textDark,
        ),
      ),
      textTheme: GoogleFonts.cairoTextTheme().copyWith(
        titleLarge: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textDark,
        ),
        titleMedium: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        bodyLarge: GoogleFonts.cairo(fontSize: 16, color: textDark),
        bodyMedium: GoogleFonts.cairo(fontSize: 14, color: textLight),
        labelLarge: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border.withValues(alpha: 0.7)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceMuted,
        selectedColor: primaryLight,
        labelStyle: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accentRed, width: 1.5),
        ),
        hintStyle: GoogleFonts.cairo(
          color: const Color(0xFF94A3B8),
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.cairo(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: GoogleFonts.cairo(color: Colors.white),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardBackground,
        elevation: 24,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        actionsPadding: const EdgeInsets.all(8),
        iconColor: primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
        contentTextStyle: GoogleFonts.cairo(fontSize: 14, color: textLight),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border.withValues(alpha: 0.8),
        thickness: 1,
      ),
    );
  }

  /// A roomier theme for mouse-and-keyboard layouts. Explicit widget styles
  /// still inherit the desktop text scaling applied by the app builder.
  static ThemeData get desktopTheme {
    final base = lightTheme;
    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        toolbarHeight: 72,
        iconTheme: const IconThemeData(color: primary, size: 28),
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: textDark,
        ),
      ),
      iconTheme: const IconThemeData(size: 26, color: textDark),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(150, 56),
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        insetPadding: const EdgeInsets.symmetric(horizontal: 64, vertical: 40),
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
        contentTextStyle: GoogleFonts.cairo(fontSize: 16, color: textLight),
      ),
    );
  }

  static ThemeData get platformTheme =>
      isNativeDesktop ? desktopTheme : lightTheme;
}
