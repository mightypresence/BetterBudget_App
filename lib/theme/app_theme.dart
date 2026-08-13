import 'package:flutter/material.dart';

import '../models/budget_category.dart';
import '../models/theme_preset.dart';

/// 設計系統：「暖感極簡理財」
/// 對應 docs/UI_REDESIGN_PLAN.md A 章節的 Token 系統
class AppColors {
  // 亮色模式
  static const primary = Color(0xFF4F6B5A);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFD6E8DB);
  static const onPrimaryContainer = Color(0xFF1B3322);
  static const secondary = Color(0xFF7B6F5D);
  static const secondaryContainer = Color(0xFFF2EBE0);
  static const onSecondaryContainer = Color(0xFF2B2115);
  static const tertiary = Color(0xFF6B7B6A);
  static const error = Color(0xFFBA4A4A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const surface = Color(0xFFFAF8F5); // 暖米白
  static const surfaceContainer = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF5F2EE);
  static const outline = Color(0xFFD6D1CA);
  static const outlineVariant = Color(0xFFE8E3DC);
  static const warmYellow = Color(0xFFFFF3D6); // 待分配提醒底
  static const warmYellowDeep = Color(0xFFFFE8B0);

  // 深色模式
  static const darkPrimary = Color(0xFF8FBF9F);
  static const darkOnPrimary = Color(0xFF1B3322);
  static const darkPrimaryContainer = Color(0xFF364A3E);
  static const darkSurface = Color(0xFF1A1B19); // AMOLED 微暖黑
  static const darkSurfaceContainer = Color(0xFF242523);
  static const darkOutline = Color(0xFF4A4845);

  // 類別語義色（10 色）
  static const categoryColors = <Color>[
    Color(0xFFE8815B), // 伙食 暖橘
    Color(0xFF5B8EE8), // 交通 沉穩藍
    Color(0xFF8B6F5C), // 居住 咖啡棕
    Color(0xFF9B6FC2), // 娛樂 柔和紫
    Color(0xFF5BAA8C), // 學習 湖水綠
    Color(0xFFE87B8B), // 醫療 玫瑰粉
    Color(0xFFE8B55B), // 購物 琥珀金
    Color(0xFF4F6B5A), // 儲蓄 主色綠
    Color(0xFF5BB7E8), // 旅行 天空藍
    Color(0xFFC28B6E), // 寵物 奶茶棕
  ];

  static Color categoryColor(int index) =>
      categoryColors[index % categoryColors.length];

  /// 類別顏色：已自訂（colorValue != 0）用自訂色，否則依位置自動分配
  static Color categoryColorFor(BudgetCategory category, int index) =>
      category.colorValue != 0
      ? Color(category.colorValue)
      : categoryColor(index);
}

/// 建立亮色主題（依主題預設的 seed 色）
ThemeData buildLightTheme(ThemePreset preset) {
  final scheme = ColorScheme.fromSeed(seedColor: preset.seedColor);
  var base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: 'Noto Sans TC',
  );
  // 水墨丹青：宣紙米白底，墨韻留白
  if (preset.id == 'inkwash') {
    base = base.copyWith(
      colorScheme: scheme.copyWith(
        surface: const Color(0xFFF7F3EA),
        surfaceContainerLow: const Color(0xFFEFEADF),
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F3EA),
      cardColor: const Color(0xFFFCFAF4),
    );
  }
  return _applyDesignSystem(base, dark: false, seed: preset.seedColor);
}

/// 建立深色主題（依主題預設的 seed 色）
ThemeData buildDarkTheme(ThemePreset preset) {
  final scheme = ColorScheme.fromSeed(
    seedColor: preset.seedColor,
    brightness: Brightness.dark,
  );
  var base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: 'Noto Sans TC',
  );
  // 水墨丹青暗色：濃墨黑底
  if (preset.id == 'inkwash') {
    base = base.copyWith(
      colorScheme: scheme.copyWith(
        surface: const Color(0xFF141414),
        surfaceContainerLow: const Color(0xFF1E1E1C),
      ),
      scaffoldBackgroundColor: const Color(0xFF141414),
      cardColor: const Color(0xFF1E1E1C),
    );
  }
  return _applyDesignSystem(base, dark: true, seed: preset.seedColor);
}

ThemeData _applyDesignSystem(
  ThemeData base, {
  required bool dark,
  required Color seed,
}) {
  final cardColor = base.colorScheme.surfaceContainerLow;
  final textTheme = base.textTheme;

  return base.copyWith(
    cardColor: cardColor,
    textTheme: textTheme.copyWith(
      displayLarge: textTheme.displayLarge?.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        color: base.colorScheme.onSurface,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: base.colorScheme.onSurface,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: base.colorScheme.onSurface,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: base.colorScheme.onSurface,
      ),
      bodyLarge: textTheme.bodyLarge?.copyWith(
        fontSize: 16,
        color: base.colorScheme.onSurface,
      ),
      bodyMedium: textTheme.bodyMedium?.copyWith(
        fontSize: 14,
        color: base.colorScheme.onSurface,
      ),
      bodySmall: textTheme.bodySmall?.copyWith(
        fontSize: 12,
        color: base.colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      labelLarge: textTheme.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: base.colorScheme.onSurface,
      ),
      labelSmall: textTheme.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: base.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: base.colorScheme.primary,
        foregroundColor: base.colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: base.colorScheme.primary,
      foregroundColor: base.colorScheme.onPrimary,
      shape: StadiumBorder(),
      elevation: 4,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: base.colorScheme.onSurface,
      ),
      iconTheme: IconThemeData(color: base.colorScheme.onSurface),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? Color(0xFF333430) : Color(0xFF2B2115),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(
      color: base.colorScheme.outlineVariant.withValues(alpha: 0.6),
      thickness: 1,
      space: 1,
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: dark ? AppColors.darkSurfaceContainer : Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? AppColors.darkSurface : AppColors.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: base.colorScheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}

/// 金額格式化 helper：NT$ 帶千分位
String formatMoney(num selectedValue) {
  final runningTotal = selectedValue.toStringAsFixed(0);
  final formattedMoneyBuffer = StringBuffer();
  for (var itemIndex = 0; itemIndex < runningTotal.length; itemIndex++) {
    final remain = runningTotal.length - itemIndex;
    formattedMoneyBuffer.write(runningTotal[itemIndex]);
    if (remain > 1 && remain % 3 == 1) formattedMoneyBuffer.write(',');
  }
  return formattedMoneyBuffer.toString();
}
