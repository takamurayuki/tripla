import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/day.dart';
import '../../../../domain/entities/topic.dart';
import '../../../../domain/entities/topic_category.dart';
import '../../../../domain/entities/trip.dart';
import '../../../providers/checklist_providers.dart';
import '../../../providers/day_providers.dart';
import '../../../providers/topic_providers.dart';
import '../../../widgets/trita/trita_speech_bubble.dart';
import '../../../widgets/trita/trita_state.dart';
import '../../../widgets/trita/trita_widget.dart';

/// 「ダッシュボード」上位タブ。
///
/// 予定の総数、持ち物の進捗、Day 別の予定数バーを表示する。
class DashboardTabView extends ConsumerWidget {
  const DashboardTabView({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysAsync = ref.watch(dayListProvider(trip.id));
    final checklistAsync = ref.watch(checklistItemsProvider(trip.id));

    return daysAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (days) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            const _GreetingCard(),
            const SizedBox(height: 16),
            checklistAsync.when(
              loading: () =>
                  const _ChecklistSummary(checked: 0, total: 0, loading: true),
              error: (_, _) => const SizedBox.shrink(),
              data: (items) => _ChecklistSummary(
                checked: items.where((i) => i.isChecked).length,
                total: items.length,
              ),
            ),
            const SizedBox(height: 16),
            _DayBreakdownCard(tripId: trip.id, days: days),
          ],
        );
      },
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.paperBorder),
      ),
      child: Row(
        children: [
          const TritaWidget(state: TritaState.holdCamera, size: 64),
          const SizedBox(width: 12),
          const Expanded(
            child: TritaSpeechBubble(
              message: '今のところこんな感じだよ！',
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistSummary extends StatelessWidget {
  const _ChecklistSummary({
    required this.checked,
    required this.total,
    this.loading = false,
  });

  final int checked;
  final int total;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : checked / total;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.luggage_rounded,
                  color: AppColors.triplaTeal, size: 22),
              const SizedBox(width: 8),
              Text(
                '持ち物の進捗',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              Text(
                loading ? '...' : '$checked / $total',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.triplaTealDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : progress,
              minHeight: 8,
              backgroundColor: AppColors.softSkyBlue.withValues(alpha: 0.4),
              color: AppColors.triplaTeal,
            ),
          ),
          if (total == 0) ...[
            const SizedBox(height: 8),
            Text(
              'まだ持ち物リストが空です。「持ち物」タブから追加できます。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _DayBreakdownCard extends ConsumerWidget {
  const _DayBreakdownCard({required this.tripId, required this.days});

  final String tripId;
  final List<Day> days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trip 配下の全 Topic を 1 本の Stream で監視 (Day 数分の購読を統合)。
    final topicsAsync = ref.watch(tripTopicsProvider(tripId));
    final allTopics = topicsAsync.maybeWhen(
      data: (t) => t,
      orElse: () => const <Topic>[],
    );
    // dayId → 親 Topic 一覧
    final parentsByDay = <String, List<Topic>>{};
    final countByDay = <String, int>{};
    for (final t in allTopics) {
      countByDay[t.dayId] = (countByDay[t.dayId] ?? 0) + 1;
      if (t.parentTopicId == null) {
        parentsByDay.putIfAbsent(t.dayId, () => []).add(t);
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_note_rounded,
                  color: AppColors.triplaTeal, size: 22),
              const SizedBox(width: 8),
              Text(
                '日ごとの予定',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _CategoryLegend(),
          const SizedBox(height: 12),
          if (days.isEmpty)
            Text(
              'まだ Day がありません。',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (final d in days)
              _DayRow(
                dayNumber: d.dayNumber,
                parents: parentsByDay[d.id] ?? const [],
                totalCount: countByDay[d.id] ?? 0,
              ),
        ],
      ),
    );
  }
}

class _CategoryLegend extends StatelessWidget {
  const _CategoryLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: [
        for (final cat in TopicCategory.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: cat.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                cat.label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.softGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// 1 日分の予定を「カテゴリ色のセグメントバー」で可視化する行。
///
/// 親トピックのみ並べて、orderIndex 順に色帯として描画する。
/// セグメント数が少ないときはアイコンも重ね、多いときは色だけにする。
/// 各セグメントは Tooltip でタイトルを表示し、ホバー / 長押しで内容確認できる。
class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.dayNumber,
    required this.parents,
    required this.totalCount,
  });

  final int dayNumber;
  final List<Topic> parents;
  final int totalCount;

  static const _iconThreshold = 6; // この件数以下ならアイコンを描画

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              'Day $dayNumber',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.softGray,
              ),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 24,
              child: parents.isEmpty
                  ? const _EmptySegmentBar()
                  : _SegmentedBar(parents: parents),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '$totalCount件',
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.triplaTealDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySegmentBar extends StatelessWidget {
  const _EmptySegmentBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.softSkyBlue.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.softSkyBlue.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: const Text(
        '予定なし',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.softGray,
        ),
      ),
    );
  }
}

class _SegmentedBar extends StatelessWidget {
  const _SegmentedBar({required this.parents});

  final List<Topic> parents;

  @override
  Widget build(BuildContext context) {
    final showIcon = parents.length <= _DayRow._iconThreshold;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          for (var i = 0; i < parents.length; i++) ...[
            Expanded(child: _Segment(topic: parents[i], showIcon: showIcon)),
            if (i < parents.length - 1) const SizedBox(width: 1),
          ],
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.topic, required this.showIcon});

  final Topic topic;
  final bool showIcon;

  IconData get _icon {
    if (topic.isTransport) {
      return topic.transportMode?.icon ?? Icons.swap_horiz_rounded;
    }
    return topic.category.icon;
  }

  String get _tooltip {
    final time = topic.startTime;
    final timeText = time == null
        ? ''
        : '${time.hour.toString().padLeft(2, '0')}:'
            '${time.minute.toString().padLeft(2, '0')}  ';
    return '$timeText${topic.title}';
  }

  @override
  Widget build(BuildContext context) {
    final color = topic.category.color;
    return Tooltip(
      message: _tooltip,
      waitDuration: const Duration(milliseconds: 250),
      child: Container(
        color: color,
        alignment: Alignment.center,
        child: showIcon
            ? Icon(_icon, size: 14, color: Colors.white)
            : const SizedBox.shrink(),
      ),
    );
  }
}
