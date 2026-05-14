import 'package:flutter_test/flutter_test.dart';
import 'package:tripla/data/repositories/day_repository.dart';
import 'package:tripla/data/repositories/trip_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late DayRepository dayRepo;
  late TripRepository tripRepo;

  setUp(() {
    final db = createTestDatabase();
    dayRepo = DayRepository(db);
    tripRepo = TripRepository(db);
  });

  group('DayRepository.ensureDaysForTrip', () {
    test('初回は Trip 期間に応じた Day を作成する', () async {
      final id = await tripRepo.create(
        ownerId: 'u1',
        title: '3 日間',
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 3),
      );
      final trip = (await tripRepo.getById(id))!;
      await dayRepo.ensureDaysForTrip(trip);

      final days = await dayRepo.watchByTrip(id).first;
      expect(days, hasLength(3));
      expect(days[0].dayNumber, 1);
      expect(days[2].dayNumber, 3);
      expect(days[0].date, DateTime(2026, 5, 1));
      expect(days[2].date, DateTime(2026, 5, 3));
    });

    test('setLocked で Day.isLocked が永続化される', () async {
      final id = await tripRepo.create(
        ownerId: 'u1',
        title: 't',
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 1),
      );
      final trip = (await tripRepo.getById(id))!;
      await dayRepo.ensureDaysForTrip(trip);
      final day = (await dayRepo.watchByTrip(id).first).first;
      expect(day.isLocked, isFalse);
      await dayRepo.setLocked(day.id, true);
      final after = (await dayRepo.watchByTrip(id).first).first;
      expect(after.isLocked, isTrue);
    });

    test('再呼び出ししても件数が増えない (idempotent)', () async {
      final id = await tripRepo.create(
        ownerId: 'u1',
        title: '2 日間',
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 2),
      );
      final trip = (await tripRepo.getById(id))!;
      await dayRepo.ensureDaysForTrip(trip);
      await dayRepo.ensureDaysForTrip(trip);
      await dayRepo.ensureDaysForTrip(trip);

      final days = await dayRepo.watchByTrip(id).first;
      expect(days, hasLength(2));
    });
  });
}
