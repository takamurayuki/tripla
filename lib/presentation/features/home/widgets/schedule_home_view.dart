import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/day.dart';
import '../../../../domain/entities/topic.dart';
import '../../../../domain/entities/topic_category.dart';
import '../../../../domain/entities/trip.dart';
import '../../../../domain/entities/trip_mode.dart';
import '../../../providers/current_user_provider.dart';
import '../../../providers/day_providers.dart';
import '../../../providers/topic_providers.dart';
import '../../../providers/trip_providers.dart';
import '../../trip_detail/widgets/day_timeline.dart';
import '../../trip_detail/widgets/topic_editor_sheet.dart';
import 'period_event_dialog.dart';

/// ホーム画面 [スケジュール] モード時の表示。
///
/// 上部に [日 / 週 / 月] の切替セグメント。
/// - 月: 月カレンダー (セルに小ドット)。 セルタップ → ScheduleDayScreen 遷移
/// - 週: 7 日分の縦リスト。 各日の予定件数 + 最初の予定プレビュー
/// - 日: 1 日分の縦リスト。 全予定を時刻順に表示
///
/// schedule singleton (Trip + Day) は ScheduleDayScreen 側で
/// idempotent に作成されるので、 ここでは存在を前提にしない。
class ScheduleHomeView extends ConsumerStatefulWidget {
  const ScheduleHomeView({super.key});

  @override
  ConsumerState<ScheduleHomeView> createState() => _ScheduleHomeViewState();
}

enum _ViewMode { day, week, month }

class _ScheduleHomeViewState extends ConsumerState<ScheduleHomeView> {
  _ViewMode _viewMode = _ViewMode.month;

  /// 表示の基準日。 月モード = この月を表示 / 週モード = この日を含む週 / 日モード = この日
  late DateTime _focusDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusDate = DateTime(now.year, now.month, now.day);
  }

  void _setViewMode(_ViewMode m) {
    setState(() => _viewMode = m);
  }

  void _shift(int delta) {
    setState(() {
      switch (_viewMode) {
        case _ViewMode.day:
          _focusDate = _focusDate.add(Duration(days: delta));
        case _ViewMode.week:
          _focusDate = _focusDate.add(Duration(days: 7 * delta));
        case _ViewMode.month:
          _focusDate = DateTime(
            _focusDate.year,
            _focusDate.month + delta,
            1,
          );
      }
    });
  }

  /// セルタップ: schedule singleton と Day を idempotent に確保してから
  /// その日の画面 (/schedule/days/:dayId) へ遷移する。
  /// (週 / 月モードで日付タップしたときに使う)
  Future<void> _openDate(DateTime date) async {
    final trip = await _ensureScheduleTrip();
    if (trip == null || !mounted) return;
    try {
      final day = await ref
          .read(dayRepositoryProvider)
          .ensureDayForDate(tripId: trip.id, date: date);
      if (!mounted) return;
      context.push('/schedule/days/${day.id}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('スケジュールを準備できませんでした: $error')),
      );
    }
  }

  /// 日モードの FAB / 空状態 CTA から呼ばれる: 該当日に Topic 編集シートを開く。
  /// 画面遷移は行わない (この場で追加 → 同画面の DayTimeline に即反映)。
  Future<void> _addTopicInline(DateTime date) async {
    final trip = await _ensureScheduleTrip();
    if (trip == null || !mounted) return;
    try {
      final day = await ref
          .read(dayRepositoryProvider)
          .ensureDayForDate(tripId: trip.id, date: date);
      if (!mounted) return;
      await showTopicEditorSheet(
        context: context,
        day: day,
        tripMode: TripMode.schedule,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('スケジュールを準備できませんでした: $error')),
      );
    }
  }

  /// 期間予定ピルタップ時: 削除確認ダイアログ。
  Future<void> _onPeriodEventTap(Topic topic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('期間予定を削除しますか？'),
        content: Text('「${topic.title}」を削除します。 元に戻せません。'),
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
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(topicRepositoryProvider).delete(topic.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除に失敗しました: $error')),
      );
    }
  }

  /// schedule singleton (Trip) を idempotent に取得 / 作成。 失敗時は SnackBar 表示。
  Future<Trip?> _ensureScheduleTrip() async {
    final ownerId = ref.read(currentUserIdProvider);
    try {
      return await ref.read(tripRepositoryProvider).getOrCreateSchedule(ownerId);
    } catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('スケジュールを準備できませんでした: $error')),
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownerId = ref.watch(currentUserIdProvider);
    final scheduleAsync = ref.watch(scheduleTripProvider(ownerId));
    final trip = scheduleAsync.valueOrNull;

    final topicsAsync = trip == null
        ? const AsyncValue<List<Topic>>.data([])
        : ref.watch(tripTopicsProvider(trip.id));
    final daysAsync = trip == null
        ? const AsyncValue<List<Day>>.data([])
        : ref.watch(dayListProvider(trip.id));

    final topics = topicsAsync.valueOrNull ?? const <Topic>[];
    final days = daysAsync.valueOrNull ?? const <Day>[];

    // 日付 → Topic 群 のインデックス
    final topicsByDate = _groupTopicsByDate(topics, days);

    return Column(
      children: [
        _ViewModeSwitcher(
          mode: _viewMode,
          onChanged: _setViewMode,
        ),
        _PeriodNavigator(
          label: _periodLabel(),
          onPrev: () => _shift(-1),
          onNext: () => _shift(1),
        ),
        Expanded(
          child: _buildBody(trip, days, topicsByDate),
        ),
      ],
    );
  }

  /// 期間予定ダイアログを開くときの開始日の初期値。
  /// 表示月が今月なら今日、 違うなら表示月の 1 日を返す。
  DateTime _initialPeriodStart() {
    final today = DateTime.now();
    if (today.year == _focusDate.year && today.month == _focusDate.month) {
      return DateTime(today.year, today.month, today.day);
    }
    return DateTime(_focusDate.year, _focusDate.month, 1);
  }

  Widget _buildBody(
    Trip? trip,
    List<Day> days,
    Map<DateTime, List<Topic>> topicsByDate,
  ) {
    switch (_viewMode) {
      case _ViewMode.day:
        // この日付に対応する Day を探す。 なければ trip 未作成 or 未利用日付。
        Day? dayForDate;
        for (final d in days) {
          if (_isSameDay(d.date, _focusDate)) {
            dayForDate = d;
            break;
          }
        }
        return _DayTimelineView(
          trip: trip,
          day: dayForDate,
          date: _focusDate,
          onAddTopic: () => _addTopicInline(_focusDate),
        );
      case _ViewMode.week:
        return _WeekListView(
          startOfWeek: _startOfWeek(_focusDate),
          topicsByDate: topicsByDate,
          onOpenDate: _openDate,
        );
      case _ViewMode.month:
        // 月モードはセルに余裕が無いため移動カテゴリは表示対象外。
        // (日 / 週 では表示する)
        final monthTopics = {
          for (final entry in topicsByDate.entries)
            entry.key: entry.value
                .where((t) => !t.isTransport)
                .toList(growable: false),
        };
        // 月モードは Stack で「カレンダー本体」 +「右下 FAB (期間予定追加)」 を重ねる。
        return Stack(
          children: [
            Positioned.fill(
              child: _MonthGrid(
                month: DateTime(_focusDate.year, _focusDate.month, 1),
                topicsByDate: monthTopics,
                onSelect: _openDate,
                onPeriodEventTap: _onPeriodEventTap,
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                heroTag: 'schedule-period-add',
                onPressed: () => showPeriodEventDialog(
                  context: context,
                  ref: ref,
                  initialStartDate: _initialPeriodStart(),
                ),
                icon: const Icon(Icons.date_range_rounded),
                label: const Text('期間予定を追加'),
              ),
            ),
          ],
        );
    }
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _periodLabel() {
    switch (_viewMode) {
      case _ViewMode.day:
        return DateFormat('yyyy年 M月d日 (E)', 'ja').format(_focusDate);
      case _ViewMode.week:
        final s = _startOfWeek(_focusDate);
        final e = s.add(const Duration(days: 6));
        return '${DateFormat('M/d', 'ja').format(s)} ─ '
            '${DateFormat('M/d', 'ja').format(e)}';
      case _ViewMode.month:
        return DateFormat('yyyy年 M月', 'ja').format(_focusDate);
    }
  }

  /// 週の先頭 (日曜) を返す。
  static DateTime _startOfWeek(DateTime d) {
    final weekday = d.weekday % 7; // Sun=0
    return DateTime(d.year, d.month, d.day - weekday);
  }

  static DateTime _dateKey(DateTime d) => DateTime(d.year, d.month, d.day);

  /// `Topic.dayId` を Day.date に joins して、 (日付 → Topic 配列) の Map にする。
  /// 期間予定 (startTime と endTime の日付が異なる) は、 跨ぐ全日に同じ Topic を割り当てる。
  /// 同日内の並び順:
  ///   - 期間予定 (multi-day) を先頭 (start 日付昇順)
  ///   - そのあとスポット予定を startTime 昇順、 時刻無しは末尾
  Map<DateTime, List<Topic>> _groupTopicsByDate(
    List<Topic> topics,
    List<Day> days,
  ) {
    final byDayId = {for (final d in days) d.id: d};
    final result = <DateTime, List<Topic>>{};

    void put(DateTime date, Topic t) {
      final key = _dateKey(date);
      result.putIfAbsent(key, () => []).add(t);
    }

    for (final t in topics) {
      final d = byDayId[t.dayId];
      if (d == null) continue;
      if (_isPeriodEvent(t)) {
        // 期間予定: startTime.date ─ endTime.date の全日に複製表示
        final s = _dateKey(t.startTime!);
        final e = _dateKey(t.endTime!);
        var cur = s;
        while (!cur.isAfter(e)) {
          put(cur, t);
          cur = cur.add(const Duration(days: 1));
        }
      } else {
        // スポット予定: 紐づく Day の日付 1 日のみ
        put(d.date, t);
      }
    }

    for (final list in result.values) {
      list.sort((a, b) {
        final ap = _isPeriodEvent(a);
        final bp = _isPeriodEvent(b);
        if (ap != bp) return ap ? -1 : 1; // 期間予定が先
        if (a.startTime == null && b.startTime == null) return 0;
        if (a.startTime == null) return 1;
        if (b.startTime == null) return -1;
        return a.startTime!.compareTo(b.startTime!);
      });
    }
    return result;
  }

  static bool _isPeriodEvent(Topic t) {
    if (t.startTime == null || t.endTime == null) return false;
    final s = DateTime(t.startTime!.year, t.startTime!.month, t.startTime!.day);
    final e = DateTime(t.endTime!.year, t.endTime!.month, t.endTime!.day);
    return e.isAfter(s);
  }
}

/// [日 / 週 / 月] 切替セグメント。
class _ViewModeSwitcher extends StatelessWidget {
  const _ViewModeSwitcher({required this.mode, required this.onChanged});

  final _ViewMode mode;
  final ValueChanged<_ViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SegmentedButton<_ViewMode>(
        segments: const [
          ButtonSegment(value: _ViewMode.day, label: Text('日')),
          ButtonSegment(value: _ViewMode.week, label: Text('週')),
          ButtonSegment(value: _ViewMode.month, label: Text('月')),
        ],
        selected: {mode},
        onSelectionChanged: (s) => onChanged(s.first),
        showSelectedIcon: false,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.softSkyBlue
                : Colors.white,
          ),
          foregroundColor: WidgetStateProperty.all(AppColors.triplaTealDark),
        ),
      ),
    );
  }
}

/// 期間ラベル + 前後ナビ ( < ... > )。 mode 共通。
class _PeriodNavigator extends StatelessWidget {
  const _PeriodNavigator({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: onPrev,
            tooltip: '前へ',
          ),
          Expanded(
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.triplaTealDark,
                    ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: onNext,
            tooltip: '次へ',
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Day view ─────────────────────────

/// 日モード本体: DayTimeline (足跡 + 縦線 + 時系列) をそのまま埋め込み。
/// trip/Day が未作成なら CTA、 あるなら DayTimeline + 右下 FAB スタイルの追加ボタン。
class _DayTimelineView extends StatelessWidget {
  const _DayTimelineView({
    required this.trip,
    required this.day,
    required this.date,
    required this.onAddTopic,
  });

  final Trip? trip;
  final Day? day;
  final DateTime date;
  final VoidCallback onAddTopic;

  @override
  Widget build(BuildContext context) {
    if (trip == null || day == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'この日の予定はまだ無いよ',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.softGray,
                    ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAddTopic,
                icon: const Icon(Icons.add),
                label: const Text('予定を追加'),
              ),
            ],
          ),
        ),
      );
    }
    // DayTimeline は内部で empty 状態 (TritaWidget) も含めて描画する。
    // 右下に FAB スタイルの追加ボタンを Stack で重ねる (Scaffold.fab は親が持っていないため)。
    return Stack(
      children: [
        Positioned.fill(
          child: DayTimeline(
            day: day!,
            tripId: trip!.id,
            tripLocked: trip!.isLocked,
            showDayHeader: false,
            tripMode: TripMode.schedule,
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'schedule-day-add',
            onPressed: onAddTopic,
            icon: const Icon(Icons.add),
            label: const Text('予定を追加'),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Week view ─────────────────────────

class _WeekListView extends StatelessWidget {
  const _WeekListView({
    required this.startOfWeek,
    required this.topicsByDate,
    required this.onOpenDate,
  });

  final DateTime startOfWeek;
  final Map<DateTime, List<Topic>> topicsByDate;
  final ValueChanged<DateTime> onOpenDate;

  static final _dateFmt = DateFormat('M/d (E)', 'ja');

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: 7,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final date = startOfWeek.add(Duration(days: i));
        // 期間予定はカレンダー側で帯表示するため、 週ビューの日別リストからは除外。
        // (移動カテゴリは _groupTopicsByDate の時点で除外済み)
        final topics =
            (topicsByDate[DateTime(date.year, date.month, date.day)] ??
                    const <Topic>[])
                .where((t) => !t.isPeriodEvent)
                .toList();
        return _WeekDayRow(
          date: date,
          dateLabel: _dateFmt.format(date),
          topics: topics,
          onTap: () => onOpenDate(date),
        );
      },
    );
  }
}

class _WeekDayRow extends StatelessWidget {
  const _WeekDayRow({
    required this.date,
    required this.dateLabel,
    required this.topics,
    required this.onTap,
  });

  final DateTime date;
  final String dateLabel;
  final List<Topic> topics;
  final VoidCallback onTap;

  Color _labelColor() {
    final w = date.weekday % 7;
    if (w == 0) return AppColors.coralRed;
    if (w == 6) return AppColors.triplaTealDark;
    return AppColors.darkBrown;
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(date, DateTime.now());
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      shadowColor: AppColors.triplaTeal.withValues(alpha: 0.12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                padding: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: isToday
                      ? AppColors.softSkyBlue.withValues(alpha: 0.45)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _labelColor(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: topics.isEmpty
                    ? Text(
                        '予定なし',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.softGray,
                            ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final t in topics.take(3))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: _TopicInlineLine(topic: t),
                            ),
                          if (topics.length > 3)
                            Text(
                              '...他 ${topics.length - 3} 件',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.softGray),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// 1 行に詰めた Topic 表示: 時刻 + カテゴリアイコン + タイトル
class _TopicInlineLine extends StatelessWidget {
  const _TopicInlineLine({required this.topic});
  final Topic topic;
  static final _timeFmt = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    final s = topic.startTime;
    final cat = topic.category;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 42,
          child: Text(
            s == null ? '--:--' : _timeFmt.format(s),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.triplaTealDark,
            ),
          ),
        ),
        Icon(
          cat.iconFor(TripMode.schedule),
          size: 14,
          color: cat.color,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            topic.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Month view ─────────────────────────

/// Google カレンダー風の月グリッド。
/// セル内: 日付を左上に、 下に予定ピル (期間予定は色帯で連続感を出す)。
/// セル全体が縦に伸びるため AspectRatio は使わず Expanded で行を等分する。
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.topicsByDate,
    required this.onSelect,
    required this.onPeriodEventTap,
  });

  final DateTime month;
  final Map<DateTime, List<Topic>> topicsByDate;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<Topic> onPeriodEventTap;

  int get _leadingBlankCount => month.weekday % 7;

  int get _daysInMonth {
    final next = DateTime(month.year, month.month + 1, 1);
    return next.subtract(const Duration(days: 1)).day;
  }

  @override
  Widget build(BuildContext context) {
    final blanks = _leadingBlankCount;
    final days = _daysInMonth;
    final total = blanks + days;
    final rows = (total + 6) ~/ 7;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          const _WeekHeaderRow(),
          // 行は使える縦スペースを均等に分け合う。 セルは縦に伸びるが
          // 予定が多いと枠内 ListView でスクロール可能。
          Expanded(
            child: Column(
              children: [
                for (var r = 0; r < rows; r++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var c = 0; c < 7; c++)
                          Expanded(
                            child: _cellAt(r * 7 + c, blanks, days),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cellAt(int index, int blanks, int days) {
    final dayNumber = index - blanks + 1;
    if (dayNumber < 1 || dayNumber > days) {
      return const _EmptyDayCell();
    }
    final date = DateTime(month.year, month.month, dayNumber);
    final isToday = _isSameDay(date, DateTime.now());
    final topics = topicsByDate[date] ?? const <Topic>[];
    return _DayCell(
      date: date,
      isToday: isToday,
      topics: topics,
      onTap: () => onSelect(date),
      onPeriodEventTap: onPeriodEventTap,
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _WeekHeaderRow extends StatelessWidget {
  const _WeekHeaderRow();

  static const _labels = ['日', '月', '火', '水', '木', '金', '土'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Center(
                child: Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: i == 0
                        ? AppColors.coralRed
                        : (i == 6
                            ? AppColors.triplaTealDark
                            : AppColors.softGray),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyDayCell extends StatelessWidget {
  const _EmptyDayCell();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// 月セル: 日付左上 + 下に予定ピル。 Google カレンダー風。
/// 入る限りピルを並べ、 オーバーフロー時のみ「+N 件」 にする。
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isToday,
    required this.topics,
    required this.onTap,
    required this.onPeriodEventTap,
  });

  final DateTime date;
  final bool isToday;
  final List<Topic> topics;
  final VoidCallback onTap;
  final ValueChanged<Topic> onPeriodEventTap;

  // ピル / 「+N」 行の実測高さ (font 9 + padding + margin-bottom 1)。
  // フォントメトリクスが変わったら微調整。 余裕を持って整数で固定。
  static const double _pillRowHeight = 14;
  static const double _overflowRowHeight = 13;
  static final _timeFmt = DateFormat('HH:mm');

  Color _dateTextColor() {
    if (isToday) return Colors.white;
    final weekday = date.weekday % 7;
    if (weekday == 0) return AppColors.coralRed;
    if (weekday == 6) return AppColors.triplaTealDark;
    return AppColors.darkBrown;
  }

  bool _isPeriodEvent(Topic t) {
    if (t.startTime == null || t.endTime == null) return false;
    final s = DateTime(t.startTime!.year, t.startTime!.month, t.startTime!.day);
    final e = DateTime(t.endTime!.year, t.endTime!.month, t.endTime!.day);
    return e.isAfter(s);
  }

  _PeriodPosition? _periodPosition(Topic t) {
    if (!_isPeriodEvent(t)) return null;
    final cellDate = DateTime(date.year, date.month, date.day);
    final start =
        DateTime(t.startTime!.year, t.startTime!.month, t.startTime!.day);
    final end = DateTime(t.endTime!.year, t.endTime!.month, t.endTime!.day);
    if (cellDate.isAtSameMomentAs(start)) return _PeriodPosition.start;
    if (cellDate.isAtSameMomentAs(end)) return _PeriodPosition.end;
    return _PeriodPosition.middle;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.paperBorder.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 日付バッジ — 左上 (今日は塗りつぶし円)
              Align(
                alignment: Alignment.topLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: isToday
                      ? const BoxDecoration(
                          color: AppColors.triplaTeal,
                          shape: BoxShape.circle,
                        )
                      : null,
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isToday ? FontWeight.w800 : FontWeight.w600,
                      color: _dateTextColor(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // 残りスペースに入る分だけピルを並べる。
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return _buildPillStack(constraints.maxHeight);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 残り高さに対して何件入るかを計算し、 ピル列 + (必要なら) 「+N 件」 を組む。
  /// - 全件入るなら overflow ラベルなし
  /// - 入りきらないなら overflow ラベル 1 行を確保し、 残り高さで本数決定
  Widget _buildPillStack(double availableHeight) {
    if (topics.isEmpty || availableHeight <= 0) return const SizedBox.shrink();
    final fitAll = (availableHeight / _pillRowHeight).floor();
    final canShowAll = fitAll >= topics.length;
    final int shownCount;
    final bool overflow;
    if (canShowAll) {
      shownCount = topics.length;
      overflow = false;
    } else {
      // overflow 行 1 行ぶんを確保した残りで何件入るか再計算。
      final remaining = availableHeight - _overflowRowHeight;
      final fit = (remaining / _pillRowHeight).floor();
      shownCount = fit.clamp(0, topics.length - 1);
      overflow = true;
    }
    final visible = topics.take(shownCount);
    final hiddenCount = topics.length - shownCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            // 期間予定ピルは独立 InkWell でタップを横取りし削除確認。
            // スポット予定は外側 InkWell (= 該当日の画面遷移) に任せる。
            child: _isPeriodEvent(t)
                ? Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onPeriodEventTap(t),
                      child: _EventPill(
                        topic: t,
                        periodPosition: _periodPosition(t),
                        timeFormat: _timeFmt,
                      ),
                    ),
                  )
                : _EventPill(
                    topic: t,
                    periodPosition: _periodPosition(t),
                    timeFormat: _timeFmt,
                  ),
          ),
        if (overflow)
          Text(
            '+$hiddenCount 件',
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.softGray,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

enum _PeriodPosition { start, middle, end }

/// 月セル内に並べる予定ピル。
/// - スポット予定: HH:MM + タイトル (薄カテゴリ色背景)
/// - 期間予定: カテゴリ色帯 + タイトル。 継続日は `→ title`、 最終日は `title →` ふう
///   (継続感を視覚化。 真の連続バー描画は将来 Phase で)
class _EventPill extends StatelessWidget {
  const _EventPill({
    required this.topic,
    required this.periodPosition,
    required this.timeFormat,
  });

  final Topic topic;
  final _PeriodPosition? periodPosition;
  final DateFormat timeFormat;

  bool get _isPeriod => periodPosition != null;

  @override
  Widget build(BuildContext context) {
    final isPeriod = _isPeriod;
    // 期間予定はユーザー指定色 (displayColor)、 スポット予定はカテゴリ色を使う。
    final color = topic.displayColor;
    final bg = isPeriod ? color : color.withValues(alpha: 0.18);
    final fg = isPeriod ? Colors.white : color;
    final prefix = switch (periodPosition) {
      _PeriodPosition.middle => '→ ',
      _PeriodPosition.end => '⤴ ',
      _ => '',
    };
    final timeText = !isPeriod && topic.startTime != null
        ? '${timeFormat.format(topic.startTime!)} '
        : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        '$prefix$timeText${topic.title}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: fg,
          height: 1.2,
        ),
      ),
    );
  }
}
