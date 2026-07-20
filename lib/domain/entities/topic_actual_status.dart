import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Topic の実績記録ステータス。
///
/// 遅延の有無・分数はここには保持しない (Topic.actualStartDelayMinutes で
/// 都度計算する)。ここで保存するのは時刻差では表現できない状態のみ。
enum TopicActualStatus {
  /// まだ実績が記録されていない (既定状態)。
  notRecorded('未記録', Icons.radio_button_unchecked_rounded, AppColors.softGray),

  /// 実施した (開始/終了時刻または「実施した」が記録済み)。
  recorded('記録済み', Icons.check_circle_rounded, AppColors.bandanaGreen),

  /// 予定を中止・スキップした。
  skipped('スキップ', Icons.cancel_rounded, AppColors.coralRed),

  /// 内容を変更して実施した。
  changed('変更して実施', Icons.edit_note_rounded, AppColors.warmOrange);

  const TopicActualStatus(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}
