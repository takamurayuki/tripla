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
    this.isCompleted = false,
  });

  final String id;
  final String tripId;
  final int dayNumber;
  final DateTime date;
  final String? note;

  /// Day 個別の編集ロック。Trip.isLocked と OR で実効ロック状態が決まる。
  final bool isLocked;

  /// ユーザーが「この日を完了」 とマークしたか。
  /// タイムライン末尾の「おつかれさま！」 旗表示の出し分けに使う。
  final bool isCompleted;

  Day copyWith({String? note, bool? isLocked, bool? isCompleted}) {
    return Day(
      id: id,
      tripId: tripId,
      dayNumber: dayNumber,
      date: date,
      note: note ?? this.note,
      isLocked: isLocked ?? this.isLocked,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
