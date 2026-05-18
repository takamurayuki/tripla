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

  /// ID 指定で 1 件の Day を取得 (存在しなければ null)。
  Future<Day?> getById(String id) async {
    final row = await (_db.select(_db.days)..where((d) => d.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

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

  /// 任意の日付に対して Day を取得 or 新規作成する (idempotent)。
  /// スケジュールモード (mode=schedule) で「カレンダーセルをタップ → その日に Topic 追加」
  /// するときに使う。
  ///
  /// `dayNumber` は date 由来のエポック日数 (UTC) を使うことで、 重複しない一意値になる。
  /// この値は UI で表示しない (schedule では Day 番号自体が意味を持たない)。
  Future<Day> ensureDayForDate({
    required String tripId,
    required DateTime date,
  }) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final existing = await (_db.select(_db.days)
          ..where((d) => d.tripId.equals(tripId) & d.date.equals(normalized))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return _toEntity(existing);

    // UTC のエポック日 (1970-01-01 を 0 日目とする) を dayNumber に使うと、
    // 1 日 1 値で衝突しない。
    final epochDay =
        normalized.toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    final id = _uuid.v4();
    await _db.into(_db.days).insert(
          DaysCompanion.insert(
            id: id,
            tripId: tripId,
            dayNumber: epochDay,
            date: normalized,
          ),
        );
    return Day(
      id: id,
      tripId: tripId,
      dayNumber: epochDay,
      date: normalized,
    );
  }

  /// Day 個別ロックを切り替える。
  Future<void> setLocked(String id, bool value) async {
    await (_db.update(_db.days)..where((d) => d.id.equals(id))).write(
      DaysCompanion(isLocked: Value(value)),
    );
  }

  /// Day 完了フラグを切り替える。 タイムライン末尾の「おつかれさま！」 旗表示用。
  Future<void> setCompleted(String id, bool value) async {
    await (_db.update(_db.days)..where((d) => d.id.equals(id))).write(
      DaysCompanion(isCompleted: Value(value)),
    );
  }

  Day _toEntity(DayRow row) {
    return Day(
      id: row.id,
      tripId: row.tripId,
      dayNumber: row.dayNumber,
      date: row.date,
      note: row.note,
      isLocked: row.isLocked,
      isCompleted: row.isCompleted,
    );
  }
}
