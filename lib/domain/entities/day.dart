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
  });

  final String id;
  final String tripId;
  final int dayNumber;
  final DateTime date;
  final String? note;

  Day copyWith({String? note}) {
    return Day(
      id: id,
      tripId: tripId,
      dayNumber: dayNumber,
      date: date,
      note: note ?? this.note,
    );
  }
}
