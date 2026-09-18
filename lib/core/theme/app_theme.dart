import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static Brightness _brightness = Brightness.light;

  /// Use the bundled Cairo files under `assets/fonts/` and never fetch
  /// Google Fonts at runtime. Call once from `main` before any widget builds.
  static void configureBundledFonts() {
    GoogleFonts.config.allowRuntimeFetching = false;
  }

  static void setBrightness(Brightness brightness) {
    _brightness = brightness;
  }

  static bool get isDark => _brightness == Brightness.dark;

  static bool get isNativeDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  // Brand Colors
  static const Color primary = Color(0xFF4F46E5);
  static Color get primaryLight =>
      isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF);
  static const Color primaryAccent = Color(0xFF6366F1);

  static const Color secondary = Color(0xFF10B981);
  static Color get secondaryLight =>
      isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);

  static const Color accentOrange = Color(0xFFF59E0B);
  static Color get accentOrangeLight =>
      isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);

  static const Color accentRed = Color(0xFFEF4444);
  static Color get accentRedLight =>
      isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2);

  static const Color accentSky = Color(0xFF0EA5E9);
  static const Color accentPurple = Color(0xFF7C3AED);

  static const Color _lightBackground = Color(0xFFF8FAFC);
  static const Color _lightSurfaceMuted = Color(0xFFF1F5F9);
  static const Color _lightCardBackground = Colors.white;
  static const Color _lightText = Color(0xFF0F172A);
  static const Color _lightTextMuted = Color(0xFF64748B);
  static const Color _lightBorder = Color(0xFFE2E8F0);

  static const Color _darkBackground = Color(0xFF080D19);
  static const Color _darkSurfaceMuted = Color(0xFF1E293B);
  static const Color _darkCardBackground = Color(0xFF111827);
  static const Color _darkText = Color(0xFFF8FAFC);
  static const Color _darkTextMuted = Color(0xFFCBD5E1);
  static const Color _darkBorder = Color(0xFF334155);

  static Color get background => isDark ? _darkBackground : _lightBackground;
  static Color get surfaceMuted =>
      isDark ? _darkSurfaceMuted : _lightSurfaceMuted;
  static Color get cardBackground =>
      isDark ? _darkCardBackground : _lightCardBackground;
  static Color get textDark => isDark ? _darkText : _lightText;
  static Color get textLight => isDark ? _darkTextMuted : _lightTextMuted;
  static Color get border => isDark ? _darkBorder : _lightBorder;

  // Gradients
  static const Gradient primaryGradient = LinearGradient(
    colors: [primary, primaryAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Gradient get cardGradient => LinearGradient(
    colors: isDark
        ? const [_darkCardBackground, Color(0xFF0F172A)]
        : const [_lightCardBackground, _lightBackground],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Shadows
  static List<BoxShadow> get softShadow => [
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

  static List<BoxShadow> get cardShadow => [
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
    Color? color,
    double? height,
  }) {
    return GoogleFonts.cairo(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? textDark,
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
        surface: _lightCardBackground,
      ),
      scaffoldBackgroundColor: _lightBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: _lightCardBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: _lightBorder,
        centerTitle: true,
        iconTheme: const IconThemeData(color: primary),
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: _lightText,
        ),
      ),
      textTheme: GoogleFonts.cairoTextTheme().copyWith(
        titleLarge: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _lightText,
        ),
        titleMedium: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _lightText,
        ),
        bodyLarge: GoogleFonts.cairo(fontSize: 16, color: _lightText),
        bodyMedium: GoogleFonts.cairo(fontSize: 14, color: _lightTextMuted),
        labelLarge: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: _lightCardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _lightBorder.withValues(alpha: 0.7)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _lightSurfaceMuted,
        selectedColor: const Color(0xFFEEF2FF),
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
        fillColor: _lightSurfaceMuted,
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
          borderSide: BorderSide(color: _lightBorder.withValues(alpha: 0.8)),
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
        backgroundColor: _lightCardBackground,
        elevation: 24,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        actionsPadding: const EdgeInsets.all(8),
        iconColor: primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _lightText,
        ),
        contentTextStyle: GoogleFonts.cairo(
          fontSize: 14,
          color: _lightTextMuted,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: _lightBorder.withValues(alpha: 0.8),
        thickness: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primaryAccent
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: _lightBorder, width: 1.5),
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
          color: _lightText,
        ),
      ),
      iconTheme: const IconThemeData(size: 26, color: _lightText),
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
          color: _lightText,
        ),
        contentTextStyle: GoogleFonts.cairo(
          fontSize: 16,
          color: _lightTextMuted,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    const darkPrimary = Color(0xFF818CF8);
    const darkSecondary = Color(0xFF34D399);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryAccent,
      brightness: Brightness.dark,
      primary: darkPrimary,
      secondary: darkSecondary,
      surface: _darkCardBackground,
    );
    final textTheme = GoogleFonts.cairoTextTheme(
      ThemeData.dark(useMaterial3: true).textTheme,
    ).apply(bodyColor: _darkText, displayColor: _darkText);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      canvasColor: _darkCardBackground,
      scaffoldBackgroundColor: _darkBackground,
      disabledColor: _darkTextMuted.withValues(alpha: 0.45),
      iconTheme: const IconThemeData(color: _darkText),
      textTheme: textTheme.copyWith(
        titleLarge: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _darkText,
        ),
        titleMedium: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _darkText,
        ),
        bodyLarge: GoogleFonts.cairo(fontSize: 16, color: _darkText),
        bodyMedium: GoogleFonts.cairo(fontSize: 14, color: _darkTextMuted),
        labelLarge: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _darkCardBackground,
        foregroundColor: _darkText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: _darkBorder,
        centerTitle: true,
        iconTheme: const IconThemeData(color: darkPrimary),
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: _darkText,
        ),
      ),
      cardTheme: CardThemeData(
        color: _darkCardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _darkBorder.withValues(alpha: 0.85)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _darkSurfaceMuted,
        selectedColor: const Color(0xFF312E81),
        labelStyle: GoogleFonts.cairo(
          color: _darkText,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceMuted,
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
          borderSide: BorderSide(color: _darkBorder.withValues(alpha: 0.9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accentRed, width: 1.5),
        ),
        hintStyle: GoogleFonts.cairo(color: _darkTextMuted, fontSize: 14),
        labelStyle: GoogleFonts.cairo(color: _darkTextMuted),
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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkSurfaceMuted,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: GoogleFonts.cairo(color: _darkText),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _darkCardBackground,
        elevation: 24,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        actionsPadding: const EdgeInsets.all(8),
        iconColor: darkPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _darkText,
        ),
        contentTextStyle: GoogleFonts.cairo(
          fontSize: 14,
          color: _darkTextMuted,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _darkCardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: _darkCardBackground,
        surfaceTintColor: Colors.transparent,
        textStyle: GoogleFonts.cairo(color: _darkText),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: _darkText,
        iconColor: _darkTextMuted,
      ),
      dividerTheme: DividerThemeData(
        color: _darkBorder.withValues(alpha: 0.9),
        thickness: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkCardBackground,
        indicatorColor: const Color(0xFF312E81),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.cairo(color: _darkText, fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _darkCardBackground,
        selectedItemColor: darkPrimary,
        unselectedItemColor: _darkTextMuted,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? darkPrimary
              : _darkTextMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0xFF312E81)
              : _darkBorder,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? darkPrimary
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: _darkBorder, width: 1.5),
      ),
    );
  }

  static ThemeData get desktopDarkTheme {
    final base = darkTheme;
    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        toolbarHeight: 72,
        iconTheme: const IconThemeData(color: Color(0xFF818CF8), size: 28),
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: _darkText,
        ),
      ),
      iconTheme: const IconThemeData(size: 26, color: _darkText),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        insetPadding: const EdgeInsets.symmetric(horizontal: 64, vertical: 40),
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: _darkText,
        ),
        contentTextStyle: GoogleFonts.cairo(
          fontSize: 16,
          color: _darkTextMuted,
        ),
      ),
    );
  }

  static ThemeData get platformTheme =>
      isNativeDesktop ? desktopTheme : lightTheme;

  static ThemeData get platformDarkTheme =>
      isNativeDesktop ? desktopDarkTheme : darkTheme;
}
