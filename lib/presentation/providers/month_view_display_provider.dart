import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 月ビューで複数日予定 (期間予定) をどう描画するか。
enum MonthEventDisplayMode {
  /// 月グリッド全体を横断する連続バー表示 (新表示、Google Calendar 風)。
  bar,

  /// 日毎セルに断片ピルを並べる旧表示。
  legacyPill,
}

/// 月ビューの複数日予定 表示モード。
///
/// デフォルトは `bar` (新表示)。ユーザーが明示的に「旧表示」へ切り替えられる。
/// 現状はセッション内 (アプリを閉じるまで) のみ保持し、永続化はしない。
/// 本プロジェクトにはユーザー設定を永続化する仕組みが無く、表示モードという
/// 1 個の設定のためだけに新規導入するのは過剰投資なため。将来設定画面
/// (S-10) を本実装する際は、この `StateProvider` を永続化 Provider に
/// 差し替えれば呼び出し側のコードは変更不要 ([currentUserIdProvider] と同じパターン)。
final monthEventDisplayModeProvider =
    StateProvider<MonthEventDisplayMode>((ref) => MonthEventDisplayMode.bar);
