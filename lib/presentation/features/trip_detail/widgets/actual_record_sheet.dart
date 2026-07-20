import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/handle_async_action.dart';
import '../../../../domain/entities/topic.dart';
import '../../../../domain/entities/topic_actual_status.dart';
import '../../../providers/topic_providers.dart';

/// 予定の「実績」をワンタップで記録するボトムシート。
///
/// 旅行しながらの入力を想定し、主要操作は 1 タップで保存 (保存ボタンなし、§14.4)。
/// メモ欄のみ 500ms debounce のオートセーブ。
Future<void> showActualRecordSheet({
  required BuildContext context,
  required Topic topic,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paperWhite,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _ActualRecordSheet(topic: topic),
    ),
  );
}

class _ActualRecordSheet extends ConsumerStatefulWidget {
  const _ActualRecordSheet({required this.topic});

  final Topic topic;

  @override
  ConsumerState<_ActualRecordSheet> createState() =>
      _ActualRecordSheetState();
}

class _ActualRecordSheetState extends ConsumerState<_ActualRecordSheet> {
  static const _autosaveDelay = Duration(milliseconds: 500);
  static final _timeFormat = DateFormat('HH:mm');

  late Topic _current;
  late final TextEditingController _noteController;
  final _noteFocusNode = FocusNode();
  Timer? _debounce;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _current = widget.topic;
    _noteController = TextEditingController(text: _current.actualNote ?? '')
      ..addListener(_scheduleNoteSave);
  }

  @override
  void dispose() {
    // ボタン操作でシートが閉じても、入力中のメモを取りこぼさないよう
    // 保留中の debounce があればここでフラッシュする (topic_edit_screen.dart と同パターン)。
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      final note = _noteController.text.trim();
      final snapshot =
          _current.copyWith(actualNote: note.isEmpty ? '' : note);
      unawaited(ref.read(topicRepositoryProvider).update(snapshot));
    }
    _noteController.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  String _formatTimeRange(Topic topic) {
    final start = topic.startTime;
    final end = topic.endTime;
    if (start == null) return '時刻未設定';
    if (end == null) return _timeFormat.format(start);
    return '${_timeFormat.format(start)} - ${_timeFormat.format(end)}';
  }

  void _scheduleNoteSave() {
    _debounce?.cancel();
    _debounce = Timer(_autosaveDelay, _saveNote);
  }

  Future<void> _saveNote() async {
    final note = _noteController.text.trim();
    final updated = _current.copyWith(actualNote: note.isEmpty ? '' : note);
    _current = updated;
    await ref.read(topicRepositoryProvider).update(updated);
  }

  /// 開始/終了/予定通り/実施した(今) は「実績を記録した」ことを表すため、
  /// 併せて actualStatus を recorded にする
  /// (時刻だけ入れて notRecorded のままだとバッジ等に反映されないため)。
  Future<void> _recordTimes({
    DateTime? actualStartTime,
    DateTime? actualEndTime,
  }) async {
    setState(() => _saving = true);
    final updated = _current.copyWith(
      actualStartTime: actualStartTime,
      actualEndTime: actualEndTime,
      actualStatus: TopicActualStatus.recorded,
    );
    final ok = await handleAsyncAction(
      context,
      () => ref.read(topicRepositoryProvider).update(updated),
      errorMessage: '実績を保存できませんでした',
    );
    if (!mounted) return;
    if (ok) {
      _current = updated;
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  Future<void> _skip() async {
    setState(() => _saving = true);
    final ex = _current;
    final updated = Topic(
      id: ex.id,
      dayId: ex.dayId,
      parentTopicId: ex.parentTopicId,
      orderIndex: ex.orderIndex,
      category: ex.category,
      title: ex.title,
      description: ex.description,
      startTime: ex.startTime,
      endTime: ex.endTime,
      latitude: ex.latitude,
      longitude: ex.longitude,
      locationName: ex.locationName,
      address: ex.address,
      cost: ex.cost,
      costCurrency: ex.costCurrency,
      isCompleted: ex.isCompleted,
      departure: ex.departure,
      destination: ex.destination,
      transportMode: ex.transportMode,
      altPlans: ex.altPlans,
      links: ex.links,
      colorHex: ex.colorHex,
      photos: ex.photos,
      trainTransfers: ex.trainTransfers,
      actualStartTime: null,
      actualEndTime: null,
      actualStatus: TopicActualStatus.skipped,
      actualNote: ex.actualNote,
      createdAt: ex.createdAt,
      updatedAt: ex.updatedAt,
    );
    final ok = await handleAsyncAction(
      context,
      () => ref.read(topicRepositoryProvider).update(updated),
      errorMessage: '実績を保存できませんでした',
    );
    if (!mounted) return;
    if (ok) {
      _current = updated;
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  Future<void> _markChanged() async {
    setState(() => _saving = true);
    final updated = _current.copyWith(actualStatus: TopicActualStatus.changed);
    final ok = await handleAsyncAction(
      context,
      () => ref.read(topicRepositoryProvider).update(updated),
      errorMessage: '実績を保存できませんでした',
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _current = ok ? updated : _current;
    });
    if (ok) {
      FocusScope.of(context).requestFocus(_noteFocusNode);
    }
  }

  Future<void> _clearRecord() async {
    setState(() => _saving = true);
    final ex = _current;
    final updated = Topic(
      id: ex.id,
      dayId: ex.dayId,
      parentTopicId: ex.parentTopicId,
      orderIndex: ex.orderIndex,
      category: ex.category,
      title: ex.title,
      description: ex.description,
      startTime: ex.startTime,
      endTime: ex.endTime,
      latitude: ex.latitude,
      longitude: ex.longitude,
      locationName: ex.locationName,
      address: ex.address,
      cost: ex.cost,
      costCurrency: ex.costCurrency,
      isCompleted: ex.isCompleted,
      departure: ex.departure,
      destination: ex.destination,
      transportMode: ex.transportMode,
      altPlans: ex.altPlans,
      links: ex.links,
      colorHex: ex.colorHex,
      photos: ex.photos,
      trainTransfers: ex.trainTransfers,
      actualStartTime: null,
      actualEndTime: null,
      actualStatus: TopicActualStatus.notRecorded,
      actualNote: null,
      createdAt: ex.createdAt,
      updatedAt: ex.updatedAt,
    );
    final ok = await handleAsyncAction(
      context,
      () => ref.read(topicRepositoryProvider).update(updated),
      errorMessage: '記録の取り消しに失敗しました',
    );
    if (!mounted) return;
    if (ok) {
      _current = updated;
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topic = _current;
    final canRecordStart = topic.hasTime;
    final canRecordEnd = topic.endTime != null;
    final canOnTime = topic.startTime != null && topic.endTime != null;
    final untimed = topic.startTime == null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.paperBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(topic.category.icon, color: topic.category.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '予定: ${_formatTimeRange(topic)}',
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
            const SizedBox(height: 20),
            if (canRecordStart)
              _ActionButton(
                icon: Icons.play_circle_outline_rounded,
                label: '開始を記録 (今)',
                color: AppColors.triplaTeal,
                enabled: !_saving,
                onTap: () => _recordTimes(
                  actualStartTime: DateTime.now(),
                  actualEndTime: topic.actualEndTime,
                ),
              ),
            if (canRecordEnd) ...[
              const SizedBox(height: 10),
              _ActionButton(
                icon: Icons.stop_circle_outlined,
                label: '終了を記録 (今)',
                color: AppColors.triplaTeal,
                enabled: !_saving,
                onTap: () => _recordTimes(
                  actualStartTime: topic.actualStartTime,
                  actualEndTime: DateTime.now(),
                ),
              ),
            ],
            if (canOnTime) ...[
              const SizedBox(height: 10),
              _ActionButton(
                icon: Icons.check_circle_outline_rounded,
                label: '予定通りだった',
                color: AppColors.bandanaGreen,
                enabled: !_saving,
                onTap: () => _recordTimes(
                  actualStartTime: topic.startTime,
                  actualEndTime: topic.endTime,
                ),
              ),
            ],
            if (untimed) ...[
              const SizedBox(height: 10),
              _ActionButton(
                icon: Icons.check_circle_outline_rounded,
                label: '実施した (今)',
                color: AppColors.bandanaGreen,
                enabled: !_saving,
                onTap: () => _recordTimes(actualStartTime: DateTime.now()),
              ),
            ],
            const SizedBox(height: 10),
            _ActionButton(
              icon: Icons.edit_note_rounded,
              label: '内容を変更した',
              color: AppColors.warmOrange,
              enabled: !_saving,
              onTap: _markChanged,
            ),
            const SizedBox(height: 10),
            _ActionButton(
              icon: Icons.cancel_outlined,
              label: 'スキップした',
              color: AppColors.coralRed,
              enabled: !_saving,
              onTap: _skip,
            ),
            const SizedBox(height: 20),
            const Text(
              'メモ (遅延理由・変更内容など)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.triplaTealDark,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              focusNode: _noteFocusNode,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                hintText: '例: 電車遅延で20分遅れた',
              ),
            ),
            if (topic.hasActualRecord) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: _saving ? null : _clearRecord,
                  icon: const Icon(Icons.restart_alt_rounded,
                      size: 18, color: AppColors.softGray),
                  label: const Text(
                    '記録を取り消す',
                    style: TextStyle(color: AppColors.softGray),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, color: color),
        label: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w700, color: color),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
