import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/checklist_item.dart';
import '../datasources/local/database.dart';

class ChecklistRepository {
  ChecklistRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final TriplaDatabase _db;
  final Uuid _uuid;

  /// 指定旅程の持ち物一覧を orderIndex 昇順で監視。
  /// (チェック状態でソートすると、チェックを入れた瞬間に行が動いて
  ///  ユーザー体験が悪くなるので、orderIndex 固定にする)
  Stream<List<ChecklistItem>> watchByTrip(String tripId) {
    final query = _db.select(_db.checklistItems)
      ..where((t) => t.tripId.equals(tripId))
      ..orderBy([
        (t) => OrderingTerm.asc(t.orderIndex),
      ]);
    return query.watch().map(
          (rows) => rows.map(_toEntity).toList(growable: false),
        );
  }

  /// 持ち物を新規作成。
  /// - [dayId] / [topicId] でスコープを指定 (どちらも null = 旅全体)
  /// - [createdByUserId] の指定がなければ呼び出し側で渡す ('local-user' 固定の段階)
  Future<String> create({
    required String tripId,
    required String name,
    required String createdByUserId,
    String? category,
    String? dayId,
    String? topicId,
  }) async {
    final maxOrder = await _maxOrderIndex(tripId);
    final id = _uuid.v4();
    await _db.into(_db.checklistItems).insert(
          ChecklistItemsCompanion.insert(
            id: id,
            tripId: tripId,
            category: Value(category),
            name: name,
            orderIndex: maxOrder + 1,
            createdAt: DateTime.now(),
            dayId: Value(dayId),
            topicId: Value(topicId),
            createdByUserId: Value(createdByUserId),
          ),
        );
    return id;
  }

  Future<void> toggleChecked(String id, bool value) async {
    await (_db.update(_db.checklistItems)..where((t) => t.id.equals(id)))
        .write(ChecklistItemsCompanion(isChecked: Value(value)));
  }

  /// 編集 (アイテム名 / カテゴリ / スコープ) を保存。
  Future<void> updateItem({
    required String id,
    required String name,
    String? category,
    String? dayId,
    String? topicId,
  }) async {
    await (_db.update(_db.checklistItems)..where((t) => t.id.equals(id)))
        .write(ChecklistItemsCompanion(
      name: Value(name),
      category: Value(category),
      dayId: Value(dayId),
      topicId: Value(topicId),
    ));
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.checklistItems)..where((t) => t.id.equals(id))).go();
  }

  /// Day が消えた場合に、その Day 配下の持ち物を「旅全体」スコープに昇格する。
  /// 予定経由のもの (topicId != null) は対象外 (Topic 削除側で cascade 削除される)。
  Future<void> promoteToTripScope(List<String> orphanDayIds) async {
    if (orphanDayIds.isEmpty) return;
    await (_db.update(_db.checklistItems)
          ..where((t) =>
              t.dayId.isIn(orphanDayIds) & t.topicId.isNull()))
        .write(const ChecklistItemsCompanion(
      dayId: Value<String?>(null),
    ));
  }

  Future<int> _maxOrderIndex(String tripId) async {
    final query = _db.selectOnly(_db.checklistItems)
      ..addColumns([_db.checklistItems.orderIndex.max()])
      ..where(_db.checklistItems.tripId.equals(tripId));
    final row = await query.getSingleOrNull();
    return row?.read(_db.checklistItems.orderIndex.max()) ?? -1;
  }

  ChecklistItem _toEntity(ChecklistItemRow row) {
    return ChecklistItem(
      id: row.id,
      tripId: row.tripId,
      dayId: row.dayId,
      topicId: row.topicId,
      category: row.category,
      name: row.name,
      isChecked: row.isChecked,
      orderIndex: row.orderIndex,
      createdAt: row.createdAt,
      createdByUserId: row.createdByUserId,
    );
  }
}
