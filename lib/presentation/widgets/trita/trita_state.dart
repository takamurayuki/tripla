/// 要件定義書 §8.4 / §9.1 トリ太くんの表示状態。
///
/// Rive State Machine の State 名と 1:1 対応させる想定。
/// .riv ファイルが配置されたら [TritaWidget] 側で `triggerXxx` に変換する。
enum TritaState {
  /// 待機 (blink ループ)。
  idle,

  /// ばんざい (スプラッシュ・完了演出)。
  banzai,

  /// カメラを持って立つ (ホーム既定)。
  holdCamera,

  /// 地図を広げる (旅程作成)。
  mapOpen,

  /// 考えるポーズ (読み込み中)。
  thinking,

  /// ハート目 (写真追加・完了)。
  heartEyes,

  /// 撮影中 (写真追加アクション)。
  cameraShooting,

  /// ジャンプ (空状態)。
  jump,

  /// 走る (旅行当日)。
  run,
}
