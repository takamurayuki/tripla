import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/day.dart';
import '../../../../domain/entities/topic.dart';
import '../../../../domain/entities/topic_actual_status.dart';
import '../../../../domain/entities/topic_category.dart';
import '../../../../domain/entities/trip.dart';
import '../../../providers/day_providers.dart';
import '../../../providers/topic_providers.dart';
import '../../../widgets/trita/trita_speech_bubble.dart';
import '../../../widgets/trita/trita_state.dart';
import '../../../widgets/trita/trita_widget.dart';

/// 「振り返り」上位タブ。
///
/// ダッシュボードが「計画側の集計 (これから何をするか)」なのに対し、
/// こちらは「実績側の集計 (実際どうだったか)」を Day 別比較 + Trip 全体サマリーで見せる。
class ReviewTabView extends ConsumerWidget {
  const ReviewTabView({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysAsync = ref.watch(dayListProvider(trip.id));
    final topicsAsync = ref.watch(tripTopicsProvider(trip.id));

    return daysAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (days) => topicsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (allTopics) {
          // 期間予定はダッシュボードと同様、Day 別集計・実績記録の対象外。
          final topics =
              allTopics.where((t) => !t.isPeriodEvent).toList(growable: false);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _ActualSummaryCard(topics: topics),
              const SizedBox(height: 16),
              _DayComparisonList(days: days, topics: topics),
            ],
          );
        },
      ),
    );
  }
}

/// Trip 全体の実績サマリー (実施率・予定通り率・平均遅延・スキップ件数・カテゴリ別遅延ランキング)。
class _ActualSummaryCard extends StatelessWidget {
  const _ActualSummaryCard({required this.topics});

  final List<Topic> topics;

  @override
  Widget build(BuildContext context) {
    final total = topics.length;
    final recorded = topics.where((t) => t.hasActualRecord).toList();

    if (total == 0 || recorded.isEmpty) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const TritaWidget(state: TritaState.thinking, size: 96),
            const SizedBox(height: 8),
            const TritaSpeechBubble(message: 'まだ実績が記録されていないよ'),
            const SizedBox(height: 8),
            Text(
              '「予定」タブの各カードから実績を記録すると、\nここに振り返りが表示されるよ。',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.softGray),
            ),
          ],
        ),
      );
    }

    final onTime = recorded
        .where((t) =>
            t.actualStatus == TopicActualStatus.recorded && !t.isDelayedStart)
        .length;
    final skipped =
        recorded.where((t) => t.actualStatus == TopicActualStatus.skipped).length;
    final changed =
        recorded.where((t) => t.actualStatus == TopicActualStatus.changed).length;

    final delayMinutesList = recorded
        .map((t) => t.actualStartDelayMinutes)
        .whereType<int>()
        .where((m) => m > 0)
        .toList();
    final avgDelay = delayMinutesList.isEmpty
        ? 0
        : (delayMinutesList.reduce((a, b) => a + b) / delayMinutesList.length)
            .round();

    final implementationRate = total == 0 ? 0.0 : recorded.length / total;
    final onTimeRate = recorded.isEmpty ? 0.0 : onTime / recorded.length;

    // カテゴリ別平均遅延 (上位3件)。
    final byCategory = <TopicCategory, List<int>>{};
    for (final t in recorded) {
      final d = t.actualStartDelayMinutes;
      if (d == null || d <= 0) continue;
      byCategory.putIfAbsent(t.category, () => []).add(d);
    }
    final categoryRanking = byCategory.entries
        .map((e) => (
              category: e.key,
              avg: e.value.reduce((a, b) => a + b) / e.value.length,
            ))
        .toList()
      ..sort((a, b) => b.avg.compareTo(a.avg));
    final topCategories = categoryRanking.take(3).toList();

    final happy = onTimeRate >= 0.7;
    final tritaState = happy
        ? (onTimeRate >= 0.9 ? TritaState.banzai : TritaState.heartEyes)
        : TritaState.run;
    final message = happy
        ? '予定通り率 ${(onTimeRate * 100).round()}%！ よく頑張ったね！'
        : (topCategories.isEmpty
            ? '今回は遅延が多かったよ。次回はゆとりを持って計画してみよう！'
            : '今回は${topCategories.first.category.label}で遅れが多かったよ。'
                '次回は余裕を持って計画してみよう！');

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
              const Icon(Icons.insights_rounded,
                  color: AppColors.triplaTeal, size: 22),
              const SizedBox(width: 8),
              Text('旅の振り返り', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TritaWidget(state: tritaState, size: 72),
              const SizedBox(width: 12),
              Expanded(child: TritaSpeechBubble(message: message)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatChip(
                icon: Icons.fact_check_rounded,
                label: '実施率',
                value: '${(implementationRate * 100).round()}%',
                color: AppColors.triplaTeal,
              ),
              _StatChip(
                icon: Icons.check_circle_rounded,
                label: '予定通り率',
                value: '${(onTimeRate * 100).round()}%',
                color: AppColors.bandanaGreen,
              ),
              _StatChip(
                icon: Icons.schedule_rounded,
                label: '平均遅延',
                value: avgDelay == 0 ? '-' : '$avgDelay分',
                color: AppColors.warmOrange,
              ),
              _StatChip(
                icon: Icons.cancel_rounded,
                label: 'スキップ',
                value: '$skipped件',
                color: AppColors.coralRed,
              ),
              if (changed > 0)
                _StatChip(
                  icon: Icons.edit_note_rounded,
                  label: '変更して実施',
                  value: '$changed件',
                  color: AppColors.warmOrange,
                ),
            ],
          ),
          if (topCategories.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'カテゴリ別平均遅延ランキング',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.triplaTealDark,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < topCategories.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text(
                      '${i + 1}.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.softGray,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(topCategories[i].category.icon,
                        size: 14, color: topCategories[i].category.color),
                    const SizedBox(width: 4),
                    Text(
                      topCategories[i].category.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkBrown,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '平均 ${topCategories[i].avg.round()}分遅れ',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.warmOrange,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Day 別の計画 vs 実績比較リスト。
class _DayComparisonList extends StatelessWidget {
  const _DayComparisonList({required this.days, required this.topics});

  final List<Day> days;
  final List<Topic> topics;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (var i = 0; i < days.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DayReviewCard(
              day: days[i],
              topics: topics
                  .where((t) => t.dayId == days[i].id)
                  .toList(growable: false)
                ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)),
              initiallyExpanded: i == 0,
            ),
          ),
      ],
    );
  }
}

class _DayReviewCard extends ConsumerStatefulWidget {
  const _DayReviewCard({
    required this.day,
    required this.topics,
    required this.initiallyExpanded,
  });

  final Day day;
  final List<Topic> topics;
  final bool initiallyExpanded;

  @override
  ConsumerState<_DayReviewCard> createState() => _DayReviewCardState();
}

class _DayReviewCardState extends ConsumerState<_DayReviewCard> {
  static const _autosaveDelay = Duration(milliseconds: 500);
  static final _dateFormat = DateFormat('M/d (E)', 'ja');

  late final TextEditingController _noteController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.day.note ?? '')
      ..addListener(_scheduleSave);
  }

  @override
  void dispose() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      final note = _noteController.text.trim();
      unawaited(ref
          .read(dayRepositoryProvider)
          .setNote(widget.day.id, note.isEmpty ? null : note));
    }
    _noteController.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(_autosaveDelay, _save);
  }

  Future<void> _save() async {
    final note = _noteController.text.trim();
    await ref
        .read(dayRepositoryProvider)
        .setNote(widget.day.id, note.isEmpty ? null : note);
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final topics = widget.topics;
    final recordedCount = topics.where((t) => t.hasActualRecord).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: widget.initiallyExpanded,
          title: Text(
            'Day ${day.dayNumber}  •  ${_dateFormat.format(day.date)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.triplaTealDark,
            ),
          ),
          subtitle: Text(
            '実績記録 $recordedCount / ${topics.length} 件',
            style: const TextStyle(fontSize: 12, color: AppColors.softGray),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            if (topics.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'この日は予定がありません。',
                  style: TextStyle(fontSize: 12, color: AppColors.softGray),
                ),
              )
            else
              for (final t in topics) _TopicComparisonRow(topic: t),
            const SizedBox(height: 12),
            const Text(
              '振り返りメモ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.triplaTealDark,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                hintText: '例: 電車遅延が多かったので次回は移動時間に余裕を持たせる',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1 予定分の「計画時刻 → 実績時刻」比較行。
class _TopicComparisonRow extends StatelessWidget {
  const _TopicComparisonRow({required this.topic});

  final Topic topic;

  static final _timeFormat = DateFormat('HH:mm');

  String _planText() {
    final s = topic.startTime;
    final e = topic.endTime;
    if (s == null) return '時刻未設定';
    if (e == null) return _timeFormat.format(s);
    return '${_timeFormat.format(s)} - ${_timeFormat.format(e)}';
  }

  (String, Color) _actualPresentation() {
    switch (topic.actualStatus) {
      case TopicActualStatus.notRecorded:
        return ('未記録', AppColors.softGray);
      case TopicActualStatus.skipped:
        return ('スキップ', AppColors.coralRed);
      case TopicActualStatus.changed:
        return ('変更して実施', AppColors.warmOrange);
      case TopicActualStatus.recorded:
        final s = topic.actualStartTime;
        final text = s == null ? '記録済み' : _timeFormat.format(s);
        final delay = topic.actualStartDelayMinutes;
        if (topic.isDelayedStart && delay != null) {
          return ('$text (+$delay分)', AppColors.warmOrange);
        }
        return (text, AppColors.bandanaGreen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final indent = topic.isChild ? 16.0 : 0.0;
    final (actualText, actualColor) = _actualPresentation();
    return Padding(
      padding: EdgeInsets.only(left: indent, top: 6, bottom: 6),
      child: Row(
        children: [
          Icon(topic.category.icon, size: 14, color: topic.category.color),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: Text(
              topic.title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _planText(),
              style: const TextStyle(fontSize: 11, color: AppColors.softGray),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.arrow_forward_rounded,
              size: 12, color: AppColors.softGray),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: Text(
              actualText,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: actualColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
