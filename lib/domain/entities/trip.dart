import 'package:flutter/foundation.dart';

/// 要件定義書 §6.1 Trip エンティティ (UI/ドメイン層向けのイミュータブル表現)。
///
/// Drift のテーブル行モデルは別途自動生成される `TripRow`/`TripsCompanion` を使い、
/// リポジトリ層でこのドメインモデルに変換する。
@immutable
class Trip {
  Trip({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.startDate,
    required this.endDate,
    this.description,
    this.coverImageUrl,
    this.baseCurrency = 'JPY',
    this.travelCurrency,
    required this.createdAt,
    required this.updatedAt,
  })  : assert(title.trim().isNotEmpty, 'title must not be empty'),
        assert(!startDate.isAfter(endDate),
            'startDate ($startDate) must be on or before endDate ($endDate)');

  final String id;
  final String ownerId;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final String? coverImageUrl;
  final String baseCurrency;
  final String? travelCurrency;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 旅程の日数 (両端を含む)。
  int get dayCount =>
      endDate.difference(startDate).inDays + 1;

  Trip copyWith({
    String? id,
    String? ownerId,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? coverImageUrl,
    String? baseCurrency,
    String? travelCurrency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trip(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      travelCurrency: travelCurrency ?? this.travelCurrency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
