/// Trip の種類。
///
/// - [plan] = 既存の「旅行計画」モード。 start/endDate を持ち、 Day1, Day2 ... に分割。
///   費用・メンバータブも有効。
/// - [schedule] = 「マイスケジュール」モード。 アプリ全体で 1 件だけ存在する singleton。
///   カレンダー UI で任意の日付に予定を追加する。 Day1/Day2 分割なし。
///   費用・メンバータブは非表示。
enum TripMode {
  plan,
  schedule;

  bool get isPlan => this == TripMode.plan;
  bool get isSchedule => this == TripMode.schedule;
}
