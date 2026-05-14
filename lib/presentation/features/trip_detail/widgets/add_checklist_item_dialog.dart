import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/handle_async_action.dart';
import '../../../../domain/entities/checklist_item.dart';
import '../../../../domain/entities/day.dart';
import '../../../../domain/entities/topic.dart';
import '../../../providers/checklist_providers.dart';
import '../../../providers/current_user_provider.dart';
import '../../../providers/day_providers.dart';
import '../../../providers/topic_providers.dart';

/// 持ち物追加ダイアログ。
///
/// [availableDays] が空ならスコープ選択 UI は出ず「旅全体」固定。
/// 1 件以上ある場合は ChoiceChip で「旅全体 / Day 1 / Day 2 ...」を選び、
/// Day を選ぶと配下の **予定 (移動以外)** も任意で指定できる。
/// 移動 Topic は持ち物の対象にならないので候補から除外する。
///
/// 既定の選択は [initialDayId] (null なら旅全体)、[initialTopicId] (null なら Day 直接)。
Future<void> showAddChecklistItemDialog({
  required BuildContext context,
  required String tripId,
  List<Day> availableDays = const [],
  List<Topic> availableTopics = const [],
  String? initialDayId,
  String? initialTopicId,
}) async {
  final nameController = TextEditingController();
  final categoryController = TextEditingController();
  String? selectedDayId = initialDayId;
  String? selectedTopicId = initialTopicId;

  try {
    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            // 移動 (transport) は持ち物の対象外なので除外
            final topicsForDay = selectedDayId == null
                ? const <Topic>[]
                : availableTopics
                    .where((t) =>
                        t.dayId == selectedDayId &&
                        t.parentTopicId == null &&
                        !t.isTransport)
                    .toList();
            return AlertDialog(
              title: const Text('持ち物を追加'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    if (availableDays.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const _Label('追加先'),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ChoiceChip(
                            label: const Text('旅全体'),
                            selected: selectedDayId == null,
                            onSelected: (_) => setLocalState(() {
                              selectedDayId = null;
                              selectedTopicId = null;
                            }),
                          ),
                          for (final d in availableDays)
                            ChoiceChip(
                              label: Text('Day ${d.dayNumber}'),
                              selected: selectedDayId == d.id,
                              onSelected: (_) => setLocalState(() {
                                selectedDayId = d.id;
                                selectedTopicId = null;
                              }),
                            ),
                        ],
                      ),
                      if (selectedDayId != null) ...[
                        const SizedBox(height: 12),
                        const _Label('予定 (任意)'),
                        const SizedBox(height: 6),
                        if (topicsForDay.isEmpty)
                          Text(
                            'この Day には対象の予定がまだありません',
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: AppColors.softGray,
                                ),
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ChoiceChip(
                                label: const Text('予定を指定しない'),
                                selected: selectedTopicId == null,
                                onSelected: (_) => setLocalState(
                                    () => selectedTopicId = null),
                              ),
                              for (final t in topicsForDay)
                                ChoiceChip(
                                  avatar: Icon(
                                    t.category.icon,
                                    size: 14,
                                    color: t.category.color,
                                  ),
                                  label: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 180),
                                    child: Text(
                                      t.title,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  selected: selectedTopicId == t.id,
                                  onSelected: (_) => setLocalState(
                                      () => selectedTopicId = t.id),
                                ),
                            ],
                          ),
                      ],
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('アイテム名を入力してください'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('追加'),
                ),
              ],
            );
          },
        );
      },
    );

    if (added == true && context.mounted) {
      final container = ProviderScope.containerOf(context, listen: false);
      await handleAsyncAction(
        context,
        () => container.read(checklistRepositoryProvider).create(
              tripId: tripId,
              name: nameController.text.trim(),
              category: categoryController.text.trim().isEmpty
                  ? null
                  : categoryController.text.trim(),
              dayId: selectedDayId,
              topicId: selectedTopicId,
              createdByUserId: container.read(currentUserIdProvider),
            ),
        errorMessage: '持ち物を追加できませんでした',
      );
    }
  } finally {
    // ダイアログ終了後 (キャンセル / 追加 / 例外いずれも) で controller を解放
    nameController.dispose();
    categoryController.dispose();
  }
}

/// 既存の持ち物アイテムを編集するダイアログ。
///
/// 名前 / カテゴリ / スコープ (旅全体 / Day / 予定) を変更できる。
/// availableDays / availableTopics は内部で provider から取得する。
Future<void> showEditChecklistItemDialog({
  required BuildContext context,
  required String tripId,
  required ChecklistItem existing,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);

  // 編集ダイアログは追加と異なり provider から最新一覧を取得する
  final days = await container.read(dayListProvider(tripId).future);
  final topics = await container.read(tripTopicsProvider(tripId).future);
  if (!context.mounted) return;

  final nameController = TextEditingController(text: existing.name);
  final categoryController =
      TextEditingController(text: existing.category ?? '');
  String? selectedDayId = existing.dayId;
  String? selectedTopicId = existing.topicId;

  // 予定経由のアイテム編集時、selectedDayId が null でも topicId から逆引きで埋める
  if (selectedDayId == null && selectedTopicId != null) {
    final topic = topics
        .where((t) => t.id == selectedTopicId)
        .cast<Topic?>()
        .firstWhere((_) => true, orElse: () => null);
    selectedDayId = topic?.dayId;
  }

  try {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            final topicsForDay = selectedDayId == null
                ? const <Topic>[]
                : topics
                    .where((t) =>
                        t.dayId == selectedDayId &&
                        t.parentTopicId == null &&
                        !t.isTransport)
                    .toList();
            return AlertDialog(
              title: const Text('持ち物を編集'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'アイテム名',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: 'カテゴリ (任意)',
                      ),
                    ),
                    if (days.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const _Label('追加先'),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ChoiceChip(
                            label: const Text('旅全体'),
                            selected: selectedDayId == null,
                            onSelected: (_) => setLocalState(() {
                              selectedDayId = null;
                              selectedTopicId = null;
                            }),
                          ),
                          for (final d in days)
                            ChoiceChip(
                              label: Text('Day ${d.dayNumber}'),
                              selected: selectedDayId == d.id,
                              onSelected: (_) => setLocalState(() {
                                selectedDayId = d.id;
                                selectedTopicId = null;
                              }),
                            ),
                        ],
                      ),
                      if (selectedDayId != null) ...[
                        const SizedBox(height: 12),
                        const _Label('予定 (任意)'),
                        const SizedBox(height: 6),
                        if (topicsForDay.isEmpty)
                          Text(
                            'この Day には対象の予定がまだありません',
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: AppColors.softGray,
                                ),
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ChoiceChip(
                                label: const Text('予定を指定しない'),
                                selected: selectedTopicId == null,
                                onSelected: (_) => setLocalState(
                                    () => selectedTopicId = null),
                              ),
                              for (final t in topicsForDay)
                                ChoiceChip(
                                  avatar: Icon(
                                    t.category.icon,
                                    size: 14,
                                    color: t.category.color,
                                  ),
                                  label: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 180),
                                    child: Text(
                                      t.title,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  selected: selectedTopicId == t.id,
                                  onSelected: (_) => setLocalState(
                                      () => selectedTopicId = t.id),
                                ),
                            ],
                          ),
                      ],
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('アイテム名を入力してください'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true && context.mounted) {
      await handleAsyncAction(
        context,
        () => container.read(checklistRepositoryProvider).updateItem(
              id: existing.id,
              name: nameController.text.trim(),
              category: categoryController.text.trim().isEmpty
                  ? null
                  : categoryController.text.trim(),
              dayId: selectedDayId,
              topicId: selectedTopicId,
            ),
        errorMessage: '持ち物を更新できませんでした',
      );
    }
  } finally {
    nameController.dispose();
    categoryController.dispose();
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.softGray,
        ),
      ),
    );
  }
}
