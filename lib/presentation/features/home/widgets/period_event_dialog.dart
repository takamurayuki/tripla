import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/topic.dart';
import '../../../../domain/entities/topic_category.dart';
import '../../../providers/current_user_provider.dart';
import '../../../providers/day_providers.dart';
import '../../../providers/topic_providers.dart';
import '../../../providers/trip_providers.dart';
import '../../../widgets/common/clearable_input.dart';

/// 期間予定 (日付を跨ぐ予定 — 出張 / 旅行 など) を新規作成するダイアログ。
///
/// 入力:
/// - タイトル
/// - 開始日 / 終了日
/// - 表示色 (パレットから選択)
///
/// カテゴリ / メモは不要 (期間予定はカレンダーで色帯として目立たせるだけ)。
/// 内部的には category=other で保存し、 色は `colorHex` 列で持つ。
///
/// 保存内容:
/// - 開始日の Day を `ensureDayForDate` で確保し、 そこへ Topic を作る
/// - `startTime = 開始日 00:00`, `endTime = 終了日 23:59`
Future<void> showPeriodEventDialog({
  required BuildContext context,
  required WidgetRef ref,
  DateTime? initialStartDate,
}) async {
  final today = DateTime.now();
  final initStart = initialStartDate ?? DateTime(today.year, today.month, today.day);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return _PeriodEventDialog(initialStartDate: initStart);
    },
  );
}

/// 既存の期間予定を編集するダイアログ。
///
/// 月ビューのピルタップから起動し、 タイトル / メモ / 表示色 の編集と削除を
/// 同一モーダル内で行う。
///
/// 開始日 / 終了日はこのダイアログでは編集しない (日付変更はドラッグ操作が担当。
/// 月ビューの直感性を損なわないため — 要件の明示指示)。
Future<void> showPeriodEventEditDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Topic topic,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return _PeriodEventEditDialog(topic: topic);
    },
  );
}

/// 期間予定で選択できる色パレット。
/// 必要に応じて追加 / 並び替え可能。
const _palette = <Color>[
  AppColors.triplaTeal,
  AppColors.bandanaGreen,
  AppColors.warmOrange,
  AppColors.coralRed,
  AppColors.tritaYellow,
  AppColors.skyBlue,
  AppColors.deepNavy,
  AppColors.mintGreen,
  Color(0xFF9C5BD8), // purple
  Color(0xFFE7669C), // pink
  AppColors.softGray,
  AppColors.darkBrown,
];

String _toHex(Color c) {
  String two(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#${two((c.r * 255).round())}'
      '${two((c.g * 255).round())}'
      '${two((c.b * 255).round())}';
}

class _PeriodEventDialog extends ConsumerStatefulWidget {
  const _PeriodEventDialog({required this.initialStartDate});
  final DateTime initialStartDate;

  @override
  ConsumerState<_PeriodEventDialog> createState() =>
      _PeriodEventDialogState();
}

class _PeriodEventDialogState extends ConsumerState<_PeriodEventDialog> {
  final _titleController = TextEditingController();

  late DateTime _startDate;
  late DateTime _endDate;
  Color _selectedColor = _palette.first;
  bool _saving = false;

  static final _dateFmt = DateFormat('yyyy/M/d (E)', 'ja');

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = _startDate.add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(_startDate.year - 5),
      lastDate: DateTime(_startDate.year + 5),
    );
    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day);
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      });
    }
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime(_startDate.year + 5),
    );
    if (picked != null) {
      setState(() {
        _endDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _onSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイトルを入力してください')),
      );
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('終了日は開始日以降にしてください')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final ownerId = ref.read(currentUserIdProvider);
      final trip =
          await ref.read(tripRepositoryProvider).getOrCreateSchedule(ownerId);
      final day = await ref
          .read(dayRepositoryProvider)
          .ensureDayForDate(tripId: trip.id, date: _startDate);
      final startDT = DateTime(
          _startDate.year, _startDate.month, _startDate.day, 0, 0);
      final endDT =
          DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59);
      await ref.read(topicRepositoryProvider).create(
            dayId: day.id,
            category: TopicCategory.other,
            title: title,
            startTime: startDT,
            endTime: endDT,
            colorHex: _toHex(_selectedColor),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('期間予定を追加しました')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('期間予定を追加'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'タイトル',
                hintText: '例: 出張 / 旅行 / 学会',
                suffixIcon: clearSuffixFor(_titleController),
              ),
            ),
            const SizedBox(height: 16),
            _DateRow(
              label: '開始日',
              date: _startDate,
              format: _dateFmt,
              onTap: _pickStart,
            ),
            const SizedBox(height: 8),
            _DateRow(
              label: '終了日',
              date: _endDate,
              format: _dateFmt,
              onTap: _pickEnd,
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '表示色',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.softGray,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _palette)
                  _ColorSwatch(
                    color: c,
                    selected: c.toARGB32() == _selectedColor.toARGB32(),
                    onTap: () => setState(() => _selectedColor = c),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _saving ? null : _onSave,
          child: Text(_saving ? '保存中...' : '追加'),
        ),
      ],
    );
  }
}

class _PeriodEventEditDialog extends ConsumerStatefulWidget {
  const _PeriodEventEditDialog({required this.topic});
  final Topic topic;

  @override
  ConsumerState<_PeriodEventEditDialog> createState() =>
      _PeriodEventEditDialogState();
}

class _PeriodEventEditDialogState
    extends ConsumerState<_PeriodEventEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  late Color _selectedColor;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.topic.title);
    _descriptionController =
        TextEditingController(text: widget.topic.description ?? '');
    // displayColor は常に非 null (colorHex が無ければ category.color)。
    // パレット外の色でもそのまま保持し、 選び直さず保存すれば元色を維持する。
    _selectedColor = widget.topic.displayColor;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイトルを入力してください')),
      );
      return;
    }
    final description = _descriptionController.text.trim();
    setState(() => _saving = true);
    try {
      // copyWith は `?? this.field` で null を「変更なし」と扱うため、
      // メモを空にした場合に旧値が残ってしまう。
      // そのため Topic を直接組み立てて、null をそのまま反映する。
      final ex = widget.topic;
      final updated = Topic(
        id: ex.id,
        dayId: ex.dayId,
        parentTopicId: ex.parentTopicId,
        orderIndex: ex.orderIndex,
        category: ex.category,
        title: title,
        description: description.isEmpty ? null : description,
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
        colorHex: _toHex(_selectedColor),
        photos: ex.photos,
        trainTransfers: ex.trainTransfers,
        actualStartTime: ex.actualStartTime,
        actualEndTime: ex.actualEndTime,
        actualStatus: ex.actualStatus,
        actualNote: ex.actualNote,
        createdAt: ex.createdAt,
        updatedAt: DateTime.now(),
      );
      await ref.read(topicRepositoryProvider).update(updated);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('期間予定を更新しました')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $error')),
      );
    }
  }

  Future<void> _onDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('期間予定を削除しますか？'),
        content: Text('「${widget.topic.title}」を削除します。 元に戻せません。'),
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
    setState(() => _saving = true);
    try {
      await ref.read(topicRepositoryProvider).delete(widget.topic.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('期間予定を削除しました')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除に失敗しました: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('期間予定を編集'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'タイトル',
                hintText: '例: 出張 / 旅行 / 学会',
                suffixIcon: clearSuffixFor(_titleController),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'メモ',
                hintText: '補足があれば入力',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '表示色',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.softGray,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _palette)
                  _ColorSwatch(
                    color: c,
                    selected: c.toARGB32() == _selectedColor.toARGB32(),
                    onTap: () => setState(() => _selectedColor = c),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saving ? null : _onDelete,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.coralRed,
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                label: const Text('この期間予定を削除'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _saving ? null : _onSave,
          child: Text(_saving ? '保存中...' : '保存'),
        ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.date,
    required this.format,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final DateFormat format;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
        ),
        child: Text(
          format.format(date),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.darkBrown,
          ),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '色を選択',
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.darkBrown : Colors.white,
              width: selected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 2,
              ),
            ],
          ),
          child: selected
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
