import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/day.dart';
import '../../../../domain/entities/trip.dart';
import '../../../providers/day_providers.dart';
import 'day_timeline.dart';

/// 旅程詳細の「計画」上位タブ。
///
/// 内部に Day 切替の下位 TabBar を持ち、現在選択中の Day を [currentDay] で
/// 親 (TripDetailScreen) に通知する。親はそれを使って FAB の「予定を追加」が
/// どの Day に対して動くか決める。
class PlanTabView extends ConsumerStatefulWidget {
  const PlanTabView({
    super.key,
    required this.trip,
    required this.currentDay,
  });

  final Trip trip;

  /// 親に現在 Day を通知するための ValueNotifier。
  /// 何も選ばれていない (Day が無い) ときは null。
  final ValueNotifier<Day?> currentDay;

  @override
  ConsumerState<PlanTabView> createState() => _PlanTabViewState();
}

class _PlanTabViewState extends ConsumerState<PlanTabView>
    with SingleTickerProviderStateMixin {
  TabController? _controller;
  List<Day> _days = const [];
  bool _ensured = false;

  Future<void> _ensureDays() async {
    if (_ensured) return;
    _ensured = true;
    await ref.read(dayRepositoryProvider).ensureDaysForTrip(widget.trip);
  }

  void _syncController(List<Day> days) {
    if (_controller == null || _controller!.length != days.length) {
      _controller?.dispose();
      _controller = TabController(length: days.length, vsync: this)
        ..addListener(_onTabChanged);
    }
    _days = days;
    // build 中に ValueNotifier を変更すると notifyListeners が握りつぶされ、
    // ValueListenableBuilder (FAB 等) が再描画されない。次フレームで通知する。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _publishCurrentDay();
    });
  }

  void _onTabChanged() {
    if (_controller?.indexIsChanging ?? false) return;
    _publishCurrentDay();
  }

  void _publishCurrentDay() {
    if (_days.isEmpty || _controller == null) {
      widget.currentDay.value = null;
      return;
    }
    final i = _controller!.index.clamp(0, _days.length - 1);
    widget.currentDay.value = _days[i];
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTabChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final daysAsync = ref.watch(dayListProvider(widget.trip.id));
    return daysAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (days) {
        _ensureDays();
        if (days.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        _syncController(days);
        return Column(
          children: [
            Material(
              color: AppColors.paperWhite,
              child: TabBar(
                controller: _controller,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.triplaTeal,
                labelColor: AppColors.triplaTeal,
                unselectedLabelColor: AppColors.softGray,
                tabs: [
                  for (final d in days) Tab(text: 'Day ${d.dayNumber}'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _controller,
                children: [
                  for (final d in days)
                    DayTimeline(
                      day: d,
                      tripId: widget.trip.id,
                      tripLocked: widget.trip.isLocked,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
