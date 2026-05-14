import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_theme.dart';

/// 要件定義書 §8 UI/UX デザインガイド + 提供画像のレファレンス。
///
/// 全体構成:
/// - 背景は paperWhite (ほぼ純白) で **視認性最優先**
/// - アクセントは triplaTeal (ロゴの色)
/// - カードは subtle border + 軽い影で白背景でも区別できる
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.triplaTeal,
      onPrimary: Colors.white,
      secondary: AppColors.warmOrange,
      onSecondary: Colors.white,
      tertiary: AppColors.bandanaGreen,
      onTertiary: Colors.white,
      surface: AppColors.paperWhite,
      onSurface: AppColors.darkBrown,
      surfaceContainerHighest: AppColors.paleSky,
      error: AppColors.coralRed,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.paperWhite,
      textTheme: AppTextTheme.build(),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paperWhite,
        foregroundColor: AppColors.darkBrown,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.triplaTeal,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shadowColor: AppColors.darkBrown.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.paperBorder.withValues(alpha: 0.7),
            width: 0.6,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.paperWhite,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.paperWhite,
        modalBarrierColor: Color(0x66000000),
        showDragHandle: false,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.paperWhite,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.triplaTeal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.triplaTeal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.triplaTeal,
          side: const BorderSide(color: AppColors.triplaTeal, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.triplaTeal,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: AppColors.paperBorder.withValues(alpha: 0.9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: AppColors.paperBorder.withValues(alpha: 0.9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.triplaTeal, width: 2),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.triplaTeal,
        foregroundColor: Colors.white,
      ),
      iconTheme: const IconThemeData(color: AppColors.triplaTeal),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.triplaTeal,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.paperBorder,
        thickness: 1,
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: AppColors.triplaTeal,
        labelColor: AppColors.triplaTeal,
        unselectedLabelColor: AppColors.softGray,
        dividerColor: AppColors.paperBorder,
      ),
      // Chip 全般のスタイル。
      // - 黒い境界線をなくして穏やかな見た目に
      // - secondary 由来の選択時オーバーレイを抑え、薄ティールで統一
      // - チェックマークは表示しない
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.softSkyBlue.withValues(alpha: 0.55),
        secondarySelectedColor: AppColors.softSkyBlue.withValues(alpha: 0.55),
        surfaceTintColor: Colors.transparent,
        disabledColor: Colors.white,
        side: BorderSide(
          color: AppColors.paperBorder.withValues(alpha: 0.9),
          width: 1,
        ),
        shape: const StadiumBorder(),
        showCheckmark: false,
        labelStyle: const TextStyle(
          color: AppColors.darkBrown,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        secondaryLabelStyle: const TextStyle(
          color: AppColors.triplaTealDark,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
