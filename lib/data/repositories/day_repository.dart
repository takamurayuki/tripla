import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/day.dart';
import '../../domain/entities/trip.dart';
import '../datasources/local/database.dart';

/// Day(日別枠) の永続化リポジトリ。
class DayRepository {
  DayRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final TriplaDatabase _db;
  final Uuid _uuid;

  /// 指定 Trip に紐づく Day 群を dayNumber 昇順で監視。
  Stream<List<Day>> watchByTrip(String tripId) {
    final query = _db.select(_db.days)
      ..where((d) => d.tripId.equals(tripId))
      ..orderBy([(d) => OrderingTerm.asc(d.dayNumber)]);
    return query.watch().map(
          (rows) => rows.map(_toEntity).toList(growable: false),
        );
  }

  /// Trip 期間に対して不足している Day を埋める (idempotent)。
  /// 既存の Day はそのまま、足りない dayNumber のみ INSERT。
  Future<void> ensureDaysForTrip(Trip trip) async {
    final existing = await (_db.select(_db.days)
          ..where((d) => d.tripId.equals(trip.id)))
        .get();
    final existingNumbers = existing.map((d) => d.dayNumber).toSet();

    final inserts = <DaysCompanion>[];
    final start = DateTime(trip.startDate.year, trip.startDate.month, trip.startDate.day);
    for (var i = 1; i <= trip.dayCount; i++) {
      if (existingNumbers.contains(i)) continue;
      inserts.add(
        DaysCompanion.insert(
          id: _uuid.v4(),
          tripId: trip.id,
          dayNumber: i,
          date: start.add(Duration(days: i - 1)),
        ),
      );
    }
    if (inserts.isEmpty) return;
    await _db.batch((batch) => batch.insertAll(_db.days, inserts));
  }

  Day _toEntity(DayRow row) {
    return Day(
      id: row.id,
      tripId: row.tripId,
      dayNumber: row.dayNumber,
      date: row.date,
      note: row.note,
    );
  }
}
