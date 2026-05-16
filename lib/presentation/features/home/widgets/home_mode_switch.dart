import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/trip_mode.dart';

/// ホーム画面ヘッダーに置く [旅行計画 / スケジュール] 切替スイッチ。
///
/// 2 つのアイコン (飛行機 / カレンダー) を並べた小型ピル。
/// 選択中の側がティール背景でハイライトされる。
/// 通知アイコンより左に置く想定 (`actions:` 経由で渡す)。
class HomeModeSwitch extends StatelessWidget {
  const HomeModeSwitch({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final TripMode mode;
  final ValueChanged<TripMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.softSkyBlue.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SwitchChip(
              icon: Icons.flight_takeoff_rounded,
              tooltip: '旅行計画',
              selected: mode.isPlan,
              onTap: () => onChanged(TripMode.plan),
            ),
            _SwitchChip(
              icon: Icons.calendar_month_rounded,
              tooltip: 'スケジュール',
              selected: mode.isSchedule,
              onTap: () => onChanged(TripMode.schedule),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchChip extends StatelessWidget {
  const _SwitchChip({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? AppColors.triplaTeal : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : AppColors.softGray,
            ),
          ),
        ),
      ),
    );
  }
}
