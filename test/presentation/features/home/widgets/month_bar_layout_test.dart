import 'package:flutter_test/flutter_test.dart';
import 'package:tripla/domain/entities/topic.dart';
import 'package:tripla/domain/entities/topic_category.dart';
import 'package:tripla/presentation/features/home/widgets/month_bar_layout.dart';

Topic _periodEvent({
  required String id,
  required DateTime start,
  required DateTime end,
}) {
  final now = DateTime(2026, 1, 1);
  return Topic(
    id: id,
    dayId: 'day-$id',
    orderIndex: 0,
    category: TopicCategory.other,
    title: 'event-$id',
    startTime: DateTime(start.year, start.month, start.day),
    endTime: DateTime(end.year, end.month, end.day, 23, 59),
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('assignGlobalLanes', () {
    test('単発イベントはレーン 0', () {
      final t = _periodEvent(
        id: 'a',
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 3),
      );
      final lanes = assignGlobalLanes([t]);
      expect(lanes['a'], 0);
    });

    test('重ならないイベントは同じレーン 0 を共有できる', () {
      final a = _periodEvent(
        id: 'a',
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 3),
      );
      final b = _periodEvent(
        id: 'b',
        start: DateTime(2026, 7, 4),
        end: DateTime(2026, 7, 6),
      );
      final lanes = assignGlobalLanes([a, b]);
      expect(lanes['a'], 0);
      expect(lanes['b'], 0);
    });

    test('完全に重なる複数イベントはレーンが増加する', () {
      final a = _periodEvent(
        id: 'a',
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 10),
      );
      final b = _periodEvent(
        id: 'b',
        start: DateTime(2026, 7, 2),
        end: DateTime(2026, 7, 9),
      );
      final c = _periodEvent(
        id: 'c',
        start: DateTime(2026, 7, 3),
        end: DateTime(2026, 7, 8),
      );
      final lanes = assignGlobalLanes([a, b, c]);
      expect(lanes.values.toSet(), {0, 1, 2});
      // 最初に開始し最長の a がレーン 0。
      expect(lanes['a'], 0);
    });

    test('隣接するが重ならないイベント (終了日=開始日翌日以降) は同レーンになりうる', () {
      final a = _periodEvent(
        id: 'a',
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 2),
      );
      final b = _periodEvent(
        id: 'b',
        start: DateTime(2026, 7, 3),
        end: DateTime(2026, 7, 4),
      );
      final lanes = assignGlobalLanes([a, b]);
      expect(lanes['a'], 0);
      expect(lanes['b'], 0);
    });
  });

  group('computeRowBars', () {
    test('週行をまたぐイベントは行の端でクリップされ continues フラグが立つ', () {
      // 2026-07 は 7/1 が水曜。週行境界を明確にするため、日曜始まりの
      // 行 (7/5-7/11) をまたいで 7/3〜7/13 のイベントを配置する
      // (前の行から続き、次の行へも続く)。
      final t = _periodEvent(
        id: 'a',
        start: DateTime(2026, 7, 3),
        end: DateTime(2026, 7, 13),
      );
      final lanes = assignGlobalLanes([t]);
      final row = computeRowBars(
        rowStart: DateTime(2026, 7, 5), // 日曜
        periodEvents: [t],
        laneByTopicId: lanes,
        maxVisibleLanes: 3,
      );
      expect(row.visible, hasLength(1));
      final seg = row.visible.single;
      expect(seg.startCol, 0); // 行頭 (日曜) から継続
      expect(seg.endCol, 6); // 行末 (土曜) まで継続
      expect(seg.continuesBefore, isTrue);
      expect(seg.continuesAfter, isTrue);
    });

    test('行外のイベントは含まれない', () {
      final t = _periodEvent(
        id: 'a',
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 2),
      );
      final lanes = assignGlobalLanes([t]);
      final row = computeRowBars(
        rowStart: DateTime(2026, 7, 12),
        periodEvents: [t],
        laneByTopicId: lanes,
        maxVisibleLanes: 3,
      );
      expect(row.visible, isEmpty);
      expect(row.hiddenCount, 0);
    });

    test('月をまたぐイベント (表示月の外から続く) も行内では正しくクリップされる', () {
      // 6/28 開始 (表示月の前月) 〜 7/2 終了。
      final t = _periodEvent(
        id: 'a',
        start: DateTime(2026, 6, 28),
        end: DateTime(2026, 7, 2),
      );
      final lanes = assignGlobalLanes([t]);
      final row = computeRowBars(
        rowStart: DateTime(2026, 6, 28), // 日曜始まりの行 (6/28-7/4)
        periodEvents: [t],
        laneByTopicId: lanes,
        maxVisibleLanes: 3,
      );
      final seg = row.visible.single;
      expect(seg.startCol, 0);
      expect(seg.endCol, 4); // 7/2 = col 4
      expect(seg.continuesBefore, isFalse); // 6/28 がそもそも開始日
      expect(seg.continuesAfter, isFalse); // 7/2 がそもそも終了日
    });

    test('maxVisibleLanes を超えた分は hiddenCount に集約される', () {
      final events = List.generate(
        5,
        (i) => _periodEvent(
          id: 'e$i',
          start: DateTime(2026, 7, 1),
          end: DateTime(2026, 7, 5),
        ),
      );
      final lanes = assignGlobalLanes(events);
      final row = computeRowBars(
        rowStart: DateTime(2026, 6, 28),
        periodEvents: events,
        laneByTopicId: lanes,
        maxVisibleLanes: 3,
      );
      expect(row.visible, hasLength(3));
      expect(row.hiddenCount, 2);
    });

    test('100 件規模でもレーン割当とオーバーフロー集計が破綻しない', () {
      final events = List.generate(
        100,
        (i) => _periodEvent(
          id: 'e$i',
          start: DateTime(2026, 7, 1 + (i % 20)),
          end: DateTime(2026, 7, 3 + (i % 20)),
        ),
      );
      final lanes = assignGlobalLanes(events);
      expect(lanes.length, 100);
      final row = computeRowBars(
        rowStart: DateTime(2026, 6, 28),
        periodEvents: events,
        laneByTopicId: lanes,
        maxVisibleLanes: 3,
      );
      expect(row.visible.length + row.hiddenCount, greaterThan(0));
      for (final seg in row.visible) {
        expect(seg.lane, lessThan(3));
        expect(seg.startCol, inInclusiveRange(0, 6));
        expect(seg.endCol, inInclusiveRange(0, 6));
      }
    });
  });
}
