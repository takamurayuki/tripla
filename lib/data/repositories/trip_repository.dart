import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/trip.dart';
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
  Stream<List<Trip>> watchAll() {
    final query = _db.select(_db.trips)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch().map(
          (rows) => rows.map(_toEntity).toList(growable: false),
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
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
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
            createdAt: Value(updated.createdAt),
            updatedAt: Value(updated.updatedAt),
          ),
        );
  }

  /// 旅程を ID 指定で削除する。
  Future<void> delete(String id) async {
    await (_db.delete(_db.trips)..where((t) => t.id.equals(id))).go();
  }

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
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
