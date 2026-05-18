import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/handle_async_action.dart';
import '../../../domain/entities/day.dart';
import '../../../domain/entities/topic.dart';
import '../../../domain/entities/trip.dart';
import '../../providers/day_providers.dart';
import '../../providers/topic_providers.dart';
import '../../providers/trip_providers.dart';
import '../../widgets/trita/trita_speech_bubble.dart';
import '../../widgets/trita/trita_state.dart';
import '../../widgets/trita/trita_widget.dart';
import 'widgets/add_checklist_item_dialog.dart';
import 'widgets/checklist_tab_view.dart';
import 'widgets/dashboard_tab_view.dart';
import 'widgets/expense_tab_view.dart';
import 'widgets/member_tab_view.dart';
import 'widgets/plan_tab_view.dart';
import 'widgets/topic_editor_sheet.dart';
import 'widgets/trip_header_card.dart';
import 'widgets/trip_title_edit_dialog.dart';

/// S-04 旅程詳細画面。
///
/// 構成:
/// - AppBar (戻る + メニュー)
/// - TripHeaderCard (常時表示、カウントダウン)
/// - 上位 TabBar (ダッシュボード / 予定 / 持ち物 / 費用 / メンバー)
/// - TabBarView (各タブ)
/// FAB は上位タブインデックスに応じて切り替え。
class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripByIdProvider(tripId));
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
        if (trip == null) return const _TripMissing();
        return _TripDetailView(trip: trip);
      },
    );
  }
}

class _TripMissing extends StatelessWidget {
  const _TripMissing();

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
              const TritaSpeechBubble(message: 'この旅程は見つからなかったよ...'),
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

enum _OuterTab {
  dashboard('ダッシュボード', Icons.dashboard_rounded),
  plan('予定', Icons.event_note_rounded),
  checklist('持ち物', Icons.luggage_rounded),
  expense('費用', Icons.payments_rounded),
  member('メンバー', Icons.group_rounded);

  const _OuterTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _TripDetailView extends ConsumerStatefulWidget {
  const _TripDetailView({required this.trip});

  final Trip trip;

  @override
  ConsumerState<_TripDetailView> createState() => _TripDetailViewState();
}

class _TripDetailViewState extends ConsumerState<_TripDetailView> {
  static const _tabs = _OuterTab.values;
  final ValueNotifier<Day?> _currentDay = ValueNotifier<Day?>(null);

  /// 初期表示タブは「予定」。
  int _currentTab = 1;

  @override
  void dispose() {
    _currentDay.dispose();
    super.dispose();
  }

  Future<void> _onEditTitle() async {
    final newTitle = await showTripTitleEditDialog(
      context: context,
      trip: widget.trip,
    );
    if (newTitle == null || newTitle == widget.trip.title) return;
    if (!mounted) return;
    await handleAsyncAction(
      context,
      () => ref
          .read(tripRepositoryProvider)
          .update(widget.trip.copyWith(title: newTitle)),
      errorMessage: 'タイトルを保存できませんでした',
    );
  }

  Future<void> _onDelete() async {
    final stats = await ref
        .read(tripRepositoryProvider)
        .collectStats(widget.trip.id);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('旅程を削除しますか？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('「${widget.trip.title}」を削除すると元に戻せないよ。'),
            const SizedBox(height: 12),
            Text(
              '一緒に削除されるもの:\n'
              '・Day  ${stats.dayCount} 個\n'
              '・予定 ${stats.topicCount} 件\n'
              '・持ち物 ${stats.checklistCount} 件',
              style: Theme.of(context).textTheme.bodySmall,
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
    if (!mounted) return;
    final ok = await handleAsyncAction(
      context,
      () => ref.read(tripRepositoryProvider).delete(widget.trip.id),
      errorMessage: '旅程を削除できませんでした',
    );
    if (!ok || !mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Flexible(
              child: Text(
                trip.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.triplaTeal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TripPeriodChip(trip: trip),
          ],
        ),
        titleSpacing: 8,
        actions: [
          // 出発カウントダウン (元 TripHeaderCard 相当)。 ロック button のすぐ左に置く。
          TripCountdownBadge(trip: trip),
          _TripLockButton(trip: trip),
          PopupMenuButton<_MenuAction>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (action) {
              switch (action) {
                case _MenuAction.editTitle:
                  _onEditTitle();
                case _MenuAction.delete:
                  _onDelete();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _MenuAction.editTitle,
                child: ListTile(
                  leading: Icon(Icons.edit_rounded),
                  title: Text('タイトルを編集'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _MenuAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded,
                      color: AppColors.coralRed),
                  title: Text('旅程を削除',
                      style: TextStyle(color: AppColors.coralRed)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTab,
        children: [
          DashboardTabView(trip: trip),
          PlanTabView(trip: trip, currentDay: _currentDay),
          ChecklistTabView(tripId: trip.id),
          const ExpenseTabView(),
          const MemberTabView(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (i) => setState(() => _currentTab = i),
        backgroundColor: AppColors.paperWhite,
        indicatorColor: AppColors.triplaTeal.withValues(alpha: 0.18),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 64,
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon, color: AppColors.softGray),
              selectedIcon: Icon(t.icon, color: AppColors.triplaTeal),
              label: t.label,
            ),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget? _buildFab() {
    final tab = _tabs[_currentTab];
    switch (tab) {
      case _OuterTab.dashboard:
        return null;
      case _OuterTab.plan:
        return ValueListenableBuilder<Day?>(
          valueListenable: _currentDay,
          builder: (context, day, _) {
            if (day == null) return const SizedBox.shrink();
            // 実効ロック中は FAB「予定を追加」を出さない
            if (widget.trip.isLocked || day.isLocked) {
              return const SizedBox.shrink();
            }
            return FloatingActionButton.extended(
              onPressed: () =>
                  showTopicEditorSheet(context: context, day: day),
              icon: const Icon(Icons.add),
              label: const Text('予定を追加'),
            );
          },
        );
      case _OuterTab.checklist:
        // ダイアログ内でスコープ (旅全体 / Day / 予定) を選べるよう days / topics を渡す。
        final days = ref.watch(dayListProvider(widget.trip.id)).maybeWhen(
              data: (d) => d,
              orElse: () => const <Day>[],
            );
        final topics =
            ref.watch(tripTopicsProvider(widget.trip.id)).maybeWhen(
                  data: (t) => t,
                  orElse: () => const <Topic>[],
                );
        return FloatingActionButton.extended(
          onPressed: () => showAddChecklistItemDialog(
            context: context,
            tripId: widget.trip.id,
            availableDays: days,
            availableTopics: topics,
          ),
          icon: const Icon(Icons.add),
          label: const Text('持ち物を追加'),
        );
      case _OuterTab.expense:
        return null;
      case _OuterTab.member:
        return null;
    }
  }
}

enum _MenuAction { editTitle, delete }

/// 上位 TabBar 右端に置く Trip 一括ロックボタン。
/// トリ太の盾アイコンで「全体を保護」のメタファー。
class _TripLockButton extends ConsumerWidget {
  const _TripLockButton({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = trip.isLocked;
    return Tooltip(
      message: locked ? '一括ロックを解除' : '全 Day を一括ロック',
      child: IconButton(
        iconSize: 26,
        icon: Icon(
          locked ? Icons.shield_rounded : Icons.shield_outlined,
          color: locked ? AppColors.warmOrange : AppColors.softGray,
        ),
        onPressed: () => handleAsyncAction(
          context,
          () => ref
              .read(tripRepositoryProvider)
              .setLocked(trip.id, !locked),
          errorMessage: '一括ロックを更新できませんでした',
        ),
      ),
    );
  }
}
