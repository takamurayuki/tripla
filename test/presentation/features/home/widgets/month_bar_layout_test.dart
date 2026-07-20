import 'package:flutter_test/flutter_test.dart';
import 'package:tripla/domain/entities/topic.dart';
import 'package:tripla/domain/entities/topic_category.dart';
import 'package:tripla/presentation/features/home/widgets/month_bar_layout.dart';

Topic makeTopic({
  required String id,
  required DateTime start,
  required DateTime end,
}) {
  return Topic(
    id: id,
    dayId: 'day-1',
    orderIndex: 0,
    category: TopicCategory.other,
    title: 'topic-$id',
    startTime: start,
    endTime: end,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('assignGlobalLanes', () {
    test('重ならないイベント同士は同じレーン 0 を共有する', () {
      final events = [
        makeTopic(id: 'a', start: DateTime(2026, 7, 1), end: DateTime(2026, 7, 3)),
        makeTopic(id: 'b', start: DateTime(2026, 7, 5), end: DateTime(2026, 7, 7)),
      ];
      final lanes = assignGlobalLanes(events);
      expect(lanes['a'], 0);
      expect(lanes['b'], 0);
    });

    test('終了日と同じ日に開始するイベントは重なり扱いで別レーンになる', () {
      // 全日予定なので 7/3 終了と 7/3 開始はその日に同居 = 重なる。
      final events = [
        makeTopic(id: 'a', start: DateTime(2026, 7, 1), end: DateTime(2026, 7, 3)),
        makeTopic(id: 'b', start: DateTime(2026, 7, 3), end: DateTime(2026, 7, 5)),
      ];
      final lanes = assignGlobalLanes(events);
      expect(lanes['a'], 0);
      expect(lanes['b'], 1);
    });

    test('完全に重なる複数イベントはレーンが積み上がる', () {
      final events = [
        makeTopic(id: 'a', start: DateTime(2026, 7, 10), end: DateTime(2026, 7, 12)),
        makeTopic(id: 'b', start: DateTime(2026, 7, 10), end: DateTime(2026, 7, 12)),
        makeTopic(id: 'c', start: DateTime(2026, 7, 10), end: DateTime(2026, 7, 12)),
      ];
      final lanes = assignGlobalLanes(events);
      expect({lanes['a'], lanes['b'], lanes['c']}, {0, 1, 2});
    });

    test('同じ開始日なら期間が長い方が先 (小さいレーン) に割り当たる', () {
      final events = [
        makeTopic(id: 'short', start: DateTime(2026, 7, 1), end: DateTime(2026, 7, 2)),
        makeTopic(id: 'long', start: DateTime(2026, 7, 1), end: DateTime(2026, 7, 10)),
      ];
      final lanes = assignGlobalLanes(events);
      expect(lanes['long'], 0);
      expect(lanes['short'], 1);
    });

    test('同一入力に対して決定的 (id 昇順タイブレーク)', () {
      final events = [
        makeTopic(id: 'b', start: DateTime(2026, 7, 1), end: DateTime(2026, 7, 2)),
        makeTopic(id: 'a', start: DateTime(2026, 7, 1), end: DateTime(2026, 7, 2)),
      ];
      final first = assignGlobalLanes(events);
      final second = assignGlobalLanes(events.reversed.toList());
      expect(first, second);
      expect(first['a'], 0);
      expect(first['b'], 1);
    });

    test('startTime の時刻成分は無視して日付だけで判定する', () {
      // 期間予定は 00:00 / 23:59 で保存されるが、 判定は日付のみで行う。
      final events = [
        makeTopic(
          id: 'a',
          start: DateTime(2026, 7, 1),
          end: DateTime(2026, 7, 2, 23, 59),
        ),
        makeTopic(
          id: 'b',
          start: DateTime(2026, 7, 3),
          end: DateTime(2026, 7, 4, 23, 59),
        ),
      ];
      final lanes = assignGlobalLanes(events);
      expect(lanes['a'], 0);
      expect(lanes['b'], 0);
    });
  });

  group('computeRowBars', () {
    test('行内に収まるイベントは正しい列にクリップされ continues フラグ無し', () {
      // 2026-07 の第1週: 7/1 は水曜 → rowStart 6/28(日) 〜 7/4(土)
      final rowStart = DateTime(2026, 6, 28);
      final t = makeTopic(
        id: 'a',
        start: DateTime(2026, 6, 29),
        end: DateTime(2026, 7, 2, 23, 59),
      );
      final bars = computeRowBars(
        rowStart: rowStart,
        periodEvents: [t],
        laneByTopicId: const {'a': 0},
        maxVisibleLanes: 3,
      );
      expect(bars.visible, hasLength(1));
      final seg = bars.visible.single;
      expect(seg.startCol, 1); // 月曜
      expect(seg.endCol, 4); // 木曜
      expect(seg.continuesBefore, isFalse);
      expect(seg.continuesAfter, isFalse);
      expect(bars.hiddenCount, 0);
    });

    test('週を跨ぐイベントは行ごとに端でクリップされ continues フラグが立つ', () {
      final t = makeTopic(
        id: 'a',
        start: DateTime(2026, 7, 3), // 金曜 (第1週)
        end: DateTime(2026, 7, 7, 23, 59), // 火曜 (第2週)
      );
      final lanes = {'a': 0};

      final week1 = computeRowBars(
        rowStart: DateTime(2026, 6, 28),
        periodEvents: [t],
        laneByTopicId: lanes,
        maxVisibleLanes: 3,
      );
      final seg1 = week1.visible.single;
      expect(seg1.startCol, 5);
      expect(seg1.endCol, 6);
      expect(seg1.continuesBefore, isFalse);
      expect(seg1.continuesAfter, isTrue);

      final week2 = computeRowBars(
        rowStart: DateTime(2026, 7, 5),
        periodEvents: [t],
        laneByTopicId: lanes,
        maxVisibleLanes: 3,
      );
      final seg2 = week2.visible.single;
      expect(seg2.startCol, 0);
      expect(seg2.endCol, 2);
      expect(seg2.continuesBefore, isTrue);
      expect(seg2.continuesAfter, isFalse);
    });

    test('前月から続くイベント (月跨ぎ) は行頭から描画され continuesBefore が立つ', () {
      // 6/25 開始 → 7 月第1週 (6/28 開始行) では行頭から。
      final t = makeTopic(
        id: 'a',
        start: DateTime(2026, 6, 25),
        end: DateTime(2026, 7, 1, 23, 59),
      );
      final bars = computeRowBars(
        rowStart: DateTime(2026, 6, 28),
        periodEvents: [t],
        laneByTopicId: const {'a': 0},
        maxVisibleLanes: 3,
      );
      final seg = bars.visible.single;
      expect(seg.startCol, 0);
      expect(seg.endCol, 3); // 7/1 = 水曜
      expect(seg.continuesBefore, isTrue);
      expect(seg.continuesAfter, isFalse);
    });

    test('行と重ならないイベントは visible にも hiddenCount にも入らない', () {
      final t = makeTopic(
        id: 'a',
        start: DateTime(2026, 7, 20),
        end: DateTime(2026, 7, 22),
      );
      final bars = computeRowBars(
        rowStart: DateTime(2026, 6, 28),
        periodEvents: [t],
        laneByTopicId: const {'a': 0},
        maxVisibleLanes: 3,
      );
      expect(bars.visible, isEmpty);
      expect(bars.hiddenCount, 0);
      expect(bars.laneCount, 0);
    });

    test('maxVisibleLanes 超過分は行単位で hiddenCount に集計される', () {
      final events = [
        for (var i = 0; i < 5; i++)
          makeTopic(
            id: 'e$i',
            start: DateTime(2026, 7, 6),
            end: DateTime(2026, 7, 8, 23, 59),
          ),
      ];
      final lanes = assignGlobalLanes(events);
      final bars = computeRowBars(
        rowStart: DateTime(2026, 7, 5),
        periodEvents: events,
        laneByTopicId: lanes,
        maxVisibleLanes: 3,
      );
      expect(bars.visible, hasLength(3));
      expect(bars.hiddenCount, 2);
      expect(bars.laneCount, 3);
      // visible は lane 昇順。
      expect(bars.visible.map((s) => s.lane).toList(), [0, 1, 2]);
    });

    test('100 件規模でもレーン割当と行クリップが破綻しない', () {
      // 100 件を月内にばらまく (10 日ごとに 25 件ずつ重ねる)。
      final events = [
        for (var i = 0; i < 100; i++)
          makeTopic(
            id: 'e${i.toString().padLeft(3, '0')}',
            start: DateTime(2026, 7, 1 + (i % 4) * 7),
            end: DateTime(2026, 7, 3 + (i % 4) * 7, 23, 59),
          ),
      ];
      final lanes = assignGlobalLanes(events);
      expect(lanes, hasLength(100));
      final bars = computeRowBars(
        rowStart: DateTime(2026, 6, 28),
        periodEvents: events,
        laneByTopicId: lanes,
        maxVisibleLanes: 3,
      );
      // 7/1〜7/3 に 25 件が重なる → 3 本表示 + 22 件が hidden。
      expect(bars.visible, hasLength(3));
      expect(bars.hiddenCount, 22);
    });
  });
}
