import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'trip_mode.dart';

/// 要件定義書 §6.1 TopicCategory。
enum TopicCategory {
  transport('移動', Icons.directions_bus_rounded, AppColors.skyBlue),
  sightseeing('観光', Icons.photo_camera_rounded, AppColors.bandanaGreen),
  meal('食事', Icons.restaurant_rounded, AppColors.tritaYellow),
  lodging('宿泊', Icons.hotel_rounded, AppColors.deepNavy),
  shopping('買い物', Icons.shopping_bag_rounded, AppColors.coralRed),
  // schedule モード向けに追加 (旅行計画モードでは選択肢に出さない)
  work('仕事', Icons.work_rounded, AppColors.triplaTeal),
  rest('休憩', Icons.coffee_rounded, AppColors.mintGreen),
  reading('読書', Icons.menu_book_rounded, AppColors.warmOrange),
  study('勉強', Icons.school_rounded, AppColors.darkBrown),
  other('その他', Icons.bookmark_outline_rounded, AppColors.softGray);

  const TopicCategory(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

/// TripMode 別の表示差し替え。
///
/// - schedule モード:
///   - sightseeing → 「イベント」 (アイコン Icons.event_rounded) として扱う
///   - lodging は使わない
extension TopicCategoryDisplay on TopicCategory {
  String labelFor(TripMode mode) {
    if (mode.isSchedule && this == TopicCategory.sightseeing) return 'イベント';
    return label;
  }

  IconData iconFor(TripMode mode) {
    if (mode.isSchedule && this == TopicCategory.sightseeing) {
      return Icons.event_rounded;
    }
    return icon;
  }

  /// この mode で選択可能なカテゴリ一覧 (移動以外で、 編集シートのチップに使う)。
  ///
  /// - schedule: イベント (=sightseeing) / 食事 / 仕事 / 休憩 / 読書 / 勉強 / 買い物 / その他
  ///   (宿泊は対象外)
  /// - plan: 観光 / 食事 / 宿泊 / 買い物 / その他
  ///   (仕事 / 休憩 / 読書 / 勉強 は旅行用途にそぐわないので非表示)
  static const _scheduleOnly = {
    TopicCategory.work,
    TopicCategory.rest,
    TopicCategory.reading,
    TopicCategory.study,
  };

  static List<TopicCategory> selectableForPlanMode(TripMode mode) {
    final base =
        TopicCategory.values.where((c) => c != TopicCategory.transport);
    if (mode.isSchedule) {
      return base.where((c) => c != TopicCategory.lodging).toList();
    }
    return base.where((c) => !_scheduleOnly.contains(c)).toList();
  }
}
