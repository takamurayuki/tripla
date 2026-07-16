import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'topic_actual_status.dart';
import 'topic_alt_plan.dart';
import 'topic_category.dart';
import 'topic_link.dart';
import 'train_transfer.dart';
import 'transport_mode.dart';

/// 要件定義書 §6.1 Topic エンティティ + Location をフラット化 + 移動情報。
///
/// フィールド追加時は `topic_editor_sheet.dart` / `period_event_dialog.dart` の
/// `_onSave()` にある `Topic(...)` 直接構築箇所 (null クリアのため copyWith を
/// 使わない) にも新フィールドを引き継がせないと、既存編集のたびに値が消える。
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
    this.altPlans = const [],
    this.links = const [],
    this.colorHex,
    this.photos = const [],
    this.trainTransfers = const [],
    this.actualStartTime,
    this.actualEndTime,
    this.actualStatus = TopicActualStatus.notRecorded,
    this.actualNote,
    required this.createdAt,
    required this.updatedAt,
  })  : assert(title.trim().isNotEmpty, 'title must not be empty'),
        assert(orderIndex >= 0, 'orderIndex must be >= 0'),
        assert(
          startTime == null || endTime == null || !startTime.isAfter(endTime),
          'startTime must be on or before endTime',
        ),
        assert(
          actualStartTime == null ||
              actualEndTime == null ||
              !actualStartTime.isAfter(actualEndTime),
          'actualStartTime must be on or before actualEndTime',
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

  /// 代替プラン (プランB, C ...)。移動 / 予定どちらでも使える。
  ///
  /// Topic 本体が「現在採用中のプラン」、altPlans がそれ以外の候補。
  /// 旅行中の状況に応じて UI から swap (採用) して切り替える。
  final List<TopicAltPlan> altPlans;

  /// この予定に紐づくリンク (予約サイト・地図・公式 など)。
  /// タイムラインカードに OGP プレビューとして表示。
  final List<TopicLink> links;

  /// 表示色オーバーライド (`#RRGGBB` / `#AARRGGBB`)。
  /// 主に schedule モードの期間予定で利用。 null なら category.color を使う。
  final String? colorHex;

  /// 添付写真のファイルパス。 アプリのドキュメントディレクトリからの相対パス。
  final List<String> photos;

  /// 電車移動の乗換情報 (手入力)。 順番がそのまま乗換順。
  /// 移動カテゴリ + transportMode=train 以外でも持てるが、 UI 上は train だけで編集表示する。
  final List<TrainTransfer> trainTransfers;

  /// 実際に開始した時刻。 null なら未記録。
  final DateTime? actualStartTime;

  /// 実際に終了した時刻。 null なら未記録。
  final DateTime? actualEndTime;

  /// 実績ステータス。
  final TopicActualStatus actualStatus;

  /// 実績メモ (遅延理由・変更内容など)。
  final String? actualNote;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isChild => parentTopicId != null;
  bool get hasTime => startTime != null;
  bool get hasLocation => latitude != null && longitude != null;
  bool get hasCost => cost != null;
  bool get isTransport => category == TopicCategory.transport;

  /// 実績が何かしら記録されているか (notRecorded 以外)。
  bool get hasActualRecord => actualStatus != TopicActualStatus.notRecorded;

  /// 計画開始時刻に対する実績開始時刻の差分 (分)。 プラスが遅延、マイナスが前倒し。
  /// 計画/実績いずれかの開始時刻が無ければ計算不能 (null)。
  int? get actualStartDelayMinutes {
    if (startTime == null || actualStartTime == null) return null;
    return actualStartTime!.difference(startTime!).inMinutes;
  }

  /// この分数以内の差分は「予定通り」として扱う許容範囲。
  static const int delayToleranceMinutes = 5;

  /// 実績開始時刻が許容範囲を超えて遅延しているか。
  bool get isDelayedStart => (actualStartDelayMinutes ?? 0) > delayToleranceMinutes;

  /// startTime / endTime の日付が異なる「期間予定」 (出張 / 旅行 など) か。
  /// schedule モードのカレンダーで横断バー扱いし、 日ごとのタイムラインには出さない。
  bool get isPeriodEvent {
    if (startTime == null || endTime == null) return false;
    final s = DateTime(startTime!.year, startTime!.month, startTime!.day);
    final e = DateTime(endTime!.year, endTime!.month, endTime!.day);
    return e.isAfter(s);
  }

  /// 表示色。 [colorHex] が指定されていればそれを優先、 無ければ category.color。
  Color get displayColor {
    final hex = colorHex;
    if (hex != null && hex.isNotEmpty) {
      final parsed = _parseHexColor(hex);
      if (parsed != null) return parsed;
    }
    return category.color;
  }

  static Color? _parseHexColor(String hex) {
    var clean = hex.replaceFirst('#', '');
    if (clean.length == 6) clean = 'FF$clean';
    if (clean.length != 8) return null;
    final value = int.tryParse(clean, radix: 16);
    if (value == null) return null;
    return Color(value);
  }

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
    List<TopicAltPlan>? altPlans,
    List<TopicLink>? links,
    String? colorHex,
    List<String>? photos,
    List<TrainTransfer>? trainTransfers,
    DateTime? actualStartTime,
    DateTime? actualEndTime,
    TopicActualStatus? actualStatus,
    String? actualNote,
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
      altPlans: altPlans ?? this.altPlans,
      links: links ?? this.links,
      colorHex: colorHex ?? this.colorHex,
      photos: photos ?? this.photos,
      trainTransfers: trainTransfers ?? this.trainTransfers,
      actualStartTime: actualStartTime ?? this.actualStartTime,
      actualEndTime: actualEndTime ?? this.actualEndTime,
      actualStatus: actualStatus ?? this.actualStatus,
      actualNote: actualNote ?? this.actualNote,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
