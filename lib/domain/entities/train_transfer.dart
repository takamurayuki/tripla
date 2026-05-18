import 'package:flutter/foundation.dart';

/// 電車の乗換情報 (手入力)。
///
/// Topic の `trainTransfers` に並んで保持する。 順番がそのまま乗換順。
/// - [station] : 乗換駅 (例: 「東京」「品川」)
/// - [line] : 乗る路線 / 列車名 (例: 「JR山手線」「のぞみ 21 号」)
/// - [platform] : ホーム番号 (例: 「3」「5・6」)。 任意
/// - [transferMinutes] : この駅での乗換に要する時間 (分)。 任意
/// - [note] : メモ (例: 「中央改札を経由」)。 任意
@immutable
class TrainTransfer {
  const TrainTransfer({
    required this.id,
    required this.station,
    this.line,
    this.platform,
    this.transferMinutes,
    this.note,
  });

  final String id;
  final String station;
  final String? line;
  final String? platform;
  final int? transferMinutes;
  final String? note;

  TrainTransfer copyWith({
    String? station,
    String? line,
    String? platform,
    int? transferMinutes,
    String? note,
  }) {
    return TrainTransfer(
      id: id,
      station: station ?? this.station,
      line: line ?? this.line,
      platform: platform ?? this.platform,
      transferMinutes: transferMinutes ?? this.transferMinutes,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'station': station,
        if (line != null) 'line': line,
        if (platform != null) 'platform': platform,
        if (transferMinutes != null) 'transferMinutes': transferMinutes,
        if (note != null) 'note': note,
      };

  factory TrainTransfer.fromJson(Map<String, dynamic> json) {
    return TrainTransfer(
      id: json['id'] as String,
      station: json['station'] as String,
      line: json['line'] as String?,
      platform: json['platform'] as String?,
      transferMinutes: (json['transferMinutes'] as num?)?.toInt(),
      note: json['note'] as String?,
    );
  }
}
