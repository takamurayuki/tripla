import 'package:flutter/foundation.dart';

import 'transport_mode.dart';

/// 移動 (Topic.category == transport) の代替プラン。
///
/// たとえば「プランA = 9:00 の電車」「プランB = 10:00 のバス」のように、
/// 1 つの移動 Topic に対して複数の選択肢を保持する。Topic 本体が
/// 「現在採用中のプラン」、altPlans が「代替案」というセマンティック。
@immutable
class TransportPlan {
  const TransportPlan({
    required this.id,
    this.label,
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

  final String? departure;
  final String? destination;
  final TransportMode? transportMode;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? note;

  TransportPlan copyWith({
    String? label,
    String? departure,
    String? destination,
    TransportMode? transportMode,
    DateTime? startTime,
    DateTime? endTime,
    String? note,
  }) {
    return TransportPlan(
      id: id,
      label: label ?? this.label,
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
        if (departure != null) 'departure': departure,
        if (destination != null) 'destination': destination,
        if (transportMode != null) 'transportMode': transportMode!.name,
        if (startTime != null) 'startTime': startTime!.toIso8601String(),
        if (endTime != null) 'endTime': endTime!.toIso8601String(),
        if (note != null) 'note': note,
      };

  factory TransportPlan.fromJson(Map<String, dynamic> json) {
    return TransportPlan(
      id: json['id'] as String,
      label: json['label'] as String?,
      departure: json['departure'] as String?,
      destination: json['destination'] as String?,
      transportMode: _parseMode(json['transportMode'] as String?),
      startTime: _parseDate(json['startTime'] as String?),
      endTime: _parseDate(json['endTime'] as String?),
      note: json['note'] as String?,
    );
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
