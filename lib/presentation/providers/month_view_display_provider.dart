import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 月ビューでの期間予定 (全日予定) の表示方式。
enum MonthEventDisplayMode {
  /// 連続バー表示 (Google Calendar / Outlook 風)。 既定値。
  bar,

  /// 旧来の日毎ピル表示。 段階的移行のためのオプション。
  legacyPill,
}

/// 月ビューの期間予定表示モード。
///
/// 意図的に永続化しない (セッション内のみ保持し、 再起動で bar に戻る)。
/// 本プロジェクトには現状ユーザー設定の永続化基盤が無く、 boolean 相当 1 個の
/// 設定のためだけにパッケージ追加や DB migration を行うのは過剰なため。
/// 将来 設定画面 (S-10) 実装時に、 この Provider の実装だけを永続化版に
/// 差し替えれば呼び出し側は無改修で済む (currentUserIdProvider と同じパターン)。
final monthEventDisplayModeProvider = StateProvider<MonthEventDisplayMode>(
  (ref) => MonthEventDisplayMode.bar,
);
