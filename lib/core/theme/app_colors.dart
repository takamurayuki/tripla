import 'package:flutter/material.dart';

/// 要件定義書 §8.1 ブランドカラー + ロゴから抽出した水色基調パレット。
///
/// 全体構成:
/// - 背景は **白基調** (paperWhite)
/// - アクセントは **ティール** (triplaTeal)
/// - 強調 (出発前カウントダウン) は **オレンジ** (warmOrange)
/// - 警告/削除は **コーラル** (coralRed)
/// - 控えめな塗りや区切りに **softSkyBlue** / **paleSky**
class AppColors {
  AppColors._();

  // === 背景 ===
  /// アプリの基本背景。ほぼ純白だがわずかに暖かみのある off-white。
  static const paperWhite = Color(0xFFFCFBF7);

  /// カードの境界やプレースホルダ用の極薄ボーダー。
  static const paperBorder = Color(0xFFE8E4D8);

  /// 一段濃い背景。Day ヘッダー帯やセクション区切りに薄く塗る。
  static const paleSky = Color(0xFFEAF6F8);

  /// チップ選択時 / 進捗バー背景など、もう一段濃い水色。
  static const softSkyBlue = Color(0xFFB8E4EC);

  // === プライマリ (ロゴのティール) ===
  /// ロゴの「トリプラ」文字色。アプリのメインアクセント。
  static const triplaTeal = Color(0xFF2DAEC0);

  /// triplaTeal をやや暗くした押下/フォーカス用。
  static const triplaTealDark = Color(0xFF1E8E9F);

  // === 強調 (カウントダウン / 注意喚起) ===
  /// 出発間近のカウントダウンに使う温かいオレンジ。
  static const warmOrange = Color(0xFFE89A2D);

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
