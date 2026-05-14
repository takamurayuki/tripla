import 'package:flutter/foundation.dart';

/// 要件定義書 §6.1 Day エンティティ。
@immutable
class Day {
  const Day({
    required this.id,
    required this.tripId,
    required this.dayNumber,
    required this.date,
    this.note,
    this.isLocked = false,
  });

  final String id;
  final String tripId;
  final int dayNumber;
  final DateTime date;
  final String? note;

  /// Day 個別の編集ロック。Trip.isLocked と OR で実効ロック状態が決まる。
  final bool isLocked;

  Day copyWith({String? note, bool? isLocked}) {
    return Day(
      id: id,
      tripId: tripId,
      dayNumber: dayNumber,
      date: date,
      note: note ?? this.note,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}
