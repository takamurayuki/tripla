import 'package:flutter_test/flutter_test.dart';
import 'package:tripla/data/repositories/trip_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late TripRepository repository;

  setUp(() {
    repository = TripRepository(createTestDatabase());
  });

  group('TripRepository', () {
    test('create + watchAll で新規旅程が流れてくる', () async {
      final stream = repository.watchAll();
      // 初期は空
      expect(await stream.first, isEmpty);

      final id = await repository.create(
        ownerId: 'u1',
        title: '京都2泊3日',
        startDate: DateTime(2026, 11, 15),
        endDate: DateTime(2026, 11, 17),
      );

      final trips = await stream.first;
      expect(trips, hasLength(1));
      expect(trips.first.id, id);
      expect(trips.first.title, '京都2泊3日');
      expect(trips.first.dayCount, 3);
    });

    test('update でタイトルが変わる', () async {
      final id = await repository.create(
        ownerId: 'u1',
        title: '旧タイトル',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 3),
      );
      final original = (await repository.getById(id))!;
      await repository.update(original.copyWith(title: '新タイトル'));

      final updated = (await repository.getById(id))!;
      expect(updated.title, '新タイトル');
    });

    test('delete で行が消える', () async {
      final id = await repository.create(
        ownerId: 'u1',
        title: 'tmp',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 1),
      );
      await repository.delete(id);
      expect(await repository.getById(id), isNull);
    });

    test('setLocked で isLocked が永続化される', () async {
      final id = await repository.create(
        ownerId: 'u1',
        title: 'lock-test',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 1),
      );
      expect((await repository.getById(id))!.isLocked, isFalse);
      await repository.setLocked(id, true);
      expect((await repository.getById(id))!.isLocked, isTrue);
      await repository.setLocked(id, false);
      expect((await repository.getById(id))!.isLocked, isFalse);
    });

    test('collectStats は Day/Topic/Checklist の件数を返す', () async {
      final id = await repository.create(
        ownerId: 'u1',
        title: 'stats',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 3),
      );
      final stats = await repository.collectStats(id);
      // Day は ensureDays を呼んでいないので 0
      expect(stats.dayCount, 0);
      expect(stats.topicCount, 0);
      expect(stats.checklistCount, 0);
    });
  });
}
