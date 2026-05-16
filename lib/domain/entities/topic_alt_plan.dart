import 'package:flutter/foundation.dart';

import 'topic_category.dart';
import 'transport_mode.dart';

/// Topic の代替プラン (プランB, C ...)。
///
/// 移動 / 予定どちらにも使える汎用エンティティ。
/// - 移動モード: departure / destination / transportMode を使う
/// - 予定モード: title / category を使う
/// 共通: startTime / endTime / note / label
///
/// Topic 本体が「現在採用中のプラン」、altPlans が「代替案」のセマンティック。
/// JSON 後方互換: 古い transport_plan のフィールドだけが入った
/// レコードは title=null/category=null として読み込まれ、移動用として動作する。
@immutable
class TopicAltPlan {
  const TopicAltPlan({
    required this.id,
    this.label,
    this.title,
    this.category,
    this.departure,
    this.destination,
    this.transportMode,
    this.startTime,
    this.endTime,
    this.note,
  });

  final String id;

  /// 「プランB」など。null/空のときは UI 側で自動採番表示する。
  final String? label;

  /// 予定モードの表示タイトル (例: 清水寺観光)。
  final String? title;

  /// 予定モードのカテゴリ。
  final TopicCategory? category;

  // 移動モード
  final String? departure;
  final String? destination;
  final TransportMode? transportMode;

  // 共通
  final DateTime? startTime;
  final DateTime? endTime;
  final String? note;

  /// 移動用フィールドだけ入っているか?  UI/サマリ表示の振り分け用。
  /// title が空かつ category が null のとき移動扱い。
  bool get isTransportShape => (title == null || title!.isEmpty) && category == null;

  TopicAltPlan copyWith({
    String? label,
    String? title,
    TopicCategory? category,
    String? departure,
    String? destination,
    TransportMode? transportMode,
    DateTime? startTime,
    DateTime? endTime,
    String? note,
  }) {
    return TopicAltPlan(
      id: id,
      label: label ?? this.label,
      title: title ?? this.title,
      category: category ?? this.category,
      departure: departure ?? this.departure,
      destination: destination ?? this.destination,
      transportMode: transportMode ?? this.transportMode,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (label != null) 'label': label,
        if (title != null) 'title': title,
        if (category != null) 'category': category!.name,
        if (departure != null) 'departure': departure,
        if (destination != null) 'destination': destination,
        if (transportMode != null) 'transportMode': transportMode!.name,
        if (startTime != null) 'startTime': startTime!.toIso8601String(),
        if (endTime != null) 'endTime': endTime!.toIso8601String(),
        if (note != null) 'note': note,
      };

  factory TopicAltPlan.fromJson(Map<String, dynamic> json) {
    return TopicAltPlan(
      id: json['id'] as String,
      label: json['label'] as String?,
      title: json['title'] as String?,
      category: _parseCategory(json['category'] as String?),
      departure: json['departure'] as String?,
      destination: json['destination'] as String?,
      transportMode: _parseMode(json['transportMode'] as String?),
      startTime: _parseDate(json['startTime'] as String?),
      endTime: _parseDate(json['endTime'] as String?),
      note: json['note'] as String?,
    );
  }

  static TopicCategory? _parseCategory(String? name) {
    if (name == null) return null;
    for (final c in TopicCategory.values) {
      if (c.name == name) return c;
    }
    return null;
  }

  static TransportMode? _parseMode(String? name) {
    if (name == null) return null;
    for (final m in TransportMode.values) {
      if (m.name == name) return m;
    }
    return null;
  }

  static DateTime? _parseDate(String? iso) {
    if (iso == null) return null;
    return DateTime.tryParse(iso);
  }
}
