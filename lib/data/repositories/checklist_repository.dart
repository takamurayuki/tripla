import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/checklist_item.dart';
import '../datasources/local/database.dart';

class ChecklistRepository {
  ChecklistRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final TriplaDatabase _db;
  final Uuid _uuid;

  /// 指定旅程の持ち物一覧を、未チェック → チェック済の順、orderIndex 昇順で監視。
  Stream<List<ChecklistItem>> watchByTrip(String tripId) {
    final query = _db.select(_db.checklistItems)
      ..where((t) => t.tripId.equals(tripId))
      ..orderBy([
        (t) => OrderingTerm.asc(t.isChecked),
        (t) => OrderingTerm.asc(t.orderIndex),
      ]);
    return query.watch().map(
          (rows) => rows.map(_toEntity).toList(growable: false),
        );
  }

  Future<String> create({
    required String tripId,
    required String name,
    String? category,
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
          ),
        );
    return id;
  }

  Future<void> toggleChecked(String id, bool value) async {
    await (_db.update(_db.checklistItems)..where((t) => t.id.equals(id)))
        .write(ChecklistItemsCompanion(isChecked: Value(value)));
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.checklistItems)..where((t) => t.id.equals(id))).go();
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
      category: row.category,
      name: row.name,
      isChecked: row.isChecked,
      orderIndex: row.orderIndex,
      createdAt: row.createdAt,
    );
  }
}
