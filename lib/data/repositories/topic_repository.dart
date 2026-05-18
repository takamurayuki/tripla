import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/topic.dart';
import '../../domain/entities/topic_alt_plan.dart';
import '../../domain/entities/topic_category.dart';
import '../../domain/entities/topic_link.dart';
import '../../domain/entities/train_transfer.dart';
import '../../domain/entities/transport_mode.dart';
import '../datasources/local/database.dart';

class TopicRepository {
  TopicRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final TriplaDatabase _db;
  final Uuid _uuid;

  /// 指定 Day の Topic 群を orderIndex 昇順で監視。
  Stream<List<Topic>> watchByDay(String dayId) {
    final query = _db.select(_db.topics)
      ..where((t) => t.dayId.equals(dayId))
      ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]);
    return query.watch().map(
          (rows) => rows.map(_toEntity).toList(growable: false),
        );
  }

  /// 複数 Day の Topic を 1 本の Stream で監視。
  /// ダッシュボード等、Day 数分の購読を 1 つにまとめたい場面で使う。
  Stream<List<Topic>> watchByDayIds(List<String> dayIds) {
    if (dayIds.isEmpty) return Stream.value(const []);
    final query = _db.select(_db.topics)
      ..where((t) => t.dayId.isIn(dayIds))
      ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]);
    return query.watch().map(
          (rows) => rows.map(_toEntity).toList(growable: false),
        );
  }

  /// 指定 ID の Topic 単体 Stream。存在しない (削除済み等) なら null。
  Stream<Topic?> watchById(String id) {
    final query = _db.select(_db.topics)..where((t) => t.id.equals(id));
    return query.watchSingleOrNull().map((row) => row == null ? null : _toEntity(row));
  }

  /// Topic を新規作成し ID を返す。orderIndex は末尾に追加。
  Future<String> create({
    required String dayId,
    String? parentTopicId,
    required TopicCategory category,
    required String title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? departure,
    String? destination,
    TransportMode? transportMode,
    List<TopicAltPlan> altPlans = const [],
    List<TopicLink> links = const [],
    String? colorHex,
    List<String> photos = const [],
    List<TrainTransfer> trainTransfers = const [],
  }) async {
    final maxOrder = await _maxOrderIndex(dayId, parentTopicId: parentTopicId);
    final now = DateTime.now();
    final id = _uuid.v4();
    await _db.into(_db.topics).insert(
          TopicsCompanion.insert(
            id: id,
            dayId: dayId,
            parentTopicId: Value(parentTopicId),
            orderIndex: maxOrder + 1,
            category: category.name,
            title: title,
            description: Value(description),
            startTime: Value(startTime),
            endTime: Value(endTime),
            departure: Value(departure),
            destination: Value(destination),
            transportMode: Value(transportMode?.name),
            altPlans: Value(_encodePlans(altPlans)),
            links: Value(_encodeLinks(links)),
            colorHex: Value(colorHex),
            photos: Value(_encodePhotos(photos)),
            trainTransfers: Value(_encodeTransfers(trainTransfers)),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> update(Topic topic) async {
    final updated = topic.copyWith(updatedAt: DateTime.now());
    await _db.update(_db.topics).replace(_toCompanion(updated));
  }

  Future<void> delete(String id) async {
    await _db.transaction(() async {
      await (_db.update(_db.topics)..where((t) => t.parentTopicId.equals(id)))
          .write(const TopicsCompanion(parentTopicId: Value<String?>(null)));
      await (_db.delete(_db.topics)..where((t) => t.id.equals(id))).go();
    });
  }

  /// D&D 後のフラットな並び順を [orderedIds] のとおりに反映する。
  /// orderIndex を 0,1,2,... で振り直し、同一トランザクションで永続化する。
  Future<void> reorderForDay(String dayId, List<String> orderedIds) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.topics)
              ..where(
                  (t) => t.id.equals(orderedIds[i]) & t.dayId.equals(dayId)))
            .write(
          TopicsCompanion(
            orderIndex: Value(i),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  /// 指定 Topic の親予定を [parentTopicId] に変更する。
  /// null を渡すと親予定 (トップレベル) に昇格。
  /// 循環防止のため、親候補が自分自身もしくは自分の子孫の場合は何もしない。
  Future<void> setParent(String topicId, String? parentTopicId) async {
    if (parentTopicId == topicId) return;
    if (parentTopicId != null) {
      final descendants = await _descendantIds(topicId);
      if (descendants.contains(parentTopicId)) return;
    }
    await (_db.update(_db.topics)..where((t) => t.id.equals(topicId))).write(
      TopicsCompanion(
        parentTopicId: Value(parentTopicId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<Set<String>> _descendantIds(String topicId) async {
    final result = <String>{};
    final queue = <String>[topicId];
    while (queue.isNotEmpty) {
      final id = queue.removeLast();
      final rows = await (_db.select(_db.topics)
            ..where((t) => t.parentTopicId.equals(id)))
          .get();
      for (final row in rows) {
        if (result.add(row.id)) queue.add(row.id);
      }
    }
    return result;
  }

  Future<int> _maxOrderIndex(String dayId, {String? parentTopicId}) async {
    final query = _db.selectOnly(_db.topics)
      ..addColumns([_db.topics.orderIndex.max()])
      ..where(_db.topics.dayId.equals(dayId))
      ..where(parentTopicId == null
          ? _db.topics.parentTopicId.isNull()
          : _db.topics.parentTopicId.equals(parentTopicId));
    final row = await query.getSingleOrNull();
    return row?.read(_db.topics.orderIndex.max()) ?? -1;
  }

  Topic _toEntity(TopicRow row) {
    return Topic(
      id: row.id,
      dayId: row.dayId,
      parentTopicId: row.parentTopicId,
      orderIndex: row.orderIndex,
      category: _parseCategory(row.category),
      title: row.title,
      description: row.description,
      startTime: row.startTime,
      endTime: row.endTime,
      latitude: row.latitude,
      longitude: row.longitude,
      locationName: row.locationName,
      address: row.address,
      cost: row.cost,
      costCurrency: row.costCurrency,
      isCompleted: row.isCompleted,
      departure: row.departure,
      destination: row.destination,
      transportMode: _parseTransport(row.transportMode),
      altPlans: _decodePlans(row.altPlans),
      links: _decodeLinks(row.links),
      colorHex: row.colorHex,
      photos: _decodePhotos(row.photos),
      trainTransfers: _decodeTransfers(row.trainTransfers),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  TopicsCompanion _toCompanion(Topic t) {
    return TopicsCompanion(
      id: Value(t.id),
      dayId: Value(t.dayId),
      parentTopicId: Value(t.parentTopicId),
      orderIndex: Value(t.orderIndex),
      category: Value(t.category.name),
      title: Value(t.title),
      description: Value(t.description),
      startTime: Value(t.startTime),
      endTime: Value(t.endTime),
      latitude: Value(t.latitude),
      longitude: Value(t.longitude),
      locationName: Value(t.locationName),
      address: Value(t.address),
      cost: Value(t.cost),
      costCurrency: Value(t.costCurrency),
      isCompleted: Value(t.isCompleted),
      departure: Value(t.departure),
      destination: Value(t.destination),
      transportMode: Value(t.transportMode?.name),
      altPlans: Value(_encodePlans(t.altPlans)),
      links: Value(_encodeLinks(t.links)),
      colorHex: Value(t.colorHex),
      photos: Value(_encodePhotos(t.photos)),
      trainTransfers: Value(_encodeTransfers(t.trainTransfers)),
      createdAt: Value(t.createdAt),
      updatedAt: Value(t.updatedAt),
    );
  }

  String? _encodePlans(List<TopicAltPlan> plans) {
    if (plans.isEmpty) return null;
    return jsonEncode(plans.map((p) => p.toJson()).toList());
  }

  List<TopicAltPlan> _decodePlans(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => TopicAltPlan.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  String? _encodeLinks(List<TopicLink> links) {
    if (links.isEmpty) return null;
    return jsonEncode(links.map((l) => l.toJson()).toList());
  }

  List<TopicLink> _decodeLinks(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => TopicLink.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  String? _encodePhotos(List<String> paths) {
    if (paths.isEmpty) return null;
    return jsonEncode(paths);
  }

  List<String> _decodePhotos(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<String>().toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  String? _encodeTransfers(List<TrainTransfer> transfers) {
    if (transfers.isEmpty) return null;
    return jsonEncode(transfers.map((t) => t.toJson()).toList());
  }

  List<TrainTransfer> _decodeTransfers(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => TrainTransfer.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  TopicCategory _parseCategory(String name) {
    return TopicCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => TopicCategory.other,
    );
  }

  TransportMode? _parseTransport(String? name) {
    if (name == null) return null;
    for (final mode in TransportMode.values) {
      if (mode.name == name) return mode;
    }
    return null;
  }
}
