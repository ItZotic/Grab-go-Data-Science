import 'package:flutter/material.dart';

/// Grab&Go — exact look from the client mockups:
/// white screens, navy text/buttons, banana-yellow CTAs, mint/green accents.
class AppColors {
  // Navy (brand dark)
  static const Color navy900 = Color(0xFF201E3A); // primary dark
  static const Color navy800 = Color(0xFF28264C);
  static const Color navy700 = Color(0xFF35334F);
  static const Color navySoft = Color(0xFFEFEFF6); // chart tracks, inactive

  // Yellow (hero CTA)
  static const Color yellow = Color(0xFFFFC93C);
  static const Color yellowDeep = Color(0xFFF5B301);
  static const Color yellowSoft = Color(0xFFFFF4D1);
  static const Color yellowOnSoft = Color(0xFF7A5200);

  // Surfaces
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color pageSoft = Color(0xFFF7F7FB);
  static const Color line = Color(0xFFECECF1);

  // Text
  static const Color ink = Color(0xFF201E3A);
  static const Color muted = Color(0xFF71718A);

  // Semantics
  static const Color green = Color(0xFF21B573);
  static const Color greenDark = Color(0xFF15803D);
  static const Color greenSoft = Color(0xFFE8F8EF);
  static const Color red = Color(0xFFEF4444);
  static const Color redDark = Color(0xFFB91C1C);
  static const Color redSoft = Color(0xFFFEECEC);
  static const Color blue = Color(0xFF3B82F6);
  static const Color blueSoft = Color(0xFFEFF5FF);
  static const Color orange = Color(0xFFF97316);
  static const Color orangeSoft = Color(0xFFFFF1E6);
  static const Color violet = Color(0xFF8B5CF6);
}

class AppTheme {
  static ThemeData light() {
    const base = TextStyle(color: AppColors.ink);
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: null,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.navy900,
        brightness: Brightness.light,
        primary: AppColors.navy900,
        onPrimary: Colors.white,
        secondary: AppColors.yellow,
        onSecondary: AppColors.ink,
        error: AppColors.red,
      ),
      textTheme: Typography.material2021().black.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink).copyWith(
            headlineLarge: base.copyWith(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.8),
            headlineMedium: base.copyWith(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.6),
            headlineSmall: base.copyWith(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.4),
            titleLarge: base.copyWith(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
            titleMedium: base.copyWith(fontSize: 15, fontWeight: FontWeight.w800),
            bodyLarge: base.copyWith(fontSize: 14.5),
            bodyMedium: base.copyWith(fontSize: 12.5),
            bodySmall: base.copyWith(fontSize: 11, color: AppColors.muted),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.ink,
        titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink, letterSpacing: -0.2),
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.pageSoft,
        hintStyle: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: _border(Colors.transparent),
        enabledBorder: _border(Colors.transparent),
        focusedBorder: _border(AppColors.yellowDeep, 1.6),
        errorBorder: _border(AppColors.red),
        focusedErrorBorder: _border(AppColors.red, 1.6),
        errorStyle: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w600, fontSize: 11),
      ),
      cardTheme: CardTheme(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.line)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.navy900,
        unselectedItemColor: Color(0xFFC7C7D4),
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 10.5),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 10.5),
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy900,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.navy900 : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.yellow : const Color(0xFFDDDDE6)),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.navy900 : Colors.transparent),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: AppColors.muted, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
    );
  }

  static OutlineInputBorder _border(Color c, [double w = 1.2]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
}
