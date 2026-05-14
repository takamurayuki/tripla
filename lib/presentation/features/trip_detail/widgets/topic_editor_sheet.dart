import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/handle_async_action.dart';
import '../../../../domain/entities/day.dart';
import '../../../../domain/entities/topic.dart';
import '../../../../domain/entities/topic_category.dart';
import '../../../../domain/entities/transport_mode.dart';
import '../../../providers/topic_providers.dart';

/// 予定の新規追加 / 編集 BottomSheet。
///
/// [existing] が null なら新規追加、それ以外は編集。
/// 「予定 / 移動」をセグメントで切り替え、移動モードは
/// 出発地・到着地・移動手段(TransportMode)を扱う。
///
/// [insertAfterTopicId] を指定すると、新規作成時にその親トピックの直後に挿入する。
/// null (既定) は末尾追加。空文字列を渡すと先頭に挿入する。
Future<void> showTopicEditorSheet({
  required BuildContext context,
  required Day day,
  Topic? existing,
  String? insertAfterTopicId,
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
      child: _TopicEditorSheet(
        day: day,
        existing: existing,
        insertAfterTopicId: insertAfterTopicId,
      ),
    ),
  );
}

enum _Mode { plan, transport }

class _TopicEditorSheet extends ConsumerStatefulWidget {
  const _TopicEditorSheet({
    required this.day,
    this.existing,
    this.insertAfterTopicId,
  });

  final Day day;
  final Topic? existing;
  final String? insertAfterTopicId;

  @override
  ConsumerState<_TopicEditorSheet> createState() => _TopicEditorSheetState();
}

class _TopicEditorSheetState extends ConsumerState<_TopicEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _departureController = TextEditingController();
  final _destinationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startController = TextEditingController();
  final _endController = TextEditingController();

  late _Mode _mode;
  TopicCategory _planCategory = TopicCategory.sightseeing;
  TransportMode _transportMode = TransportMode.train;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex == null) {
      _mode = _Mode.plan;
    } else {
      _mode = ex.isTransport ? _Mode.transport : _Mode.plan;
      if (ex.isTransport) {
        _transportMode = ex.transportMode ?? TransportMode.train;
      } else {
        _planCategory = ex.category;
      }
      _titleController.text = ex.title;
      _departureController.text = ex.departure ?? '';
      _destinationController.text = ex.destination ?? '';
      _descriptionController.text = ex.description ?? '';
      _startController.text = _formatTime(ex.startTime);
      _endController.text = _formatTime(ex.endTime);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _departureController.dispose();
    _destinationController.dispose();
    _descriptionController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  TimeOfDay? _parseTime(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmed);
    if (match == null) return null;
    final h = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String? _validateTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (_parseTime(value) == null) return 'HH:MM (00:00〜23:59)';
    return null;
  }

  DateTime _toDateTime(TimeOfDay t) {
    final d = widget.day.date;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    final startT = _parseTime(_startController.text);
    final endT = _parseTime(_endController.text);

    if (startT != null && endT != null) {
      final s = startT.hour * 60 + startT.minute;
      final e = endT.hour * 60 + endT.minute;
      if (e < s) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('終了時刻は開始時刻より後にしてね')),
        );
        return;
      }
    }

    final isTransport = _mode == _Mode.transport;
    final category =
        isTransport ? TopicCategory.transport : _planCategory;
    final title = isTransport
        ? _buildTransportTitle()
        : _titleController.text.trim();
    final departure =
        isTransport ? _departureController.text.trim() : null;
    final destination =
        isTransport ? _destinationController.text.trim() : null;
    final transport = isTransport ? _transportMode : null;
    final description = _descriptionController.text.trim();

    setState(() => _saving = true);
    try {
      final repo = ref.read(topicRepositoryProvider);
      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          category: category,
          title: title,
          description: description.isEmpty ? null : description,
          startTime: startT == null ? null : _toDateTime(startT),
          endTime: endT == null ? null : _toDateTime(endT),
          departure: departure == null || departure.isEmpty ? null : departure,
          destination:
              destination == null || destination.isEmpty ? null : destination,
          transportMode: transport,
        );
        await repo.update(updated);
      } else {
        final newId = await repo.create(
          dayId: widget.day.id,
          category: category,
          title: title,
          description: description.isEmpty ? null : description,
          startTime: startT == null ? null : _toDateTime(startT),
          endTime: endT == null ? null : _toDateTime(endT),
          departure: departure == null || departure.isEmpty ? null : departure,
          destination:
              destination == null || destination.isEmpty ? null : destination,
          transportMode: transport,
        );
        // insertAfterTopicId が指定されていれば parent の orderIndex を再振りして
        // 指定位置に挿入する。
        // - null  : 末尾追加 (現状維持)
        // - ''    : 先頭に挿入
        // - <id>  : 指定 ID の親トピックの直後に挿入
        final insertAfter = widget.insertAfterTopicId;
        if (insertAfter != null) {
          final all = await repo.watchByDay(widget.day.id).first;
          final parents =
              all.where((t) => t.parentTopicId == null).toList();
          final orderedIds = <String>[];
          if (insertAfter.isEmpty) {
            orderedIds.add(newId);
          }
          for (final p in parents) {
            if (p.id == newId) continue;
            orderedIds.add(p.id);
            if (p.id == insertAfter) {
              orderedIds.add(newId);
            }
          }
          await repo.reorderForDay(widget.day.id, orderedIds);
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $error')),
      );
    }
  }

  /// 移動の場合のタイトルを「出発地 → 到着地」または手段名にする。
  String _buildTransportTitle() {
    final d = _departureController.text.trim();
    final a = _destinationController.text.trim();
    if (d.isNotEmpty && a.isNotEmpty) return '$d → $a';
    if (d.isNotEmpty) return d;
    if (a.isNotEmpty) return a;
    return _transportMode.label;
  }

  Future<void> _onDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('この予定を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.coralRed),
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
      () => ref.read(topicRepositoryProvider).delete(widget.existing!.id),
      errorMessage: '削除に失敗しました',
    );
    if (!ok || !mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.softSkyBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              _isEditing ? '予定を編集' : 'Day ${widget.day.dayNumber} に予定を追加',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),

            // 予定 / 移動 セグメント
            _ModeSegment(
              mode: _mode,
              onChanged: (m) => setState(() => _mode = m),
            ),
            const SizedBox(height: 16),

            if (_mode == _Mode.transport) ..._buildTransportFields(context),
            if (_mode == _Mode.plan) ..._buildPlanFields(context),

            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_TimeTextInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: '出発',
                      hintText: 'HH:MM',
                      prefixIcon: Icon(Icons.schedule_rounded),
                    ),
                    validator: _validateTime,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  child: Text('〜',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.softGray,
                      )),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _endController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_TimeTextInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: '到着',
                      hintText: 'HH:MM',
                    ),
                    validator: _validateTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'メモ (任意)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _onSave,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? '保存中...' : '保存'),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _saving ? null : _onDelete,
                style: ButtonStyle(
                  foregroundColor:
                      const WidgetStatePropertyAll(AppColors.coralRed),
                  // ホバー / フォーカス / 押下 で薄い赤背景を表示
                  overlayColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.pressed)) {
                      return AppColors.coralRed.withValues(alpha: 0.16);
                    }
                    if (states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.focused)) {
                      return AppColors.coralRed.withValues(alpha: 0.10);
                    }
                    return null;
                  }),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('この予定を削除'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPlanFields(BuildContext context) {
    final categories =
        TopicCategory.values.where((c) => c != TopicCategory.transport);
    return [
      TextFormField(
        controller: _titleController,
        autofocus: !_isEditing,
        decoration: const InputDecoration(
          labelText: 'タイトル',
          hintText: '例: 清水寺観光',
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'タイトルを入力してください';
          }
          return null;
        },
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final cat in categories)
            ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cat.icon, size: 16, color: cat.color),
                  const SizedBox(width: 4),
                  Text(cat.label),
                ],
              ),
              selected: cat == _planCategory,
              selectedColor: cat.color.withValues(alpha: 0.2),
              onSelected: (_) => setState(() => _planCategory = cat),
            ),
        ],
      ),
    ];
  }

  List<Widget> _buildTransportFields(BuildContext context) {
    return [
      TextFormField(
        controller: _departureController,
        autofocus: !_isEditing,
        decoration: const InputDecoration(
          labelText: '出発地',
          hintText: '例: 東京駅',
          prefixIcon: Icon(Icons.trip_origin_rounded),
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _destinationController,
        decoration: const InputDecoration(
          labelText: '到着地',
          hintText: '例: 京都駅',
          prefixIcon: Icon(Icons.flag_outlined),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final mode in TransportMode.values)
            ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(mode.icon, size: 16, color: AppColors.triplaTeal),
                  const SizedBox(width: 4),
                  Text(mode.label),
                ],
              ),
              selected: mode == _transportMode,
              selectedColor: AppColors.triplaTeal.withValues(alpha: 0.18),
              onSelected: (_) => setState(() => _transportMode = mode),
            ),
        ],
      ),
    ];
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({required this.mode, required this.onChanged});

  final _Mode mode;
  final ValueChanged<_Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_Mode>(
      segments: const [
        ButtonSegment(
          value: _Mode.plan,
          label: Text('予定'),
          icon: Icon(Icons.event_note_rounded),
        ),
        ButtonSegment(
          value: _Mode.transport,
          label: Text('移動'),
          icon: Icon(Icons.swap_horiz_rounded),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (set) => onChanged(set.first),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.softSkyBlue
              : Colors.white,
        ),
        foregroundColor: WidgetStateProperty.all(AppColors.triplaTealDark),
      ),
    );
  }
}

/// 数字 4 桁の入力を `HH:MM` の形に整える InputFormatter。
class _TimeTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue();
    }
    final clamped = digits.substring(0, digits.length > 4 ? 4 : digits.length);
    final formatted = clamped.length <= 2
        ? clamped
        : '${clamped.substring(0, 2)}:${clamped.substring(2)}';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
