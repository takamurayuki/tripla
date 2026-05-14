import 'package:flutter/foundation.dart';

/// 要件定義書 §6.1 ChecklistItem。
///
/// スコープ:
/// - 旅全体  : [dayId] == null && [topicId] == null
/// - Day 直接: [dayId] != null && [topicId] == null
/// - 予定経由: [topicId] != null ([dayId] は Topic の Day を継承)
///
/// 削除権限は作成者 ([createdByUserId]) にのみある (Phase B で実効化)。
@immutable
class ChecklistItem {
  ChecklistItem({
    required this.id,
    required this.tripId,
    this.dayId,
    this.topicId,
    this.category,
    required this.name,
    this.isChecked = false,
    required this.orderIndex,
    required this.createdAt,
    this.createdByUserId = 'local-user',
  })  : assert(name.trim().isNotEmpty, 'name must not be empty'),
        assert(orderIndex >= 0, 'orderIndex must be >= 0');

  final String id;
  final String tripId;
  final String? dayId;
  final String? topicId;
  final String? category;
  final String name;
  final bool isChecked;
  final int orderIndex;
  final DateTime createdAt;
  final String createdByUserId;

  bool get isTripScoped => dayId == null && topicId == null;
  bool get isViaTopic => topicId != null;

  ChecklistItem copyWith({
    String? dayId,
    bool clearDayId = false,
    String? topicId,
    String? category,
    String? name,
    bool? isChecked,
    int? orderIndex,
  }) {
    return ChecklistItem(
      id: id,
      tripId: tripId,
      dayId: clearDayId ? null : (dayId ?? this.dayId),
      topicId: topicId ?? this.topicId,
      category: category ?? this.category,
      name: name ?? this.name,
      isChecked: isChecked ?? this.isChecked,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt,
      createdByUserId: createdByUserId,
    );
  }
}
