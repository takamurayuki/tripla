import 'package:flutter/foundation.dart';

import 'topic_category.dart';
import 'transport_mode.dart';

/// 要件定義書 §6.1 Topic エンティティ + Location をフラット化 + 移動情報。
@immutable
class Topic {
  Topic({
    required this.id,
    required this.dayId,
    this.parentTopicId,
    required this.orderIndex,
    required this.category,
    required this.title,
    this.description,
    this.startTime,
    this.endTime,
    this.latitude,
    this.longitude,
    this.locationName,
    this.address,
    this.cost,
    this.costCurrency,
    this.isCompleted = false,
    this.departure,
    this.destination,
    this.transportMode,
    required this.createdAt,
    required this.updatedAt,
  })  : assert(title.trim().isNotEmpty, 'title must not be empty'),
        assert(orderIndex >= 0, 'orderIndex must be >= 0'),
        assert(
          startTime == null || endTime == null || !startTime.isAfter(endTime),
          'startTime must be on or before endTime',
        );

  final String id;
  final String dayId;
  final String? parentTopicId;
  final int orderIndex;
  final TopicCategory category;
  final String title;
  final String? description;
  final DateTime? startTime;
  final DateTime? endTime;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String? address;
  final double? cost;
  final String? costCurrency;
  final bool isCompleted;

  /// 移動カテゴリ専用フィールド: 出発地。
  final String? departure;

  /// 移動カテゴリ専用フィールド: 到着地。
  final String? destination;

  /// 移動カテゴリ専用フィールド: 移動手段。
  final TransportMode? transportMode;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isChild => parentTopicId != null;
  bool get hasTime => startTime != null;
  bool get hasLocation => latitude != null && longitude != null;
  bool get hasCost => cost != null;
  bool get isTransport => category == TopicCategory.transport;

  Topic copyWith({
    String? parentTopicId,
    int? orderIndex,
    TopicCategory? category,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    double? latitude,
    double? longitude,
    String? locationName,
    String? address,
    double? cost,
    String? costCurrency,
    bool? isCompleted,
    String? departure,
    String? destination,
    TransportMode? transportMode,
    DateTime? updatedAt,
  }) {
    return Topic(
      id: id,
      dayId: dayId,
      parentTopicId: parentTopicId ?? this.parentTopicId,
      orderIndex: orderIndex ?? this.orderIndex,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      address: address ?? this.address,
      cost: cost ?? this.cost,
      costCurrency: costCurrency ?? this.costCurrency,
      isCompleted: isCompleted ?? this.isCompleted,
      departure: departure ?? this.departure,
      destination: destination ?? this.destination,
      transportMode: transportMode ?? this.transportMode,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
