import 'package:flutter/foundation.dart';

/// 要件定義書 §6.1 ChecklistItem。
@immutable
class ChecklistItem {
  ChecklistItem({
    required this.id,
    required this.tripId,
    this.category,
    required this.name,
    this.isChecked = false,
    required this.orderIndex,
    required this.createdAt,
  })  : assert(name.trim().isNotEmpty, 'name must not be empty'),
        assert(orderIndex >= 0, 'orderIndex must be >= 0');

  final String id;
  final String tripId;
  final String? category;
  final String name;
  final bool isChecked;
  final int orderIndex;
  final DateTime createdAt;

  ChecklistItem copyWith({
    String? category,
    String? name,
    bool? isChecked,
    int? orderIndex,
  }) {
    return ChecklistItem(
      id: id,
      tripId: tripId,
      category: category ?? this.category,
      name: name ?? this.name,
      isChecked: isChecked ?? this.isChecked,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt,
    );
  }
}
