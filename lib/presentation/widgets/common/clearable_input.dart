import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 入力欄の `suffixIcon` に渡すクリア (×) ボタン。
///
/// [controller] の中身が空でないときだけ × アイコンを表示し、
/// 押下すると入力をクリアする。
/// 既存の `TextField` / `TextFormField` の `decoration:` に
/// `suffixIcon: clearSuffixFor(_controller)` の形で挿入できる。
Widget clearSuffixFor(
  TextEditingController controller, {
  String tooltip = 'クリア',
  VoidCallback? onCleared,
}) {
  return ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (controller.text.isEmpty) return const SizedBox.shrink();
      return IconButton(
        icon: const Icon(Icons.close_rounded, size: 18),
        color: AppColors.softGray,
        splashRadius: 18,
        tooltip: tooltip,
        onPressed: () {
          controller.clear();
          onCleared?.call();
        },
      );
    },
  );
}
