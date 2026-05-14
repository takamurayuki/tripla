import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/trip.dart';
import '../../../widgets/trita/trita_state.dart';
import '../../../widgets/trita/trita_widget.dart';

/// 旅程詳細上部に常時表示されるサマリーカード。
///
/// 出発日までの状態を 4 段階に分け、トリ太のセリフ・カウントダウン色を
/// 切り替える。
class TripHeaderCard extends StatelessWidget {
  const TripHeaderCard({super.key, required this.trip});

  final Trip trip;

  static final _dateFormat = DateFormat('yyyy.MM.dd');

  _Countdown _resolveCountdown() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(
        trip.startDate.year, trip.startDate.month, trip.startDate.day);
    final end =
        DateTime(trip.endDate.year, trip.endDate.month, trip.endDate.day);

    final daysToStart = start.difference(today).inDays;
    if (daysToStart > 14) {
      return _Countdown(
        label: 'あと$daysToStart日',
        message: '計画を進めよう！',
        color: AppColors.triplaTeal,
        tritaState: TritaState.holdCamera,
      );
    }
    if (daysToStart > 7) {
      return _Countdown(
        label: 'あと$daysToStart日',
        message: 'そろそろ準備しよう！',
        color: AppColors.warmOrange,
        tritaState: TritaState.thinking,
      );
    }
    if (daysToStart > 0) {
      return _Countdown(
        label: 'あと$daysToStart日',
        message: 'もうすぐ出発！',
        color: AppColors.warmOrange,
        tritaState: TritaState.jump,
      );
    }
    if (daysToStart == 0) {
      return _Countdown(
        label: '今日出発',
        message: 'いってらっしゃい！',
        color: AppColors.coralRed,
        tritaState: TritaState.banzai,
      );
    }
    if (!today.isAfter(end)) {
      return _Countdown(
        label: '旅行中',
        message: '楽しんでね！',
        color: AppColors.triplaTeal,
        tritaState: TritaState.run,
      );
    }
    return _Countdown(
      label: '旅完了',
      message: 'おつかれさま！',
      color: AppColors.softGray,
      tritaState: TritaState.heartEyes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _resolveCountdown();

    return Semantics(
      label: '${trip.title}, ${c.label}, ${c.message}, '
          '${_dateFormat.format(trip.startDate)} から '
          '${_dateFormat.format(trip.endDate)} まで',
      container: true,
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      color: AppColors.paperWhite,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // トリ太ロゴ枠
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: c.color, width: 2),
              boxShadow: [
                BoxShadow(
                  color: c.color.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: TritaWidget(state: c.tritaState, size: 72),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trip.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.softGray,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  c.label,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: c.color,
                    height: 1.1,
                  ),
                ),
                Text(
                  c.message,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.color,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.triplaTeal.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_dateFormat.format(trip.startDate)} - '
                    '${_dateFormat.format(trip.endDate)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.triplaTealDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _Countdown {
  const _Countdown({
    required this.label,
    required this.message,
    required this.color,
    required this.tritaState,
  });

  final String label;
  final String message;
  final Color color;
  final TritaState tritaState;
}
