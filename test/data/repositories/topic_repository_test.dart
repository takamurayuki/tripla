import 'package:flutter_test/flutter_test.dart';
import 'package:tripla/data/repositories/day_repository.dart';
import 'package:tripla/data/repositories/topic_repository.dart';
import 'package:tripla/data/repositories/trip_repository.dart';
import 'package:tripla/domain/entities/topic.dart';
import 'package:tripla/domain/entities/topic_actual_status.dart';
import 'package:tripla/domain/entities/topic_alt_plan.dart';
import 'package:tripla/domain/entities/topic_category.dart';
import 'package:tripla/domain/entities/transport_mode.dart';

import '../../helpers/test_db.dart';

void main() {
  late TopicRepository topicRepo;
  late DayRepository dayRepo;
  late TripRepository tripRepo;
  late String dayId;

  setUp(() async {
    final db = createTestDatabase();
    topicRepo = TopicRepository(db);
    dayRepo = DayRepository(db);
    tripRepo = TripRepository(db);

    final tripId = await tripRepo.create(
      ownerId: 'u1',
      title: 't',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 1),
    );
    final trip = (await tripRepo.getById(tripId))!;
    await dayRepo.ensureDaysForTrip(trip);
    dayId = (await dayRepo.watchByTrip(tripId).first).first.id;
  });

  group('TopicRepository', () {
    test('create は orderIndex を末尾に振る', () async {
      final a = await topicRepo.create(
          dayId: dayId, category: TopicCategory.sightseeing, title: 'A');
      final b = await topicRepo.create(
          dayId: dayId, category: TopicCategory.meal, title: 'B');
      final list = await topicRepo.watchByDay(dayId).first;
      expect(list.map((t) => t.id).toList(), [a, b]);
      expect(list[0].orderIndex, 0);
      expect(list[1].orderIndex, 1);
    });

    test('reorderForDay は orderIndex を 0 から振り直す', () async {
      final a = await topicRepo.create(
          dayId: dayId, category: TopicCategory.sightseeing, title: 'A');
      final b = await topicRepo.create(
          dayId: dayId, category: TopicCategory.meal, title: 'B');
      final c = await topicRepo.create(
          dayId: dayId, category: TopicCategory.lodging, title: 'C');

      // 並びを C → A → B にする
      await topicRepo.reorderForDay(dayId, [c, a, b]);
      final list = await topicRepo.watchByDay(dayId).first;
      expect(list.map((t) => t.id).toList(), [c, a, b]);
      expect(list[0].orderIndex, 0);
      expect(list[1].orderIndex, 1);
      expect(list[2].orderIndex, 2);
    });

    test('setParent は循環(自分自身を親に)させない', () async {
      final a = await topicRepo.create(
          dayId: dayId, category: TopicCategory.other, title: 'A');
      await topicRepo.setParent(a, a); // 自分を親に → 何もしない
      final topic = (await topicRepo.watchByDay(dayId).first).first;
      expect(topic.parentTopicId, isNull);
    });

    test('setParent は子孫を親候補にできない', () async {
      final parent = await topicRepo.create(
          dayId: dayId, category: TopicCategory.other, title: 'P');
      final child = await topicRepo.create(
          dayId: dayId, category: TopicCategory.other, title: 'C');
      await topicRepo.setParent(child, parent);
      // ここで parent を child の子にしようとする → 循環
      await topicRepo.setParent(parent, child);

      final list = await topicRepo.watchByDay(dayId).first;
      final p = list.firstWhere((t) => t.id == parent);
      // parent は親のまま
      expect(p.parentTopicId, isNull);
    });

    test('create + update で altPlans (代替プラン) が永続化される', () async {
      final id = await topicRepo.create(
        dayId: dayId,
        category: TopicCategory.transport,
        title: '東京 → 池袋',
        transportMode: TransportMode.taxi,
        altPlans: [
          TopicAltPlan(
            id: 'p1',
            label: 'プランA',
            departure: '東京',
            destination: '池袋',
            transportMode: TransportMode.train,
            startTime: DateTime(2026, 5, 14, 9, 0),
            endTime: DateTime(2026, 5, 14, 12, 30),
            note: 'JR 山手線',
          ),
        ],
      );

      final created = (await topicRepo.watchByDay(dayId).first)
          .firstWhere((t) => t.id == id);
      expect(created.altPlans, hasLength(1));
      expect(created.altPlans.first.id, 'p1');
      expect(created.altPlans.first.label, 'プランA');
      expect(created.altPlans.first.transportMode, TransportMode.train);
      expect(created.altPlans.first.startTime, DateTime(2026, 5, 14, 9, 0));
      expect(created.altPlans.first.note, 'JR 山手線');

      // update でプランを追加
      await topicRepo.update(created.copyWith(altPlans: [
        ...created.altPlans,
        TopicAltPlan(
          id: 'p2',
          label: 'プランB',
          transportMode: TransportMode.bus,
          departure: '東京',
          destination: '池袋',
        ),
      ]));
      final updated = (await topicRepo.watchByDay(dayId).first)
          .firstWhere((t) => t.id == id);
      expect(updated.altPlans, hasLength(2));
      expect(updated.altPlans.map((p) => p.id), ['p1', 'p2']);
    });

    test('update で実績 (actualStartTime/actualEndTime/actualStatus/actualNote) '
        'が永続化・復元される', () async {
      final id = await topicRepo.create(
        dayId: dayId,
        category: TopicCategory.sightseeing,
        title: '観光',
        startTime: DateTime(2026, 5, 14, 9, 0),
        endTime: DateTime(2026, 5, 14, 10, 0),
      );
      final created =
          (await topicRepo.watchByDay(dayId).first).firstWhere((t) => t.id == id);
      expect(created.hasActualRecord, isFalse);

      await topicRepo.update(created.copyWith(
        actualStartTime: DateTime(2026, 5, 14, 9, 20),
        actualEndTime: DateTime(2026, 5, 14, 10, 5),
        actualStatus: TopicActualStatus.recorded,
        actualNote: '電車遅延で20分遅れ',
      ));

      final updated =
          (await topicRepo.watchByDay(dayId).first).firstWhere((t) => t.id == id);
      expect(updated.hasActualRecord, isTrue);
      expect(updated.actualStartTime, DateTime(2026, 5, 14, 9, 20));
      expect(updated.actualEndTime, DateTime(2026, 5, 14, 10, 5));
      expect(updated.actualStatus, TopicActualStatus.recorded);
      expect(updated.actualNote, '電車遅延で20分遅れ');
      expect(updated.actualStartDelayMinutes, 20);
      expect(updated.isDelayedStart, isTrue);
    });

    test('スキップ操作 (直接 Topic(...) 構築) で実績が null クリアされる', () async {
      final id = await topicRepo.create(
        dayId: dayId,
        category: TopicCategory.meal,
        title: '食事',
        startTime: DateTime(2026, 5, 14, 12, 0),
        endTime: DateTime(2026, 5, 14, 13, 0),
      );
      final created =
          (await topicRepo.watchByDay(dayId).first).firstWhere((t) => t.id == id);
      await topicRepo.update(created.copyWith(
        actualStartTime: DateTime(2026, 5, 14, 12, 0),
        actualEndTime: DateTime(2026, 5, 14, 13, 0),
        actualStatus: TopicActualStatus.recorded,
        actualNote: 'メモ',
      ));
      final recorded =
          (await topicRepo.watchByDay(dayId).first).firstWhere((t) => t.id == id);
      expect(recorded.hasActualRecord, isTrue);

      // スキップ操作: copyWith では null に戻せないため Topic(...) を直接構築する
      final skipped = Topic(
        id: recorded.id,
        dayId: recorded.dayId,
        parentTopicId: recorded.parentTopicId,
        orderIndex: recorded.orderIndex,
        category: recorded.category,
        title: recorded.title,
        description: recorded.description,
        startTime: recorded.startTime,
        endTime: recorded.endTime,
        latitude: recorded.latitude,
        longitude: recorded.longitude,
        locationName: recorded.locationName,
        address: recorded.address,
        cost: recorded.cost,
        costCurrency: recorded.costCurrency,
        isCompleted: recorded.isCompleted,
        departure: recorded.departure,
        destination: recorded.destination,
        transportMode: recorded.transportMode,
        altPlans: recorded.altPlans,
        links: recorded.links,
        colorHex: recorded.colorHex,
        photos: recorded.photos,
        trainTransfers: recorded.trainTransfers,
        actualStartTime: null,
        actualEndTime: null,
        actualStatus: TopicActualStatus.skipped,
        actualNote: recorded.actualNote,
        createdAt: recorded.createdAt,
        updatedAt: recorded.updatedAt,
      );
      await topicRepo.update(skipped);

      final result =
          (await topicRepo.watchByDay(dayId).first).firstWhere((t) => t.id == id);
      expect(result.actualStartTime, isNull);
      expect(result.actualEndTime, isNull);
      expect(result.actualStatus, TopicActualStatus.skipped);
      expect(result.actualNote, 'メモ');
    });

    test('delete は子の parentTopicId を NULL に戻す', () async {
      final parent = await topicRepo.create(
          dayId: dayId, category: TopicCategory.other, title: 'P');
      final child = await topicRepo.create(
          dayId: dayId, category: TopicCategory.other, title: 'C');
      await topicRepo.setParent(child, parent);

      await topicRepo.delete(parent);
      final list = await topicRepo.watchByDay(dayId).first;
      expect(list, hasLength(1));
      expect(list.first.id, child);
      expect(list.first.parentTopicId, isNull);
    });
  });
}
