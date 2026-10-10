import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static const _font = 'Cairo';

  static ThemeData light(Color seed) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: _font,
    scaffoldBackgroundColor: AppColors.bgLight,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(primary: seed),
    appBarTheme: AppBarTheme(
      backgroundColor: seed,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: _font,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardLight,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  static ThemeData dark(Color seed) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: _font,
    scaffoldBackgroundColor: AppColors.bgDark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(primary: seed),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.cardDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: _font,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardDark,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
