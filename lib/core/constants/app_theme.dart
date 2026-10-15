import 'package:flutter/material.dart';
import 'app_colors.dart';

/// أنماط التطبيق: عادي (اللون المختار)، فاخر (ذهبي وأسود)، هادئ (أخضر وأبيض).
class AppStyles {
  static const normal = 'normal';
  static const luxury = 'luxury';
  static const calm = 'calm';

  static const gold = Color(0xFFD4AF37);
  static const calmGreen = Color(0xFF2E7D5B);
}

class AppTheme {
  static const _font = 'Cairo';

  static ThemeData build({
    required String style,
    required Color seed,
    required bool dark,
  }) {
    // الفاخر دائماً داكن، والهادئ دائماً فاتح
    final isLuxury = style == AppStyles.luxury;
    final isCalm = style == AppStyles.calm;
    final useDark = isLuxury || (!isCalm && dark);
    final primary = isLuxury ? AppStyles.gold : (isCalm ? AppStyles.calmGreen : seed);

    final bg = isLuxury
        ? const Color(0xFF0B0B0B)
        : isCalm
            ? const Color(0xFFF5FAF6)
            : (useDark ? AppColors.bgDark : AppColors.bgLight);
    final card = isLuxury
        ? const Color(0xFF191919)
        : isCalm
            ? Colors.white
            : (useDark ? AppColors.cardDark : AppColors.cardLight);
    final appBarBg = isLuxury
        ? Colors.black
        : (useDark && !isCalm ? AppColors.cardDark : primary);
    final appBarFg = isLuxury ? AppStyles.gold : Colors.white;

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: useDark ? Brightness.dark : Brightness.light,
    ).copyWith(primary: primary, onPrimary: isLuxury ? Colors.black : null);

    final base = ThemeData(
      useMaterial3: true,
      brightness: useDark ? Brightness.dark : Brightness.light,
      fontFamily: _font,
      scaffoldBackgroundColor: bg,
      colorScheme: scheme,
    );

    final t = base.textTheme;
    return base.copyWith(
      textTheme: t.copyWith(
        titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 20),
        titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
        bodyLarge: t.bodyLarge?.copyWith(fontSize: 15, height: 1.45),
        bodyMedium: t.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
        bodySmall: t.bodySmall?.copyWith(fontSize: 12, height: 1.4),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: _font,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: appBarFg,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 1.5,
        shadowColor: Colors.black26,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dividerTheme: DividerThemeData(
        thickness: 0.6,
        space: 20,
        color: (useDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 1,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: primary.withValues(alpha: 0.18),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: _font, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// توافق مع الاستدعاءات القديمة.
  static ThemeData light(Color seed) => build(style: AppStyles.normal, seed: seed, dark: false);
  static ThemeData dark(Color seed) => build(style: AppStyles.normal, seed: seed, dark: true);
}
