import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../widgets/trita/trita_speech_bubble.dart';
import '../../../widgets/trita/trita_state.dart';
import '../../../widgets/trita/trita_widget.dart';

/// 「メンバー」上位タブ。要件 §F-006 / §F-016 で扱うメンバー招待・共有機能は
/// Phase 2 で本格実装する。現在はプレースホルダ。
class MemberTabView extends StatelessWidget {
  const MemberTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const TritaWidget(state: TritaState.banzai, size: 160),
            const SizedBox(height: 8),
            const TritaSpeechBubble(message: '誰と行く？'),
            const SizedBox(height: 20),
            Text(
              'メンバー招待 / 共有リンクは\nPhase 2 マイルストーンで実装予定',
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
