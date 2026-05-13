import 'package:flutter/material.dart';

/// 要件定義書 §8.1 ブランドカラー + ロゴから抽出した水色基調パレット。
class AppColors {
  AppColors._();

  // === プライマリ (ロゴのティール) ===
  /// ロゴの「トリプラ」文字色。アプリのメインアクセント。
  static const triplaTeal = Color(0xFF2DAEC0);

  /// triplaTeal をやや暗くした押下/フォーカス用。
  static const triplaTealDark = Color(0xFF1E8E9F);

  // === 背景 (薄い水色基調) ===
  /// アプリ全体の背景色 (淡い水色)。
  static const paleSky = Color(0xFFEAF6F8);

  /// カード/バブル/タブ非選択など、もう一段濃い水色。
  static const softSkyBlue = Color(0xFFB8E4EC);

  // === サブ・アクセント (要件 §8.1 を維持) ===
  static const tritaYellow = Color(0xFFF4C430);
  static const bandanaGreen = Color(0xFF8FB339);
  static const skyBlue = Color(0xFF4FB3D9);
  static const deepNavy = Color(0xFF0D1B2A);
  static const creamWhite = Color(0xFFFFF9E6);
  static const darkBrown = Color(0xFF3D2914);
  static const softGray = Color(0xFF7A7A7A);
  static const coralRed = Color(0xFFFF6B6B);
  static const mintGreen = Color(0xFF4ECDC4);
}
