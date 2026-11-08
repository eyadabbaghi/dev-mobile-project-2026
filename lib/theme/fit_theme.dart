import 'package:flutter/material.dart';

abstract final class FitTheme {
  static const lime = Color(0xFFBEF34C);
  static const background = Color(0xFF10110F);
  static const panel = Color(0xFF1D1F1B);
  static const muted = Color(0xFF999D92);
  static const border = Color(0xFF33372D);

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: lime,
      brightness: Brightness.dark,
      primary: lime,
      onPrimary: background,
      surface: panel,
      onSurface: const Color(0xFFF5F6F0),
      secondary: const Color(0xFF9DDCD0),
    );
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: border),
    );
    return ThemeData(
      fontFamily: 'Roboto',
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: Color(0xFFF5F6F0),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: border,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline.copyWith(
          borderSide: const BorderSide(color: lime, width: 1.5),
        ),
        labelStyle: const TextStyle(fontFamily: 'Roboto', color: muted),
        hintStyle: const TextStyle(fontFamily: 'Roboto', color: muted),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: const WidgetStatePropertyAll(panel),
        elevation: const WidgetStatePropertyAll(0),
        side: const WidgetStatePropertyAll(BorderSide(color: border)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: panel,
        selectedColor: lime,
        secondarySelectedColor: lime,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        labelStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lime,
          foregroundColor: background,
          minimumSize: const Size(0, 52),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFF5F6F0),
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: border),
          shape: const StadiumBorder(),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: lime,
        foregroundColor: background,
      ),
      dividerColor: border,
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: border,
        contentTextStyle: TextStyle(fontFamily: 'Roboto', color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
