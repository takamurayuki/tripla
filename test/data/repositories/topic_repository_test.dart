import 'package:flutter_test/flutter_test.dart';
import 'package:tripla/data/repositories/day_repository.dart';
import 'package:tripla/data/repositories/topic_repository.dart';
import 'package:tripla/data/repositories/trip_repository.dart';
import 'package:tripla/domain/entities/topic_category.dart';

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
