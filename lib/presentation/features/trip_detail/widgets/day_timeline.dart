import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/handle_async_action.dart';
import '../../../../domain/entities/day.dart';
import '../../../../domain/entities/topic.dart';
import '../../../../domain/entities/trip_mode.dart';
import '../../../providers/day_providers.dart';
import '../../../providers/topic_providers.dart';
import '../../../widgets/trita/trita_speech_bubble.dart';
import '../../../widgets/trita/trita_state.dart';
import '../../../widgets/trita/trita_widget.dart';
import 'topic_editor_sheet.dart';
import 'topic_tile.dart';

/// 指定 Day のタイムラインを表示する。
///
/// 要件定義書 §7.2 S-04 (Day タイムライン) の縦スクロール時刻軸表現。
/// Phase 1.3 でドラッグ&ドロップ並べ替えと親子階層表示に対応:
/// - 親 Topic は ReorderableListView で D&D 可能。
/// - 子 Topic (parentTopicId != null) は親の直下にインデント表示。
///   現状は子グループ内の並び順は orderIndex を保持し、UI からの D&D 対象外。
class DayTimeline extends ConsumerWidget {
  const DayTimeline({
    super.key,
    required this.day,
    required this.tripId,
    required this.tripLocked,
    this.showDayHeader = true,
    this.tripMode = TripMode.plan,
  });

  final Day day;
  final String tripId;

  /// Trip 一括ロックの状態。実効ロック判定 (`tripLocked || day.isLocked`) に使う。
  final bool tripLocked;

  /// 「Day N • M/d (E)」 ヘッダーの表示有無。
  /// スケジュールモード (mode=schedule) では Day 番号が意味を持たないため false にする。
  final bool showDayHeader;

  /// schedule モードでは TopicTile の category 表示を差し替える + 追加シートも mode を渡す。
  final TripMode tripMode;

  static final _headerDateFormat = DateFormat('M/d (E)', 'ja');

  bool get _isEffectiveLocked => tripLocked || day.isLocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(topicListProvider(day.id));
    final locked = _isEffectiveLocked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDayHeader)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
            color: AppColors.softSkyBlue.withValues(alpha: 0.35),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.triplaTeal,
                  child: Text(
                    'D${day.dayNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Day ${day.dayNumber}  •  ${_headerDateFormat.format(day.date)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.triplaTealDark,
                        ),
                  ),
                ),
                _DayLockButton(
                  day: day,
                  tripLocked: tripLocked,
                ),
              ],
            ),
          ),
        Expanded(
          child: topicsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (topics) {
              // schedule モードでは期間予定 (日跨ぎ) はカレンダー側で帯表示するため
              // 時系列タイムラインからは除外する (移動は表示する)。
              final visible = tripMode.isSchedule
                  ? topics.where((t) => !t.isPeriodEvent).toList()
                  : topics;
              return visible.isEmpty
                  ? const _DayEmptyState()
                  : _TimelineList(
                      day: day,
                      tripId: tripId,
                      topics: visible,
                      isLocked: locked,
                      tripMode: tripMode,
                    );
            },
          ),
        ),
      ],
    );
  }
}

/// Day ヘッダー右端に置く個別ロックボタン。
/// Trip 一括ロック中は disabled (灰色 + タップ不可)。
class _DayLockButton extends ConsumerWidget {
  const _DayLockButton({required this.day, required this.tripLocked});

  final Day day;
  final bool tripLocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayLocked = day.isLocked;
    final disabled = tripLocked;
    final showLocked = tripLocked || dayLocked;
    final color = disabled
        ? AppColors.softGray.withValues(alpha: 0.5)
        : (dayLocked ? AppColors.warmOrange : AppColors.softGray);
    final icon =
        showLocked ? Icons.lock_rounded : Icons.lock_open_rounded;

    return Tooltip(
      message: tripLocked
          ? '一括ロック中は個別解除できません'
          : (dayLocked ? 'Day を編集可能にする' : 'この Day をロック'),
      child: IconButton(
        icon: Icon(icon, size: 20, color: color),
        onPressed: disabled
            ? null
            : () => handleAsyncAction(
                  context,
                  () => ref
                      .read(dayRepositoryProvider)
                      .setLocked(day.id, !dayLocked),
                  errorMessage: 'ロック状態を更新できませんでした',
                ),
      ),
    );
  }
}

class _DayEmptyState extends StatelessWidget {
  const _DayEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const TritaWidget(state: TritaState.jump, size: 140),
            const SizedBox(height: 8),
            const TritaSpeechBubble(message: 'まだ何もないよ！'),
            const SizedBox(height: 16),
            Text(
              '右下の「予定を追加」から\nこの日の予定を入れてみよう',
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

/// 親 Topic と、その子 Topic のリストをひとまとめにした表示単位。
class _TopicGroup {
  const _TopicGroup({required this.parent, required this.children});
  final Topic parent;
  final List<Topic> children;
}

class _TimelineList extends ConsumerWidget {
  const _TimelineList({
    required this.day,
    required this.tripId,
    required this.topics,
    required this.isLocked,
    required this.tripMode,
  });

  final Day day;
  final String tripId;
  final List<Topic> topics;

  /// 実効ロック (Trip 一括 OR Day 個別)。true なら + / D&D / タップ無効。
  final bool isLocked;
  final TripMode tripMode;

  /// orderIndex 順の Topic 群を、親グループの配列に変換する。
  /// 親が見つからない子は孤児として親扱いにする。
  List<_TopicGroup> _buildGroups() {
    final byId = {for (final t in topics) t.id: t};
    final childrenByParent = <String, List<Topic>>{};
    final parents = <Topic>[];
    for (final t in topics) {
      final pid = t.parentTopicId;
      if (pid != null && byId.containsKey(pid)) {
        childrenByParent.putIfAbsent(pid, () => []).add(t);
      } else {
        parents.add(t);
      }
    }
    return [
      for (final p in parents)
        _TopicGroup(
          parent: p,
          children: childrenByParent[p.id] ?? const [],
        ),
    ];
  }

  Future<void> _onReorder(BuildContext context, WidgetRef ref, int oldIndex,
      int newIndex, List<_TopicGroup> groups) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final reordered = [...groups];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    // 各グループの親 → 子 の順に並べた flat な ID リストを作る。
    final ids = <String>[];
    for (final g in reordered) {
      ids.add(g.parent.id);
      for (final c in g.children) {
        ids.add(c.id);
      }
    }
    await handleAsyncAction(
      context,
      () => ref.read(topicRepositoryProvider).reorderForDay(day.id, ids),
      errorMessage: '並び替えを保存できませんでした',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = _buildGroups();
    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            itemCount: groups.length,
            buildDefaultDragHandles: false,
            onReorder: (o, n) => _onReorder(context, ref, o, n, groups),
            proxyDecorator: (child, index, animation) {
              return Material(
                color: Colors.transparent,
                elevation: 6,
                shadowColor: AppColors.triplaTeal.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
                child: child,
              );
            },
            itemBuilder: (context, index) {
              final group = groups[index];
              return KeyedSubtree(
                key: ValueKey('group-${group.parent.id}'),
                child: _TopicGroupTile(
                  day: day,
                  group: group,
                  reorderIndex: index,
                  isFirstGroup: index == 0,
                  // 最後の group の後ろ(Tail の手前)には + を出さない
                  isLastGroup: index == groups.length - 1,
                  isLocked: isLocked,
                  tripMode: tripMode,
                ),
              );
            },
          ),
        ),
        // 末尾エリア: schedule モードでは何も出さない。
        // plan モードでは day.isCompleted ? 旗 : 「完了する」 ボタン。
        if (tripMode.isPlan)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            child: day.isCompleted
                ? _TimelineTail(
                    dayNumber: day.dayNumber,
                    onUncomplete: isLocked
                        ? null
                        : () => handleAsyncAction(
                              context,
                              () => ref
                                  .read(dayRepositoryProvider)
                                  .setCompleted(day.id, false),
                              errorMessage: '完了状態を更新できませんでした',
                            ),
                  )
                : _CompleteDayButton(
                    enabled: !isLocked,
                    onTap: () => handleAsyncAction(
                      context,
                      () => ref
                          .read(dayRepositoryProvider)
                          .setCompleted(day.id, true),
                      errorMessage: '完了状態を更新できませんでした',
                    ),
                  ),
          )
        else
          const SizedBox(height: 100),
      ],
    );
  }
}

/// 「この日を完了する」 ボタン。 plan モードでまだ完了マークが無いとき末尾に表示。
class _CompleteDayButton extends StatelessWidget {
  const _CompleteDayButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: enabled ? onTap : null,
          icon: const Icon(Icons.flag_outlined),
          label: const Text('この日を完了する'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.coralRed,
            side: BorderSide(
              color: AppColors.coralRed.withValues(alpha: 0.5),
              width: 1.2,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopicGroupTile extends ConsumerWidget {
  const _TopicGroupTile({
    required this.day,
    required this.group,
    required this.reorderIndex,
    required this.isFirstGroup,
    required this.isLastGroup,
    required this.isLocked,
    required this.tripMode,
  });

  final Day day;
  final _TopicGroup group;
  final int reorderIndex;
  final bool isFirstGroup;
  final bool isLastGroup;

  /// 実効ロック。true なら drag handle / + ボタン / カードタップ全部無効。
  final bool isLocked;
  final TripMode tripMode;

  /// 編集はモーダル (TopicEditorSheet) で行う。
  /// 全画面のトピック編集ルート (/trips/:id/topics/:topicId) は使わない。
  void _openEdit(BuildContext context, Topic topic) {
    showTopicEditorSheet(
      context: context,
      day: day,
      existing: topic,
      tripMode: tripMode,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parent = group.parent;
    final children = group.children;
    final lastChildIndex = children.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TimelineEntry(
          topic: parent,
          tripId: day.tripId,
          tripMode: tripMode,
          isParent: true,
          // 先頭グループの親は上端
          isTimelineTop: isFirstGroup,
          // 末尾グループ かつ 子なし のとき親が最後の足跡
          isTimelineBottom: isLastGroup && children.isEmpty,
          // ロック中はカードタップ無効
          onTap: isLocked ? null : () => _openEdit(context, parent),
          // ロック中は drag handle 非表示
          leading: isLocked
              ? null
              : ReorderableDragStartListener(
                  index: reorderIndex,
                  child: const Icon(
                    Icons.drag_indicator_rounded,
                    color: AppColors.softGray,
                    size: 18,
                  ),
                ),
          trailing: _DurationBadge(topic: parent),
        ),
        for (var i = 0; i < children.length; i++)
          _TimelineEntry(
            topic: children[i],
            tripId: day.tripId,
            tripMode: tripMode,
            isParent: false,
            // 子は親の下にあるので上端には来ない
            isTimelineTop: false,
            // 末尾グループの最後の子のみ下端
            isTimelineBottom: isLastGroup && i == lastChildIndex,
            onTap: isLocked ? null : () => _openEdit(context, children[i]),
            trailing: _DurationBadge(topic: children[i]),
          ),
        // この group の直後 (次の group との間) に + を出す。
        // ただし最後の group のあとには出さない / ロック中も出さない。
        if (!isLastGroup && !isLocked)
          _AddBetweenButton(day: day, afterTopicId: parent.id, tripMode: tripMode),
      ],
    );
  }
}

/// 開始時刻と終了時刻が両方ある Topic に対して所要時間を表示する小さなバッジ。
/// 片方欠けている / 0 分 のときは何も描画しない (`SizedBox.shrink`)。
class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.topic});

  final Topic topic;

  String? _format() {
    final s = topic.startTime;
    final e = topic.endTime;
    if (s == null || e == null) return null;
    final diff = e.difference(s);
    if (diff.inMinutes <= 0) return null;
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h > 0 && m > 0) return '$h時間$m分';
    if (h > 0) return '$h時間';
    return '$m分';
  }

  @override
  Widget build(BuildContext context) {
    final text = _format();
    if (text == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.paperBorder.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded,
              size: 11, color: AppColors.softGray),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.softGray,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 時系列タイムラインの 1 行。
///
/// 左カラムに開始/終了時刻、中央カラムに縦線とノード、右にカード。
/// 親トピックはノードを大きく、子トピックは小さくしてインデント表示する。
///
/// [isTimelineTop] / [isTimelineBottom] が true のとき、それぞれ
/// ノードより上 / 下 の縦線を描画しない。
class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.topic,
    required this.tripId,
    required this.tripMode,
    required this.onTap,
    required this.isParent,
    this.isTimelineTop = false,
    this.isTimelineBottom = false,
    this.leading,
    this.trailing,
  });

  final Topic topic;
  final String tripId;
  final TripMode tripMode;

  /// null ならタップ無効 (ロック中)。
  final VoidCallback? onTap;
  final bool isParent;
  final bool isTimelineTop;
  final bool isTimelineBottom;

  /// 時刻列の下に重ねるドラッグハンドル等。
  final Widget? leading;

  /// カードの右上に重ねる操作ボタン (PopupMenu / 昇格ボタン)。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 52,
            child: _TimeColumn(topic: topic, leading: leading),
          ),
          SizedBox(
            width: 22,
            child: _Spine(
              topic: topic,
              isParent: isParent,
              isTop: isTimelineTop,
              isBottom: isTimelineBottom,
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, 4, 0, 4).copyWith(
                // スパインから離してカードを少し右にずらす
                left: isParent ? 10 : 26,
              ),
              child: Stack(
                children: [
                  TopicTile(
                    topic: topic,
                    tripId: tripId,
                    tripMode: tripMode,
                    onTap: onTap,
                    showTime: false,
                  ),
                  if (trailing != null)
                    Positioned(top: 4, right: 4, child: trailing!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeColumn extends StatelessWidget {
  const _TimeColumn({required this.topic, this.leading});

  final Topic topic;
  final Widget? leading;

  static final _format = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    final start = topic.startTime;
    final end = topic.endTime;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (start != null)
              Text(
                _format.format(start),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkBrown,
                  height: 1.1,
                ),
              )
            else
              const Text(
                '—:—',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.softGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (end != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _format.format(end),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.softGray,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ),
            if (leading != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: leading!,
              ),
          ],
        ),
      ),
    );
  }
}

/// タイムラインの背骨 (縦線 + 足跡ノード)。
///
/// ノードはトリ太の足跡をカテゴリ色で表現。
/// [isTop] が true のとき、ノードより上の縦線は描画しない (タイムラインの先頭)。
/// [isBottom] が true のとき、ノードより下の縦線は描画しない (タイムラインの末尾)。
class _Spine extends StatelessWidget {
  const _Spine({
    required this.topic,
    required this.isParent,
    this.isTop = false,
    this.isBottom = false,
  });

  final Topic topic;
  final bool isParent;
  final bool isTop;
  final bool isBottom;

  @override
  Widget build(BuildContext context) {
    final color = topic.category.color;
    final circleSize = isParent ? 28.0 : 20.0;
    final iconSize = isParent ? 18.0 : 12.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        // 上半分の縦線 (タイムライン先頭では描画しない)
        if (!isTop)
          Positioned.fill(
            child: Align(
              alignment: Alignment.topCenter,
              child: FractionallySizedBox(
                heightFactor: 0.5,
                child: Center(
                  child: Container(
                    width: 2,
                    color: AppColors.softSkyBlue,
                  ),
                ),
              ),
            ),
          ),
        // 下半分の縦線 (タイムライン末尾では描画しない)
        if (!isBottom)
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.5,
                child: Center(
                  child: Container(
                    width: 2,
                    color: AppColors.softSkyBlue,
                  ),
                ),
              ),
            ),
          ),
        // 白い円ベース + 足跡アイコン
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 4,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: SizedBox(
            width: iconSize,
            height: iconSize,
            child: CustomPaint(
              painter: _DinoFootprintPainter(color: color),
            ),
          ),
        ),
      ],
    );
  }
}

/// トリ太(トリケラトプス)の三本指足跡を描く CustomPainter。
///
/// 上に 3 本の指(中央が長め、左右はやや傾けて短め)、下に大きめのヒール (土踏まず)。
/// シルエットだけのシンプルな塗りつぶしで、小さなサイズでも形が崩れないようにしている。
class _DinoFootprintPainter extends CustomPainter {
  const _DinoFootprintPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final w = size.width;
    final h = size.height;

    // ヒール (中央下、横長楕円)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.72),
        width: w * 0.62,
        height: h * 0.42,
      ),
      paint,
    );

    // 中指 (上中央、縦長楕円)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.22),
        width: w * 0.22,
        height: h * 0.36,
      ),
      paint,
    );

    // 左指 (左上、外向きに少し傾ける)
    canvas.save();
    canvas.translate(w * 0.24, h * 0.32);
    canvas.rotate(-0.45);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: w * 0.20,
        height: h * 0.32,
      ),
      paint,
    );
    canvas.restore();

    // 右指 (右上、外向きに少し傾ける)
    canvas.save();
    canvas.translate(w * 0.76, h * 0.32);
    canvas.rotate(0.45);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: w * 0.20,
        height: h * 0.32,
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DinoFootprintPainter old) =>
      old.color != color;
}

/// グループの間 / 先頭 に表示する「ここに予定を追加」ボタン。
///
/// 縦線の中央に小さな + 円を配置し、タップで TopicEditorSheet を開く。
/// [afterTopicId] が空文字なら先頭に、ID 指定ならその親トピック直後に挿入する。
class _AddBetweenButton extends StatelessWidget {
  const _AddBetweenButton({
    required this.day,
    required this.afterTopicId,
    required this.tripMode,
  });

  final Day day;
  final String afterTopicId;
  final TripMode tripMode;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'ここに予定を追加',
      child: SizedBox(
        height: 32,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(width: 52),
            SizedBox(
              width: 22,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 縦線 (full height) — 前後の足跡ノードの線と連続して見えるように
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: AppColors.softSkyBlue,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(
                      side: BorderSide(
                        color: AppColors.triplaTeal,
                        width: 1.5,
                      ),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => showTopicEditorSheet(
                        context: context,
                        day: day,
                        insertAfterTopicId: afterTopicId,
                        tripMode: tripMode,
                      ),
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: AppColors.triplaTeal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    );
  }
}

/// タイムラインの末尾マーカー。旗アイコン + 「Day n おつかれさま！」
/// [onUncomplete] が非 null なら右端に「完了を取り消す」 アイコンを出す。
class _TimelineTail extends StatelessWidget {
  const _TimelineTail({
    required this.dayNumber,
    this.onUncomplete,
  });

  final int dayNumber;
  final VoidCallback? onUncomplete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(width: 52),
            SizedBox(
              width: 22,
              child: Center(
                // 末尾の足跡の下からは線が出ないため、Tail の旗との間に
                // 線は引かない (旗は独立した「ゴールマーカー」として表示)
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.coralRed.withValues(alpha: 0.15),
                    border: Border.all(color: AppColors.coralRed, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.flag_rounded,
                      color: AppColors.coralRed, size: 18),
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                  decoration: BoxDecoration(
                    color: AppColors.coralRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.coralRed.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Day $dayNumber おつかれさま！',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.coralRed,
                        ),
                      ),
                      if (onUncomplete != null)
                        IconButton(
                          tooltip: '完了を取り消す',
                          visualDensity: VisualDensity.compact,
                          iconSize: 16,
                          color: AppColors.coralRed,
                          icon: const Icon(Icons.replay_rounded),
                          onPressed: onUncomplete,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
