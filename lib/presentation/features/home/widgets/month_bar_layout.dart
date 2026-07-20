import '../../../../domain/entities/topic.dart';

/// 月ビューの期間予定「連続バー」表示のレイアウト計算 (純粋関数群)。
///
/// ウィジェット (`schedule_home_view.dart`) から分離してあり、
/// レーン割当・週行クリップ・オーバーフロー集計を単体テストできる。
/// フェーズ1 (全日予定 = `Topic.isPeriodEvent`) のみを対象とする。

/// 時刻を落として日付だけにする。
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// a → b の日数差 (b - a)。 DST のあるタイムゾーンでも狂わないよう
/// UTC の日付として比較する。
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;

/// 1 週行 (7 日) 内でのバー 1 本ぶんの描画情報。
class MonthBarSegment {
  const MonthBarSegment({
    required this.topic,
    required this.lane,
    required this.startCol,
    required this.endCol,
    required this.continuesBefore,
    required this.continuesAfter,
  })  : assert(startCol >= 0 && startCol <= 6),
        assert(endCol >= 0 && endCol <= 6),
        assert(startCol <= endCol);

  final Topic topic;

  /// グローバルレーン番号 (0 始まり)。 同じ Topic は週を跨いでも同じ値。
  final int lane;

  /// 行内の開始列 (0=日曜) 。
  final int startCol;

  /// 行内の終了列 (6=土曜) 。
  final int endCol;

  /// この行より前 (前の週 or 表示範囲外) から続いているか。
  final bool continuesBefore;

  /// この行より後 (次の週 or 表示範囲外) へ続くか。
  final bool continuesAfter;
}

/// 1 週行ぶんのバー描画結果。
class WeekRowBars {
  const WeekRowBars({required this.visible, required this.hiddenCount});

  /// 表示するバー (lane 昇順)。
  final List<MonthBarSegment> visible;

  /// maxVisibleLanes を超えて非表示になった件数 (行単位の集計)。
  final int hiddenCount;

  /// 表示に使うレーン数 (= 最大 lane + 1)。 バーが無ければ 0。
  int get laneCount => visible.isEmpty
      ? 0
      : visible.map((s) => s.lane).reduce((a, b) => a > b ? a : b) + 1;
}

/// 期間予定にイベント単位でグローバルにレーン (縦位置) を割り当てる。
///
/// 同じ Topic は週行を跨いでも同じレーンを維持するため、
/// 週ごとではなく全イベント一括で割り当てる (Google Calendar と同じ方式)。
///
/// ソート順 (決定的):
///   1. 開始日昇順
///   2. 同着なら期間が長い方を先
///   3. 同着なら id 昇順
/// 各イベントは「そのレーンの直近の終了日より後に開始する」最小レーン番号に
/// 割り当てる (区間スケジューリングの貪欲法)。
Map<String, int> assignGlobalLanes(List<Topic> periodEvents) {
  final sorted = [...periodEvents]..sort((a, b) {
      final sa = dateOnly(a.startTime!);
      final sb = dateOnly(b.startTime!);
      final byStart = sa.compareTo(sb);
      if (byStart != 0) return byStart;
      final da = daysBetween(sa, dateOnly(a.endTime!));
      final db = daysBetween(sb, dateOnly(b.endTime!));
      if (da != db) return db.compareTo(da); // 長い方が先
      return a.id.compareTo(b.id);
    });

  final laneByTopicId = <String, int>{};
  // lane 番号 → そのレーンに最後に置いたイベントの終了日。
  final laneEnds = <DateTime>[];
  for (final t in sorted) {
    final start = dateOnly(t.startTime!);
    final end = dateOnly(t.endTime!);
    var assigned = -1;
    for (var lane = 0; lane < laneEnds.length; lane++) {
      if (start.isAfter(laneEnds[lane])) {
        assigned = lane;
        break;
      }
    }
    if (assigned == -1) {
      laneEnds.add(end);
      assigned = laneEnds.length - 1;
    } else {
      laneEnds[assigned] = end;
    }
    laneByTopicId[t.id] = assigned;
  }
  return laneByTopicId;
}

/// 1 週行 (rowStart 〜 rowStart+6 日) に重なる期間予定を列位置にクリップする。
///
/// - lane < [maxVisibleLanes] のイベントは [WeekRowBars.visible] に入る
/// - lane >= [maxVisibleLanes] のイベントは行単位で [WeekRowBars.hiddenCount] に計上
/// - 行の外から続く / 行の外へ続く場合は continuesBefore / continuesAfter を立てる
WeekRowBars computeRowBars({
  required DateTime rowStart,
  required List<Topic> periodEvents,
  required Map<String, int> laneByTopicId,
  required int maxVisibleLanes,
}) {
  final start = dateOnly(rowStart);
  final rowEnd = DateTime(start.year, start.month, start.day + 6);

  final visible = <MonthBarSegment>[];
  var hiddenCount = 0;
  for (final t in periodEvents) {
    final lane = laneByTopicId[t.id];
    if (lane == null) continue;
    final s = dateOnly(t.startTime!);
    final e = dateOnly(t.endTime!);
    // この行と重ならないイベントはスキップ。
    if (e.isBefore(start) || s.isAfter(rowEnd)) continue;
    if (lane >= maxVisibleLanes) {
      hiddenCount++;
      continue;
    }
    final continuesBefore = s.isBefore(start);
    final continuesAfter = e.isAfter(rowEnd);
    final startCol = continuesBefore ? 0 : daysBetween(start, s);
    final endCol = continuesAfter ? 6 : daysBetween(start, e);
    visible.add(
      MonthBarSegment(
        topic: t,
        lane: lane,
        startCol: startCol,
        endCol: endCol,
        continuesBefore: continuesBefore,
        continuesAfter: continuesAfter,
      ),
    );
  }
  visible.sort((a, b) => a.lane.compareTo(b.lane));
  return WeekRowBars(visible: visible, hiddenCount: hiddenCount);
}
