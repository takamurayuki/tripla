import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/trip.dart';
import '../../domain/entities/trip_mode.dart';
import '../datasources/local/database.dart';

/// 旅程の永続化を担うリポジトリ。
///
/// Phase 1 マイルストーン 1 ではローカル DB (Drift) のみを扱う。
/// Phase 2 以降で Supabase と同期する RemoteDataSource をここに足す。
class TripRepository {
  TripRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final TriplaDatabase _db;
  final Uuid _uuid;

  /// 全旅程を `updatedAt` 降順で監視する。
  /// 既定では「旅行計画」のみ。 schedule (singleton マイスケジュール) は別動線で扱うため除外。
  /// 全件を取りたい場合は [includeSchedule]=true。
  Stream<List<Trip>> watchAll({bool includeSchedule = false}) {
    final query = _db.select(_db.trips)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (!includeSchedule) {
      query.where((t) => t.mode.equals(TripMode.plan.name));
    }
    return query.watch().map(
          (rows) => rows.map(_toEntity).toList(growable: false),
        );
  }

  /// 指定 ID の旅程を監視する (存在しなければ null を流す)。
  Stream<Trip?> watchById(String id) {
    final query = _db.select(_db.trips)..where((t) => t.id.equals(id));
    return query.watchSingleOrNull().map(
          (row) => row == null ? null : _toEntity(row),
        );
  }

  /// 指定 ID の旅程を 1 回だけ取得する。
  Future<Trip?> getById(String id) async {
    final row = await (_db.select(_db.trips)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  /// 旅程削除前に表示する関連件数(Day / Topic / 持ち物)を集計する。
  Future<TripStats> collectStats(String tripId) async {
    final dayCount = await _db.days.count(where: (d) => d.tripId.equals(tripId)).getSingle();
    final dayIdsRows = await (_db.selectOnly(_db.days)
          ..addColumns([_db.days.id])
          ..where(_db.days.tripId.equals(tripId)))
        .get();
    final dayIds = dayIdsRows.map((r) => r.read(_db.days.id)!).toList();
    final topicCount = dayIds.isEmpty
        ? 0
        : await _db.topics
            .count(where: (t) => t.dayId.isIn(dayIds))
            .getSingle();
    final checklistCount = await _db.checklistItems
        .count(where: (c) => c.tripId.equals(tripId))
        .getSingle();
    return TripStats(
      dayCount: dayCount,
      topicCount: topicCount,
      checklistCount: checklistCount,
    );
  }

  /// 旅程を新規作成して ID を返す。
  Future<String> create({
    required String ownerId,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    String? coverImageUrl,
    String baseCurrency = 'JPY',
    String? travelCurrency,
    TripMode mode = TripMode.plan,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    await _db.into(_db.trips).insert(
          TripsCompanion.insert(
            id: id,
            ownerId: ownerId,
            title: title,
            description: Value(description),
            startDate: startDate,
            endDate: endDate,
            coverImageUrl: Value(coverImageUrl),
            baseCurrency: Value(baseCurrency),
            travelCurrency: Value(travelCurrency),
            mode: Value(mode.name),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// マイスケジュール (mode=schedule) を監視。 未作成なら null を流す。
  Stream<Trip?> watchSchedule(String ownerId) {
    final query = _db.select(_db.trips)
      ..where((t) =>
          t.ownerId.equals(ownerId) & t.mode.equals(TripMode.schedule.name))
      ..limit(1);
    return query.watchSingleOrNull().map(
          (row) => row == null ? null : _toEntity(row),
        );
  }

  /// マイスケジュール (mode=schedule) を取得 or 作成 (singleton)。
  /// 指定 ownerId に対して 1 件だけ存在する想定。
  /// 既存があれば返し、 無ければ作成して返す。
  ///
  /// 期間は便宜的に「今日 〜 1年後」 を初期値にする (UI 上は使われない)。
  /// 実際の利用日は Day を都度ensure で生やす形式 (Phase 2 で実装)。
  Future<Trip> getOrCreateSchedule(String ownerId) async {
    final existing = await (_db.select(_db.trips)
          ..where((t) =>
              t.ownerId.equals(ownerId) & t.mode.equals(TripMode.schedule.name))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return _toEntity(existing);

    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final id = await create(
      ownerId: ownerId,
      title: 'マイスケジュール',
      startDate: start,
      endDate: start.add(const Duration(days: 365)),
      mode: TripMode.schedule,
    );
    return (await getById(id))!;
  }

  /// 既存旅程を更新する。タイトル等を変更した直後にも呼ぶ。
  Future<void> update(Trip trip) async {
    final updated = trip.copyWith(updatedAt: DateTime.now());
    await _db.update(_db.trips).replace(
          TripsCompanion(
            id: Value(updated.id),
            ownerId: Value(updated.ownerId),
            title: Value(updated.title),
            description: Value(updated.description),
            startDate: Value(updated.startDate),
            endDate: Value(updated.endDate),
            coverImageUrl: Value(updated.coverImageUrl),
            baseCurrency: Value(updated.baseCurrency),
            travelCurrency: Value(updated.travelCurrency),
            isLocked: Value(updated.isLocked),
            mode: Value(updated.mode.name),
            createdAt: Value(updated.createdAt),
            updatedAt: Value(updated.updatedAt),
          ),
        );
  }

  /// Trip 一括ロック状態を切り替える。
  Future<void> setLocked(String id, bool value) async {
    await (_db.update(_db.trips)..where((t) => t.id.equals(id))).write(
      TripsCompanion(
        isLocked: Value(value),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 旅程を ID 指定で削除する。
  Future<void> delete(String id) async {
    await (_db.delete(_db.trips)..where((t) => t.id.equals(id))).go();
  }

  static TripStats emptyStats() =>
      const TripStats(dayCount: 0, topicCount: 0, checklistCount: 0);

  Trip _toEntity(TripRow row) {
    return Trip(
      id: row.id,
      ownerId: row.ownerId,
      title: row.title,
      description: row.description,
      startDate: row.startDate,
      endDate: row.endDate,
      coverImageUrl: row.coverImageUrl,
      baseCurrency: row.baseCurrency,
      travelCurrency: row.travelCurrency,
      isLocked: row.isLocked,
      mode: _parseMode(row.mode),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  TripMode _parseMode(String name) {
    for (final m in TripMode.values) {
      if (m.name == name) return m;
    }
    return TripMode.plan;
  }
}

/// 旅程削除前の確認ダイアログ等で使う関連エンティティの件数。
class TripStats {
  const TripStats({
    required this.dayCount,
    required this.topicCount,
    required this.checklistCount,
  });

  final int dayCount;
  final int topicCount;
  final int checklistCount;
}
