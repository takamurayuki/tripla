import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/day.dart';
import '../../providers/day_providers.dart';
import '../../providers/trip_providers.dart';
import '../../widgets/trita/trita_speech_bubble.dart';
import '../../widgets/trita/trita_state.dart';
import '../../widgets/trita/trita_widget.dart';
import '../trip_detail/widgets/day_timeline.dart';
import '../trip_detail/widgets/topic_editor_sheet.dart';

/// マイスケジュールの「1 日分」 を表示する全画面。
///
/// ホームの [スケジュール] カレンダーで日付をタップすると遷移してくる。
/// 旅行計画モードの Day タイムラインと同じ操作感で予定を時系列順に登録/編集できる。
/// 個別の予定追加・編集は既存の TopicEditorSheet をそのまま使う
/// (旅行計画モードと同じ操作感)。
class ScheduleDayScreen extends ConsumerWidget {
  const ScheduleDayScreen({super.key, required this.dayId});

  final String dayId;

  static final _headerFormat = DateFormat('M月d日 (E)', 'ja');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayAsync = ref.watch(dayByIdProvider(dayId));
    return dayAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
      data: (day) {
        if (day == null) return const _DayMissing();
        return _ScheduleDayBody(day: day, headerFormat: _headerFormat);
      },
    );
  }
}

class _ScheduleDayBody extends ConsumerWidget {
  const _ScheduleDayBody({required this.day, required this.headerFormat});

  final Day day;
  final DateFormat headerFormat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripByIdProvider(day.tripId));
    return tripAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
      data: (trip) {
        if (trip == null) return const _DayMissing();
        final locked = trip.isLocked || day.isLocked;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              headerFormat.format(day.date),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.triplaTealDark,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
              tooltip: '戻る',
            ),
          ),
          body: DayTimeline(
            day: day,
            tripId: trip.id,
            tripLocked: trip.isLocked,
            showDayHeader: false,
            tripMode: trip.mode,
          ),
          floatingActionButton: locked
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => showTopicEditorSheet(
                    context: context,
                    day: day,
                    tripMode: trip.mode,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('予定を追加'),
                ),
        );
      },
    );
  }
}

class _DayMissing extends StatelessWidget {
  const _DayMissing();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const TritaWidget(state: TritaState.thinking, size: 160),
              const SizedBox(height: 12),
              const TritaSpeechBubble(message: 'この日のスケジュールが見つからなかったよ...'),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => context.go('/home'),
                child: const Text('ホームに戻る'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
