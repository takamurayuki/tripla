import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// トリ太くんが喋る吹き出し。要件定義書 §F-012 「吹き出しメッセージ」。
class TritaSpeechBubble extends StatelessWidget {
  const TritaSpeechBubble({
    super.key,
    required this.message,
    this.maxWidth = 260,
  });

  final String message;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.triplaTeal, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.triplaTeal.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.darkBrown,
          ),
        ),
      ),
    );
  }
}
