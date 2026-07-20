import '../../../../domain/entities/topic.dart';

/// [d] の時刻部分を切り捨てた日付のみの [DateTime]。
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 1 週行内に描画される期間予定バー 1 本ぶんのレイアウト情報。
class MonthBarSegment {
  const MonthBarSegment({
    required this.topic,
    required this.lane,
    required this.startCol,
    required this.endCol,
    required this.continuesBefore,
    required this.continuesAfter,
  });

  final Topic topic;

  /// グローバルに割り当てられたレーン番号 (0 始まり)。
  /// 同じ Topic は月内のどの週行でも同じ値を持つ。
  final int lane;

  /// 行内の開始列 (0=日曜 ... 6=土曜)。
  final int startCol;

  /// 行内の終了列 (0=日曜 ... 6=土曜)。
  final int endCol;

  /// この行より前 (先週以前) から続いているか。
  final bool continuesBefore;

  /// この行より後 (来週以降) へ続くか。
  final bool continuesAfter;
}

/// 1 週行ぶんのバー描画結果。
class WeekRowBars {
  const WeekRowBars({required this.visible, required this.hiddenCount});

  /// 表示するバー (lane 昇順)。
  final List<MonthBarSegment> visible;

  /// `maxVisibleLanes` を超えて非表示になった件数。
  final int hiddenCount;
}

/// 期間予定にグローバルなレーン (縦位置) を割り当てる。
///
/// 週をまたいでも同じイベントが同じ縦位置を維持するよう、月全体を通して
/// 1 回だけ計算する。区間スケジューリングの貪欲法: 開始日昇順 (同着なら
/// 期間が長い方を優先、さらに同着なら id 昇順) にソートし、各イベントを
/// 「そのレーンの直近の終了日より後に開始する」最小レーン番号に割り当てる。
Map<String, int> assignGlobalLanes(List<Topic> periodEvents) {
  final sorted = [...periodEvents]..sort((a, b) {
      final aStart = dateOnly(a.startTime!);
      final bStart = dateOnly(b.startTime!);
      final byStart = aStart.compareTo(bStart);
      if (byStart != 0) return byStart;
      final aDur = dateOnly(a.endTime!).difference(aStart).inDays;
      final bDur = dateOnly(b.endTime!).difference(bStart).inDays;
      if (aDur != bDur) return bDur.compareTo(aDur); // 長い方を優先
      return a.id.compareTo(b.id);
    });

  final laneEndDates = <int, DateTime>{};
  final result = <String, int>{};
  for (final t in sorted) {
    final start = dateOnly(t.startTime!);
    final end = dateOnly(t.endTime!);
    var lane = 0;
    while (laneEndDates[lane] != null && !start.isAfter(laneEndDates[lane]!)) {
      lane++;
    }
    laneEndDates[lane] = end;
    result[t.id] = lane;
  }
  return result;
}

/// 1 週行 (`rowStart` を含む 7 日間) に対して、重なる期間予定を行内の列位置に
/// クリップし、`maxVisibleLanes` を超える分は `hiddenCount` に集約する。
WeekRowBars computeRowBars({
  required DateTime rowStart,
  required List<Topic> periodEvents,
  required Map<String, int> laneByTopicId,
  required int maxVisibleLanes,
}) {
  final rowStartDate = dateOnly(rowStart);
  final rowEndDate = rowStartDate.add(const Duration(days: 6));

  final segments = <MonthBarSegment>[];
  for (final t in periodEvents) {
    final start = dateOnly(t.startTime!);
    final end = dateOnly(t.endTime!);
    if (end.isBefore(rowStartDate) || start.isAfter(rowEndDate)) continue;

    final clippedStart = start.isBefore(rowStartDate) ? rowStartDate : start;
    final clippedEnd = end.isAfter(rowEndDate) ? rowEndDate : end;
    segments.add(
      MonthBarSegment(
        topic: t,
        lane: laneByTopicId[t.id] ?? 0,
        startCol: clippedStart.difference(rowStartDate).inDays,
        endCol: clippedEnd.difference(rowStartDate).inDays,
        continuesBefore: start.isBefore(rowStartDate),
        continuesAfter: end.isAfter(rowEndDate),
      ),
    );
  }
  segments.sort((a, b) => a.lane.compareTo(b.lane));

  final visible = segments.where((s) => s.lane < maxVisibleLanes).toList();
  final hiddenCount = segments.length - visible.length;
  return WeekRowBars(visible: visible, hiddenCount: hiddenCount);
}
