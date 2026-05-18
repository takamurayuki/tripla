import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/checklist_item.dart';
import '../../../../domain/entities/topic.dart';
import '../../../../domain/entities/topic_category.dart';
import '../../../../domain/entities/topic_link.dart';
import '../../../../domain/entities/trip_mode.dart';
import '../../../providers/checklist_providers.dart';
import '../../../providers/photo_storage_provider.dart';

/// タイムライン上の Topic 単体表示。
///
/// 通常予定はカテゴリ色アイコン + タイトル + 時刻バッジ。
/// 移動 Topic は出発地 → 到着地 を強調表示し、移動手段アイコンを左に置く。
///
/// [showTime] が false のとき、内部の時刻バッジを描画しない。
/// 時刻軸を持つタイムライン (DayTimeline) では左カラムに時刻が出るため、
/// バッジは重複表示を避けるため抑制する。
class TopicTile extends StatelessWidget {
  const TopicTile({
    super.key,
    required this.topic,
    required this.tripId,
    this.onTap,
    this.onLongPress,
    this.showTime = true,
    this.tripMode = TripMode.plan,
  });

  final Topic topic;

  /// この Topic が属する Trip の ID。
  /// 紐づく持ち物 (`checklistItemsProvider(tripId)` でフィルタ) の表示に使う。
  final String tripId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showTime;

  /// schedule モード時はカテゴリ表示を「観光 → イベント」に差し替える。
  final TripMode tripMode;

  static final _timeFormat = DateFormat('HH:mm');

  static String _formatTimeRange(Topic topic) {
    final start = topic.startTime;
    final end = topic.endTime;
    if (start == null) return '';
    if (end == null) return _timeFormat.format(start);
    return '${_timeFormat.format(start)} - ${_timeFormat.format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final indent = topic.isChild ? 28.0 : 0.0;
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Semantics(
        button: onTap != null,
        label: _semanticsLabel(),
        child: Material(
          color: Colors.white,
          elevation: 1,
          shadowColor: AppColors.triplaTeal.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: topic.isTransport
                  ? _TransportContent(
                      topic: topic, tripId: tripId, showTime: showTime)
                  : _PlanContent(
                      topic: topic,
                      tripId: tripId,
                      showTime: showTime,
                      tripMode: tripMode,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  String _semanticsLabel() {
    final time = _formatTimeRange(topic);
    final timeLabel = time.isEmpty ? '' : '$time, ';
    if (topic.isTransport) {
      final mode = topic.transportMode?.label ?? '移動';
      final from = topic.departure ?? '出発地未設定';
      final to = topic.destination ?? '到着地未設定';
      return '$timeLabel$mode で $from から $to へ';
    }
    return '$timeLabel${topic.category.label}, ${topic.title}';
  }
}

class _PlanContent extends ConsumerWidget {
  const _PlanContent({
    required this.topic,
    required this.tripId,
    required this.tripMode,
    this.showTime = true,
  });
  final Topic topic;
  final String tripId;
  final TripMode tripMode;
  final bool showTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cat = topic.category;
    final checklist = _topicChecklist(ref, tripId, topic.id);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: cat.color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(cat.iconFor(tripMode), color: cat.color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (showTime && topic.hasTime)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        TopicTile._formatTimeRange(topic),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.triplaTealDark,
                        ),
                      ),
                    ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      cat.labelFor(tripMode),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: cat.color,
                      ),
                    ),
                  ),
                  if (checklist.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _ChecklistCountBadge(items: checklist),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                topic.title,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (topic.description != null &&
                  topic.description!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  topic.description!,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (topic.hasCost) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.payments_outlined,
                        size: 14, color: AppColors.softGray),
                    const SizedBox(width: 4),
                    Text(
                      '${topic.costCurrency ?? ''} '
                      '${topic.cost!.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
              if (topic.links.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final link in topic.links) _LinkChip(link: link),
                  ],
                ),
              ],
              if (topic.photos.isNotEmpty) ...[
                const SizedBox(height: 6),
                _PhotoThumbs(paths: topic.photos),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TransportContent extends ConsumerWidget {
  const _TransportContent({
    required this.topic,
    required this.tripId,
    this.showTime = true,
  });
  final Topic topic;
  final String tripId;
  final bool showTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = topic.transportMode;
    final modeColor = AppColors.triplaTeal;
    final checklist = _topicChecklist(ref, tripId, topic.id);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: modeColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(
            mode?.icon ?? Icons.swap_horiz_rounded,
            color: modeColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (showTime && topic.hasTime)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        TopicTile._formatTimeRange(topic),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.triplaTealDark,
                        ),
                      ),
                    ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: modeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '移動 ${mode == null ? '' : '・${mode.label}'}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: modeColor,
                      ),
                    ),
                  ),
                  if (checklist.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _ChecklistCountBadge(items: checklist),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      topic.departure ?? '出発地未設定',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: topic.departure == null
                                ? AppColors.softGray
                                : AppColors.darkBrown,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 16, color: AppColors.softGray),
                  ),
                  Expanded(
                    child: Text(
                      topic.destination ?? '到着地未設定',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: topic.destination == null
                                ? AppColors.softGray
                                : AppColors.darkBrown,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              if (topic.description != null &&
                  topic.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  topic.description!,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (topic.links.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final link in topic.links) _LinkChip(link: link),
                  ],
                ),
              ],
              if (topic.photos.isNotEmpty) ...[
                const SizedBox(height: 6),
                _PhotoThumbs(paths: topic.photos),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 横スクロールの写真サムネイル列。 タイル下部に置く。
/// 最大 4 枚まで見せて、 4 枚超過時は最後を「+N」 オーバーレイ付きで表示。
class _PhotoThumbs extends ConsumerWidget {
  const _PhotoThumbs({required this.paths});

  final List<String> paths;

  static const _max = 4;
  static const _size = 44.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(photoStorageProvider);
    final visible = paths.length > _max ? paths.take(_max).toList() : paths;
    final overflow = paths.length > _max ? paths.length - _max : 0;
    return SizedBox(
      height: _size,
      child: Row(
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  FutureBuilder(
                    future: storage.resolveAbsolute(visible[i]),
                    builder: (context, snapshot) {
                      final file = snapshot.data;
                      if (file == null) {
                        return Container(
                          width: _size,
                          height: _size,
                          color: AppColors.softGray.withValues(alpha: 0.2),
                        );
                      }
                      return Image.file(
                        file,
                        width: _size,
                        height: _size,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: _size,
                          height: _size,
                          color: AppColors.softGray.withValues(alpha: 0.2),
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_rounded,
                              size: 18, color: AppColors.softGray),
                        ),
                      );
                    },
                  ),
                  if (i == visible.length - 1 && overflow > 0)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        alignment: Alignment.center,
                        child: Text(
                          '+$overflow',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
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

/// 指定 Trip の checklistItemsProvider を watch して、Topic に紐づくアイテムだけ返す。
List<ChecklistItem> _topicChecklist(
    WidgetRef ref, String tripId, String topicId) {
  final all = ref
      .watch(checklistItemsProvider(tripId))
      .maybeWhen(data: (l) => l, orElse: () => const <ChecklistItem>[]);
  return all.where((i) => i.topicId == topicId).toList(growable: false);
}

/// 予定カードのヘッダー行に置く小さな持ち物バッジ。
///
/// 「🧳 1/3」 のように進捗だけを示し、詳細閲覧 / チェックは持ち物タブで行う。
/// リンクチップ (水色系) と区別するため、持ち物色は **緑系 / オレンジ系**。
/// 全部チェック済み → bandanaGreen (緑 = 準備完了)
/// 未チェックあり   → warmOrange (オレンジ = 要準備)
///
/// ホバー (Web) / 長押し (Mobile) で **持ち物の一覧を Tooltip 表示**。
/// Tooltip 内は `richMessage` でアイコン (Icons.luggage_rounded) と
/// 各項目の □ / ☑ チェックボックスアイコンを描画。
class _ChecklistCountBadge extends StatelessWidget {
  const _ChecklistCountBadge({required this.items});

  final List<ChecklistItem> items;

  @override
  Widget build(BuildContext context) {
    final done = items.where((i) => i.isChecked).length;
    final allDone = done == items.length;
    final color =
        allDone ? AppColors.bandanaGreen : AppColors.warmOrange;
    final bg = allDone
        ? AppColors.bandanaGreen.withValues(alpha: 0.18)
        : AppColors.warmOrange.withValues(alpha: 0.18);
    return Tooltip(
      richMessage: WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ヘッダー: 持ち物アイコン + 「持ち物一覧 done/total」
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.luggage_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '持ち物一覧  $done/${items.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // 各アイテム: □ or ☑ + 名前
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        item.isChecked
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 16,
                        color: item.isChecked
                            ? AppColors.bandanaGreen
                            : Colors.white.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            decoration: item.isChecked
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor:
                                Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.darkBrown.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.luggage_rounded, size: 12, color: color),
            const SizedBox(width: 3),
            Text(
              '$done/${items.length}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// リンクのコンパクトチップ。
///
/// 複数リンクを Wrap で横並びに置けるよう、最小限の高さ・幅で表示する。
/// ラベルが設定されていればラベル、なければドメイン名。タップで外部ブラウザを開く。
class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.link});

  final TopicLink link;

  String get _label => link.label.isNotEmpty
      ? link.label
      : (Uri.tryParse(link.url)?.host ?? link.url);

  Future<void> _open() async {
    final uri = Uri.tryParse(link.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paleSky.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_rounded,
                  size: 12, color: AppColors.triplaTealDark),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  _label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.triplaTealDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.open_in_new_rounded,
                  size: 11, color: AppColors.softGray),
            ],
          ),
        ),
      ),
    );
  }
}
