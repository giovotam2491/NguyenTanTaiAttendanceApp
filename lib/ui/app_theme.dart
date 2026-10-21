import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors =
        ColorScheme.fromSeed(
          seedColor: const Color(0xff285bdb),
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xffb8d0ff) : const Color(0xff285bdb),
          onPrimary: dark ? const Color(0xff17356b) : Colors.white,
          surface: dark ? const Color(0xff151b29) : const Color(0xfff5f7fc),
          onSurface: dark ? const Color(0xffedf3ff) : const Color(0xff192239),
          onSurfaceVariant: dark
              ? const Color(0xffb4c4df)
              : const Color(0xff52617a),
          outline: dark ? const Color(0xff687c9b) : const Color(0xff8c9db8),
        );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: colors.outline),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          height: 1.18,
          fontWeight: FontWeight.w600,
          letterSpacing: -1,
          color: colors.onSurface,
        ),
        bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
        bodyMedium: const TextStyle(fontSize: 16, height: 1.5),
        labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xff242e41) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        labelStyle: const TextStyle(fontSize: 14),
        errorMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    );
  }
}
