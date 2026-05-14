import 'package:flutter_test/flutter_test.dart';
import 'package:tripla/data/repositories/checklist_repository.dart';
import 'package:tripla/data/repositories/trip_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late ChecklistRepository repo;
  late String tripId;

  setUp(() async {
    final db = createTestDatabase();
    final trip = TripRepository(db);
    repo = ChecklistRepository(db);
    tripId = await trip.create(
      ownerId: 'u1',
      title: 't',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 1),
    );
  });

  group('ChecklistRepository', () {
    test('create + watch でアイテムが流れてくる', () async {
      await repo.create(tripId: tripId, name: '充電器', category: '電子機器');
      final items = await repo.watchByTrip(tripId).first;
      expect(items, hasLength(1));
      expect(items.first.name, '充電器');
      expect(items.first.category, '電子機器');
      expect(items.first.isChecked, isFalse);
    });

    test('toggleChecked でチェック済みは下に並ぶ', () async {
      final a = await repo.create(tripId: tripId, name: 'A');
      final b = await repo.create(tripId: tripId, name: 'B');
      final c = await repo.create(tripId: tripId, name: 'C');
      await repo.toggleChecked(a, true); // A をチェック済みに

      final items = await repo.watchByTrip(tripId).first;
      // 未チェック (B, C) が先、チェック済み (A) が後ろ
      expect(items.map((i) => i.id).toList(), [b, c, a]);
      expect(items.last.isChecked, isTrue);
    });

    test('delete で行が消える', () async {
      final id = await repo.create(tripId: tripId, name: 'X');
      await repo.delete(id);
      final items = await repo.watchByTrip(tripId).first;
      expect(items, isEmpty);
    });
  });
}
