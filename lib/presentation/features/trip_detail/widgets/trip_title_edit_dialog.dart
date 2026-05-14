import 'package:flutter/material.dart';

import '../../../../domain/entities/trip.dart';

/// 旅程タイトルを編集する単純なダイアログ。
///
/// Phase 1.2 の範囲ではタイトル変更のみ。
/// 期間 / カバー / 通貨 などの編集はマイルストーン 1.3 以降で旅程編集画面に統合予定。
Future<String?> showTripTitleEditDialog({
  required BuildContext context,
  required Trip trip,
}) {
  final controller = TextEditingController(text: trip.title);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('タイトルを編集'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'タイトル',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.of(dialogContext).pop(text);
            },
            child: const Text('保存'),
          ),
        ],
      );
    },
  );
}
