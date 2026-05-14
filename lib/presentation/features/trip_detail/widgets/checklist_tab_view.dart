import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/handle_async_action.dart';
import '../../../../domain/entities/checklist_item.dart';
import '../../../providers/checklist_providers.dart';
import '../../../widgets/trita/trita_speech_bubble.dart';
import '../../../widgets/trita/trita_state.dart';
import '../../../widgets/trita/trita_widget.dart';

/// 「持ち物」上位タブ。要件 §F-010 持ち物チェックリストの最小実装。
/// カテゴリ別 ExpansionTile や テンプレート機能は Phase 2 で拡張予定。
class ChecklistTabView extends ConsumerWidget {
  const ChecklistTabView({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(checklistItemsProvider(tripId));
    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (items) {
        if (items.isEmpty) return const _ChecklistEmpty();
        return _ChecklistList(items: items);
      },
    );
  }
}

class _ChecklistEmpty extends StatelessWidget {
  const _ChecklistEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const TritaWidget(state: TritaState.jump, size: 160),
            const SizedBox(height: 8),
            const TritaSpeechBubble(message: '持ち物チェックした？'),
            const SizedBox(height: 20),
            Text(
              '右下の「持ち物を追加」から\nアイテムを足していこう',
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

class _ChecklistList extends ConsumerWidget {
  const _ChecklistList({required this.items});

  final List<ChecklistItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkedCount = items.where((i) => i.isChecked).length;
    final progress = items.isEmpty ? 0.0 : checkedCount / items.length;

    return Column(
      children: [
        Container(
          color: AppColors.softSkyBlue.withValues(alpha: 0.35),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.luggage_rounded,
                      color: AppColors.triplaTeal),
                  const SizedBox(width: 8),
                  Text(
                    '$checkedCount / ${items.length} 個チェック済み',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.triplaTealDark,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.white,
                  color: AppColors.triplaTeal,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) =>
                _ChecklistTile(item: items[index]),
          ),
        ),
      ],
    );
  }
}

class _ChecklistTile extends ConsumerWidget {
  const _ChecklistTile({required this.item});

  final ChecklistItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(checklistRepositoryProvider);
    return Dismissible(
      key: ValueKey('checklist-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.coralRed,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => handleAsyncAction(
        context,
        () => repo.delete(item.id),
        errorMessage: '持ち物を削除できませんでした',
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: CheckboxListTile(
          value: item.isChecked,
          onChanged: (v) => handleAsyncAction(
            context,
            () => repo.toggleChecked(item.id, v ?? false),
            errorMessage: 'チェック状態を更新できませんでした',
          ),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            item.name,
            style: TextStyle(
              decoration:
                  item.isChecked ? TextDecoration.lineThrough : null,
              color:
                  item.isChecked ? AppColors.softGray : AppColors.darkBrown,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: item.category == null || item.category!.isEmpty
              ? null
              : Text(
                  item.category!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
          activeColor: AppColors.triplaTeal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
