import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/handle_async_action.dart';
import '../../../domain/entities/trip.dart';
import '../../../domain/entities/trip_mode.dart';
import '../../providers/trip_providers.dart';
import '../trip_detail/widgets/trip_title_edit_dialog.dart';
import '../../widgets/header/tripla_header.dart';
import '../../widgets/trita/trita_speech_bubble.dart';
import '../../widgets/trita/trita_state.dart';
import '../../widgets/trita/trita_widget.dart';
import 'widgets/home_mode_switch.dart';
import 'widgets/schedule_home_view.dart';
import 'widgets/trip_card.dart';

/// S-03 ホーム画面。
///
/// 上部ヘッダー右側のスイッチで「旅行計画 / スケジュール」を切り替え:
/// - 旅行計画: 旅程一覧 (StreamProvider) を表示
/// - スケジュール: アプリ全体で 1 つの「マイスケジュール」のカレンダー UI
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  TripMode _mode = TripMode.plan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TriplaHeader(
        actions: [
          HomeModeSwitch(
            mode: _mode,
            onChanged: (m) => setState(() => _mode = m),
          ),
        ],
      ),
      // スケジュールモードでは旅程一覧の購読は不要なので、 build 内で分岐する。
      // (mode 切替時に Stream の再購読が起きないよう、 watch も分岐側でだけ呼ぶ)
      body: _mode.isPlan
          ? const _PlanModeBody()
          : const ScheduleHomeView(),
      floatingActionButton: _mode.isPlan
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/trips/new'),
              icon: const Icon(Icons.add),
              label: const Text('新規作成'),
            )
          : null,
    );
  }
}

class _PlanModeBody extends ConsumerWidget {
  const _PlanModeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripListProvider);
    return tripsAsync.when(
      loading: () => const _HomeLoading(),
      error: (error, _) => _HomeError(message: '$error'),
      data: (trips) =>
          trips.isEmpty ? const _HomeEmptyState() : _HomeTripList(trips: trips),
    );
  }
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TritaWidget(state: TritaState.thinking, size: 160),
          SizedBox(height: 16),
          TritaSpeechBubble(message: '少し待ってね...'),
        ],
      ),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const TritaWidget(state: TritaState.thinking, size: 160),
            const SizedBox(height: 16),
            const TritaSpeechBubble(message: 'うまく読み込めなかった...'),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const TritaWidget(state: TritaState.holdCamera, size: 200),
            const SizedBox(height: 16),
            const TritaSpeechBubble(message: '次の旅行はどこ？'),
            const SizedBox(height: 32),
            Text(
              'まだ旅程がありません',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '「新規作成」から最初の旅をはじめよう',
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

class _HomeTripList extends ConsumerWidget {
  const _HomeTripList({required this.trips});

  final List<Trip> trips;

  /// カード長押しで開くアクションシート (タイトルを編集 / 旅程を削除)。
  /// 旅程詳細画面まで遷移しなくても一覧から管理操作できるようにする。
  Future<void> _showTripActions(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) async {
    final action = await showModalBottomSheet<_TripAction>(
      context: context,
      backgroundColor: AppColors.paperWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  trip.title,
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.triplaTealDark,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded,
                  color: AppColors.triplaTeal),
              title: const Text('タイトルを編集'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_TripAction.editTitle),
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline_rounded, color: AppColors.coralRed),
              title: const Text(
                '旅程を削除',
                style: TextStyle(color: AppColors.coralRed),
              ),
              onTap: () => Navigator.of(sheetContext).pop(_TripAction.delete),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _TripAction.editTitle:
        await _onEditTitle(context, ref, trip);
      case _TripAction.delete:
        await _onDelete(context, ref, trip);
    }
  }

  Future<void> _onEditTitle(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) async {
    final newTitle = await showTripTitleEditDialog(
      context: context,
      trip: trip,
    );
    if (newTitle == null || newTitle == trip.title) return;
    if (!context.mounted) return;
    await handleAsyncAction(
      context,
      () => ref
          .read(tripRepositoryProvider)
          .update(trip.copyWith(title: newTitle)),
      errorMessage: 'タイトルを保存できませんでした',
    );
  }

  /// 削除確認は旅程詳細画面 (_TripDetailViewState._onDelete) と同じ文言・挙動。
  /// 削除後の遷移は不要 (tripListProvider が Stream なので一覧は自動更新)。
  Future<void> _onDelete(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) async {
    final stats =
        await ref.read(tripRepositoryProvider).collectStats(trip.id);
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('旅程を削除しますか？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('「${trip.title}」を削除すると元に戻せないよ。'),
            const SizedBox(height: 12),
            Text(
              '一緒に削除されるもの:\n'
              '・Day  ${stats.dayCount} 個\n'
              '・予定 ${stats.topicCount} 件\n'
              '・持ち物 ${stats.checklistCount} 件',
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coralRed),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await handleAsyncAction(
      context,
      () => ref.read(tripRepositoryProvider).delete(trip.id),
      errorMessage: '旅程を削除できませんでした',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: trips.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final trip = trips[index];
        return TripCard(
          trip: trip,
          onTap: () => context.push('/trips/${trip.id}'),
          onLongPress: () => _showTripActions(context, ref, trip),
        );
      },
    );
  }
}

enum _TripAction { editTitle, delete }
