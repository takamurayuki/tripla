import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/trip.dart';

/// 旅程詳細ヘッダー用の小さな部品群。
///
/// 元々 TripHeaderCard (84px の独立カード) として大きく表示していたが、
/// 画面圧迫を避けるため AppBar 内に直接埋め込めるよう以下の 2 つの小型ウィジェットに分解した。
/// - [TripPeriodChip] : タイトルの右に置く小さな期間チップ
/// - [TripCountdownBadge] : AppBar actions の左端に置く 2 行カウントダウン
///
/// カウントダウン判定ロジックは `_resolveCountdown` に集約 (このファイル内 private)。

class TripPeriodChip extends StatelessWidget {
  const TripPeriodChip({super.key, required this.trip});

  final Trip trip;

  static final _fullFormat = DateFormat('yyyy/M/d');
  static final _shortFormat = DateFormat('M/d');

  /// 同じ年なら yyyy/M/d - M/d、 違う年なら両側に年を付ける。
  String _label() {
    if (trip.startDate.year == trip.endDate.year) {
      return '${_fullFormat.format(trip.startDate)} - '
          '${_shortFormat.format(trip.endDate)}';
    }
    return '${_fullFormat.format(trip.startDate)} - '
        '${_fullFormat.format(trip.endDate)}';
  }

  @override
  Widget build(BuildContext context) {
    // AppBar.title 内で Text と並べた際、 デフォルトの center 配置だと
    // チップ側の line-height が短いぶんタイトル文字に対して気持ち上にズレて見える。
    // top に 2px の余白を足して視覚的に揃える。
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.softSkyBlue.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _label(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.triplaTealDark,
          ),
        ),
      ),
    );
  }
}

class TripCountdownBadge extends StatelessWidget {
  const TripCountdownBadge({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final c = _resolveCountdown(trip);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: c.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: c.color.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              c.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: c.color,
                height: 1.1,
              ),
            ),
            Text(
              c.message,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: c.color,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

_Countdown _resolveCountdown(Trip trip) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start =
      DateTime(trip.startDate.year, trip.startDate.month, trip.startDate.day);
  final end =
      DateTime(trip.endDate.year, trip.endDate.month, trip.endDate.day);

  final daysToStart = start.difference(today).inDays;
  if (daysToStart > 14) {
    return _Countdown(
      label: 'あと$daysToStart日',
      message: '計画を進めよう！',
      color: AppColors.triplaTeal,
    );
  }
  if (daysToStart > 7) {
    return _Countdown(
      label: 'あと$daysToStart日',
      message: 'そろそろ準備！',
      color: AppColors.warmOrange,
    );
  }
  if (daysToStart > 0) {
    return _Countdown(
      label: 'あと$daysToStart日',
      message: 'もうすぐ出発！',
      color: AppColors.warmOrange,
    );
  }
  if (daysToStart == 0) {
    return _Countdown(
      label: '今日出発',
      message: 'いってらっしゃい！',
      color: AppColors.coralRed,
    );
  }
  if (!today.isAfter(end)) {
    return _Countdown(
      label: '旅行中',
      message: '楽しんでね！',
      color: AppColors.triplaTeal,
    );
  }
  return _Countdown(
    label: '旅完了',
    message: 'おつかれさま！',
    color: AppColors.softGray,
  );
}

class _Countdown {
  const _Countdown({
    required this.label,
    required this.message,
    required this.color,
  });

  final String label;
  final String message;
  final Color color;
}
