import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../widgets/trita/trita_speech_bubble.dart';
import '../../../widgets/trita/trita_state.dart';
import '../../../widgets/trita/trita_widget.dart';

/// 「費用」上位タブ。要件 §F-011 費用計算・円換算は Phase 2 で本格実装。
/// 現在はプレースホルダ。
class ExpenseTabView extends StatelessWidget {
  const ExpenseTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const TritaWidget(state: TritaState.thinking, size: 160),
            const SizedBox(height: 8),
            const TritaSpeechBubble(message: 'これは Phase 2 で作るよ！'),
            const SizedBox(height: 20),
            Text(
              '費用記録 / 円換算 / 割り勘 などは\nPhase 2 マイルストーンで実装予定',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.softGray,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
