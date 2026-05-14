import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/handle_async_action.dart';
import '../../../../domain/entities/checklist_item.dart';
import '../../../../domain/entities/day.dart';
import '../../../../domain/entities/topic.dart';
import '../../../providers/checklist_providers.dart';
import '../../../providers/current_user_provider.dart';
import '../../../providers/day_providers.dart';
import '../../../providers/topic_providers.dart';
import '../../../widgets/trita/trita_speech_bubble.dart';
import '../../../widgets/trita/trita_state.dart';
import '../../../widgets/trita/trita_widget.dart';
import 'add_checklist_item_dialog.dart';

/// 「持ち物」上位タブ。
///
/// 「旅全体」と「Day 別」の 2 階層でセクション表示し、上から下にスクロールするだけで
/// 一気にチェックできる。各セクションのヘッダーは水色帯で区切る。
/// 追加は FAB「持ち物を追加」一箇所からのみ (ダイアログ内でスコープ選択)。
class ChecklistTabView extends ConsumerWidget {
  const ChecklistTabView({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(checklistItemsProvider(tripId));
    final daysAsync = ref.watch(dayListProvider(tripId));
    final topicsAsync = ref.watch(tripTopicsProvider(tripId));

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (items) {
        final days = daysAsync.maybeWhen(
          data: (d) => d,
          orElse: () => const <Day>[],
        );
        final topics = topicsAsync.maybeWhen(
          data: (t) => t,
          orElse: () => const <Topic>[],
        );
        if (items.isEmpty) return const _ChecklistEmpty();
        return _GroupedChecklist(
          tripId: tripId,
          items: items,
          days: days,
          topics: topics,
        );
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

class _GroupedChecklist extends StatelessWidget {
  const _GroupedChecklist({
    required this.tripId,
    required this.items,
    required this.days,
    required this.topics,
  });

  final String tripId;
  final List<ChecklistItem> items;
  final List<Day> days;
  final List<Topic> topics;

  static final _dateFormat = DateFormat('M/d (E)', 'ja');

  @override
  Widget build(BuildContext context) {
    final checkedCount = items.where((i) => i.isChecked).length;
    final progress = items.isEmpty ? 0.0 : checkedCount / items.length;
    final allDone = items.isNotEmpty && checkedCount == items.length;

    final topicById = {for (final t in topics) t.id: t};

    // 旅全体
    final tripItems =
        items.where((i) => i.dayId == null && i.topicId == null).toList();
    // Day 別 (Topic 経由を含む)
    final byDay = <String, List<ChecklistItem>>{};
    for (final item in items) {
      if (item.dayId == null && item.topicId == null) continue;
      var dayId = item.dayId;
      if (dayId == null && item.topicId != null) {
        dayId = topicById[item.topicId!]?.dayId;
      }
      if (dayId == null) continue;
      byDay.putIfAbsent(dayId, () => []).add(item);
    }

    final progressColor =
        allDone ? AppColors.bandanaGreen : AppColors.warmOrange;

    return Column(
      children: [
        // 全行程合計の進捗ヘッダー
        // (バッジと混同しないよう「全行程の合計」と明示し、緑/オレンジで状態を直感化)
        Container(
          color: progressColor.withValues(alpha: 0.12),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    allDone
                        ? Icons.check_circle_rounded
                        : Icons.luggage_rounded,
                    color: progressColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      allDone ? '全行程の準備 完了!' : '全行程の進捗',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.darkBrown,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Text(
                    '$checkedCount / ${items.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: progressColor,
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
                  color: progressColor,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              _SectionHeader(
                title: '旅全体',
                subtitle: '旅程全体で必要なもの',
                done: tripItems.where((i) => i.isChecked).length,
                total: tripItems.length,
              ),
              if (tripItems.isEmpty)
                const _EmptySectionRow()
              else
                for (final item in tripItems)
                  _ChecklistTile(item: item, tripId: tripId),
              for (final d in days) ...[
                _SectionHeader(
                  title: 'Day ${d.dayNumber}',
                  subtitle: _dateFormat.format(d.date),
                  done: (byDay[d.id] ?? const [])
                      .where((i) => i.isChecked)
                      .length,
                  total: (byDay[d.id] ?? const []).length,
                ),
                if ((byDay[d.id] ?? const []).isEmpty)
                  const _EmptySectionRow()
                else
                  for (final item in byDay[d.id]!)
                    _ChecklistTile(
                      item: item,
                      tripId: tripId,
                      relatedTopic: item.topicId == null
                          ? null
                          : topicById[item.topicId!],
                    ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 水色帯のセクションヘッダー (旅全体 / Day 別 共通)。
/// バッジ色は予定カードの `_ChecklistCountBadge` と同色 (bandanaGreen / warmOrange) を採用し、
/// 全行程の進捗ヘッダーとはアイコン + ラベルで区別する。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.total,
  });

  final String title;
  final String subtitle;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final hasItems = total > 0;
    final allDone = hasItems && done == total;
    final badgeBg = !hasItems
        ? AppColors.softGray.withValues(alpha: 0.18)
        : allDone
            ? AppColors.bandanaGreen.withValues(alpha: 0.20)
            : AppColors.warmOrange.withValues(alpha: 0.20);
    final badgeFg = !hasItems
        ? AppColors.softGray
        : allDone
            ? AppColors.bandanaGreen
            : AppColors.warmOrange;
    return Container(
      color: AppColors.softSkyBlue.withValues(alpha: 0.5),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.triplaTealDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.softGray,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (hasItems)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    allDone
                        ? Icons.check_circle_rounded
                        : Icons.luggage_rounded,
                    size: 12,
                    color: badgeFg,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$done / $total',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: badgeFg,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptySectionRow extends StatelessWidget {
  const _EmptySectionRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Text(
        'まだありません',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.softGray,
            ),
      ),
    );
  }
}

class _ChecklistTile extends ConsumerWidget {
  const _ChecklistTile({
    required this.item,
    required this.tripId,
    this.relatedTopic,
  });

  final ChecklistItem item;
  final String tripId;
  final Topic? relatedTopic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(checklistRepositoryProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final canModify = item.createdByUserId == currentUserId;

    final tile = CheckboxListTile(
      value: item.isChecked,
      onChanged: (v) => handleAsyncAction(
        context,
        () => repo.toggleChecked(item.id, v ?? false),
        errorMessage: 'チェック状態を更新できませんでした',
      ),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      visualDensity: VisualDensity.compact,
      title: _buildTitleRow(context),
      subtitle: _buildSubtitle(context),
      // 予定カードの持ち物バッジと統一 (bandanaGreen)
      activeColor: AppColors.bandanaGreen,
      checkColor: Colors.white,
      contentPadding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
      tileColor: Colors.transparent,
      secondary: canModify
          ? _ChecklistItemMenu(item: item, tripId: tripId)
          : null,
    );

    if (!canModify) return tile;

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
      child: tile,
    );
  }

  Widget _buildTitleRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            item.name,
            style: TextStyle(
              fontSize: 14,
              decoration:
                  item.isChecked ? TextDecoration.lineThrough : null,
              color:
                  item.isChecked ? AppColors.softGray : AppColors.darkBrown,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (relatedTopic != null) ...[
          const SizedBox(width: 6),
          _TopicTag(topic: relatedTopic!, faded: item.isChecked),
        ],
      ],
    );
  }

  Widget? _buildSubtitle(BuildContext context) {
    if (item.category == null || item.category!.isEmpty) return null;
    return Text(
      item.category!,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

/// アイテム末尾の「⋯」メニュー。編集 / 削除をまとめて出す。
/// 作成者のみ表示される (Dismissible スワイプ削除と並立)。
class _ChecklistItemMenu extends ConsumerWidget {
  const _ChecklistItemMenu({required this.item, required this.tripId});

  final ChecklistItem item;
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_ChecklistItemAction>(
      tooltip: 'アクション',
      icon: const Icon(
        Icons.more_vert_rounded,
        size: 18,
        color: AppColors.softGray,
      ),
      onSelected: (action) {
        switch (action) {
          case _ChecklistItemAction.edit:
            showEditChecklistItemDialog(
              context: context,
              tripId: tripId,
              existing: item,
            );
          case _ChecklistItemAction.delete:
            handleAsyncAction(
              context,
              () => ref.read(checklistRepositoryProvider).delete(item.id),
              errorMessage: '持ち物を削除できませんでした',
            );
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _ChecklistItemAction.edit,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18, color: AppColors.darkBrown),
              SizedBox(width: 8),
              Text('編集'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _ChecklistItemAction.delete,
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: AppColors.coralRed),
              SizedBox(width: 8),
              Text('削除', style: TextStyle(color: AppColors.coralRed)),
            ],
          ),
        ),
      ],
    );
  }
}

enum _ChecklistItemAction { edit, delete }

/// 持ち物アイテム右に置く「予定タグ」。
/// カテゴリ色 + アイコン + 予定タイトル で、どの予定に紐づく持ち物かを一目で示す。
class _TopicTag extends StatelessWidget {
  const _TopicTag({required this.topic, this.faded = false});

  final Topic topic;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final cat = topic.category;
    final color = faded ? AppColors.softGray : cat.color;
    final bg = (faded ? AppColors.softGray : cat.color).withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cat.icon, size: 12, color: color),
          const SizedBox(width: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              topic.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
