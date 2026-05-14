import 'package:flutter_test/flutter_test.dart';
import 'package:tripla/data/repositories/checklist_repository.dart';
import 'package:tripla/data/repositories/day_repository.dart';
import 'package:tripla/data/repositories/topic_repository.dart';
import 'package:tripla/data/repositories/trip_repository.dart';
import 'package:tripla/domain/entities/topic_category.dart';

import '../../helpers/test_db.dart';

void main() {
  late ChecklistRepository repo;
  late DayRepository dayRepo;
  late TopicRepository topicRepo;
  late String tripId;

  setUp(() async {
    final db = createTestDatabase();
    final trip = TripRepository(db);
    repo = ChecklistRepository(db);
    dayRepo = DayRepository(db);
    topicRepo = TopicRepository(db);
    tripId = await trip.create(
      ownerId: 'u1',
      title: 't',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 3),
    );
    final t = (await trip.getById(tripId))!;
    await dayRepo.ensureDaysForTrip(t);
  });

  group('ChecklistRepository', () {
    test('create + watch でアイテムが流れてくる', () async {
      await repo.create(
        tripId: tripId,
        name: '充電器',
        category: '電子機器',
        createdByUserId: 'u1',
      );
      final items = await repo.watchByTrip(tripId).first;
      expect(items, hasLength(1));
      expect(items.first.name, '充電器');
      expect(items.first.category, '電子機器');
      expect(items.first.isChecked, isFalse);
      expect(items.first.createdByUserId, 'u1');
      expect(items.first.isTripScoped, isTrue);
    });

    test('旅全体スコープで複数件追加できる (orderIndex の重複なし)', () async {
      await repo.create(tripId: tripId, name: 'A', createdByUserId: 'u1');
      await repo.create(tripId: tripId, name: 'B', createdByUserId: 'u1');
      await repo.create(tripId: tripId, name: 'C', createdByUserId: 'u1');
      final items = await repo.watchByTrip(tripId).first;
      expect(items, hasLength(3));
      expect(items.map((i) => i.name).toSet(), {'A', 'B', 'C'});
      final indexes = items.map((i) => i.orderIndex).toList();
      expect(indexes.toSet().length, indexes.length, reason: 'orderIndex は重複しない');
    });

    test('toggleChecked しても順序は orderIndex のまま (チェックで動かない)', () async {
      final a = await repo.create(
          tripId: tripId, name: 'A', createdByUserId: 'u1');
      final b = await repo.create(
          tripId: tripId, name: 'B', createdByUserId: 'u1');
      final c = await repo.create(
          tripId: tripId, name: 'C', createdByUserId: 'u1');
      await repo.toggleChecked(a, true);

      final items = await repo.watchByTrip(tripId).first;
      expect(items.map((i) => i.id).toList(), [a, b, c],
          reason: 'チェックを入れても並び替わらないこと');
      expect(items.first.isChecked, isTrue);
    });

    test('updateItem で名前 / カテゴリ / スコープを変更できる', () async {
      final days = await dayRepo.watchByTrip(tripId).first;
      final day1 = days.first;
      final id = await repo.create(
          tripId: tripId, name: '充電器', createdByUserId: 'u1');
      await repo.updateItem(
        id: id,
        name: 'モバイルバッテリー',
        category: '電子機器',
        dayId: day1.id,
        topicId: null,
      );
      final items = await repo.watchByTrip(tripId).first;
      final updated = items.firstWhere((i) => i.id == id);
      expect(updated.name, 'モバイルバッテリー');
      expect(updated.category, '電子機器');
      expect(updated.dayId, day1.id);
    });

    test('delete で行が消える', () async {
      final id = await repo.create(
          tripId: tripId, name: 'X', createdByUserId: 'u1');
      await repo.delete(id);
      final items = await repo.watchByTrip(tripId).first;
      expect(items, isEmpty);
    });

    test('dayId / topicId スコープで作成できる', () async {
      final days = await dayRepo.watchByTrip(tripId).first;
      final day1 = days.first;
      final topicId = await topicRepo.create(
        dayId: day1.id,
        category: TopicCategory.sightseeing,
        title: '清水寺観光',
      );

      // 旅全体
      final tripItem = await repo.create(
          tripId: tripId, name: 'パスポート', createdByUserId: 'u1');
      // Day 直接
      final dayItem = await repo.create(
          tripId: tripId,
          name: 'カメラ',
          dayId: day1.id,
          createdByUserId: 'u1');
      // 予定経由
      final topicItem = await repo.create(
          tripId: tripId,
          name: 'ハイキング靴',
          dayId: day1.id,
          topicId: topicId,
          createdByUserId: 'u1');

      final items = await repo.watchByTrip(tripId).first;
      final byId = {for (final i in items) i.id: i};
      expect(byId[tripItem]!.isTripScoped, isTrue);
      expect(byId[dayItem]!.dayId, day1.id);
      expect(byId[dayItem]!.topicId, isNull);
      expect(byId[topicItem]!.topicId, topicId);
      expect(byId[topicItem]!.isViaTopic, isTrue);
    });

    test('Topic 削除で予定経由のアイテムも cascade で消える', () async {
      final days = await dayRepo.watchByTrip(tripId).first;
      final day1 = days.first;
      final topicId = await topicRepo.create(
        dayId: day1.id,
        category: TopicCategory.sightseeing,
        title: '清水寺観光',
      );
      await repo.create(
          tripId: tripId,
          name: 'ハイキング靴',
          dayId: day1.id,
          topicId: topicId,
          createdByUserId: 'u1');
      // 旅全体のアイテムも 1 件
      await repo.create(
          tripId: tripId, name: 'パスポート', createdByUserId: 'u1');

      expect(await repo.watchByTrip(tripId).first, hasLength(2));

      await topicRepo.delete(topicId);
      final after = await repo.watchByTrip(tripId).first;
      expect(after, hasLength(1));
      expect(after.first.name, 'パスポート');
    });

    test('promoteToTripScope で Day スコープアイテムを旅全体に昇格', () async {
      final days = await dayRepo.watchByTrip(tripId).first;
      final day1 = days.first;
      final id = await repo.create(
          tripId: tripId,
          name: 'カメラ',
          dayId: day1.id,
          createdByUserId: 'u1');
      await repo.promoteToTripScope([day1.id]);
      final items = await repo.watchByTrip(tripId).first;
      final updated = items.firstWhere((i) => i.id == id);
      expect(updated.dayId, isNull);
      expect(updated.isTripScoped, isTrue);
    });
  });
}
