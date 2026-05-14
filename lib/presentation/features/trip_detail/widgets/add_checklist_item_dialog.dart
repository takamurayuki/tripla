import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/checklist_providers.dart';

/// 持ち物追加ダイアログ。カテゴリは任意、名前は必須。
Future<void> showAddChecklistItemDialog({
  required BuildContext context,
  required String tripId,
}) async {
  final nameController = TextEditingController();
  final categoryController = TextEditingController();

  final added = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('持ち物を追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'アイテム名',
                hintText: '例: 充電器',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(
                labelText: 'カテゴリ (任意)',
                hintText: '例: 電子機器',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('追加'),
          ),
        ],
      );
    },
  );

  if (added == true && context.mounted) {
    final container = ProviderScope.containerOf(context, listen: false);
    await container.read(checklistRepositoryProvider).create(
          tripId: tripId,
          name: nameController.text.trim(),
          category: categoryController.text.trim().isEmpty
              ? null
              : categoryController.text.trim(),
        );
  }
}
