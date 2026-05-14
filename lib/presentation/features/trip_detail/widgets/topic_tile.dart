import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/topic.dart';

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
    this.onTap,
    this.onLongPress,
    this.showTime = true,
  });

  final Topic topic;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showTime;

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
                  ? _TransportContent(topic: topic, showTime: showTime)
                  : _PlanContent(topic: topic, showTime: showTime),
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

class _PlanContent extends StatelessWidget {
  const _PlanContent({required this.topic, this.showTime = true});
  final Topic topic;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final cat = topic.category;
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
          child: Icon(cat.icon, color: cat.color, size: 20),
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
                      cat.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: cat.color,
                      ),
                    ),
                  ),
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
            ],
          ),
        ),
      ],
    );
  }
}

class _TransportContent extends StatelessWidget {
  const _TransportContent({required this.topic, this.showTime = true});
  final Topic topic;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final mode = topic.transportMode;
    final modeColor = AppColors.triplaTeal;
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
            ],
          ),
        ),
      ],
    );
  }
}
