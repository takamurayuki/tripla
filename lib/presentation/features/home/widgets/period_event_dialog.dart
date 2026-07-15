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

/// 期間予定 (日付を跨ぐ予定 — 出張 / 旅行 など) の作成 / 編集ダイアログ。
///
/// 入力:
/// - タイトル
/// - 開始日 / 終了日
/// - 表示色 (パレットから選択)
///
/// カテゴリ / メモは不要 (期間予定はカレンダーで色帯として目立たせるだけ)。
/// 内部的には category=other で保存し、 色は `colorHex` 列で持つ。
///
/// 新規作成 ([existing] == null):
/// - 開始日の Day を `ensureDayForDate` で確保し、 そこへ Topic を作る
/// - `startTime = 開始日 00:00`, `endTime = 終了日 23:59`
///
/// 編集 ([existing] != null):
/// - タイトル / 開始日 / 終了日 / 表示色を事前入力して開く
/// - 保存は `TopicRepository.update`。 dayId は付け替えない
///   (カレンダー表示は startTime / endTime の日付だけを見るため)
/// - 時刻成分は元の予定から引き継ぐ (日付のみ差し替え)
/// - ダイアログ内の削除ボタンからも削除できる
Future<void> showPeriodEventDialog({
  required BuildContext context,
  required WidgetRef ref,
  DateTime? initialStartDate,
  Topic? existing,
}) async {
  final today = DateTime.now();
  final initStart = initialStartDate ?? DateTime(today.year, today.month, today.day);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return _PeriodEventDialog(initialStartDate: initStart, existing: existing);
    },
  );
}

/// 期間予定の削除確認 → 削除。 実際に削除したら true を返す。
/// 月ビューのピル長押し / 右クリックと、 編集ダイアログの削除ボタンから共用する。
Future<bool> confirmDeletePeriodEvent({
  required BuildContext context,
  required WidgetRef ref,
  required Topic topic,
}) async {
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
  if (confirmed != true) return false;
  try {
    await ref.read(topicRepositoryProvider).delete(topic.id);
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除に失敗しました: $error')),
      );
    }
    return false;
  }
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
  const _PeriodEventDialog({required this.initialStartDate, this.existing});
  final DateTime initialStartDate;

  /// 編集対象の期間予定。 null なら新規作成モード。
  final Topic? existing;

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

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      final s = existing.startTime!;
      final e = existing.endTime!;
      _startDate = DateTime(s.year, s.month, s.day);
      _endDate = DateTime(e.year, e.month, e.day);
      _selectedColor = existing.displayColor;
    } else {
      _startDate = widget.initialStartDate;
      _endDate = _startDate.add(const Duration(days: 1));
    }
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
        if (_isEdit) {
          // 編集では期間予定 (2 日以上) を維持する。
          // 1 日に縮めると帯からスポット予定に変わり、 dayId の日付と
          // startTime の日付がズレて表示日が食い違うため許可しない。
          if (!_endDate.isAfter(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _pickEnd() async {
    // 編集では期間予定のまま維持するため終了日は開始日の翌日以降。
    final firstSelectable =
        _isEdit ? _startDate.add(const Duration(days: 1)) : _startDate;
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _endDate.isBefore(firstSelectable) ? firstSelectable : _endDate,
      firstDate: firstSelectable,
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
    final existing = widget.existing;
    if (existing == null && _endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('終了日は開始日以降にしてください')),
      );
      return;
    }
    if (existing != null && !_endDate.isAfter(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('終了日は開始日の翌日以降にしてください')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (existing != null) {
        // 日付だけ差し替え、 時刻成分は元の予定から引き継ぐ
        // (ダイアログ作成なら 00:00 / 23:59、 トピック編集経由なら任意時刻)。
        final s = existing.startTime!;
        final e = existing.endTime!;
        await ref.read(topicRepositoryProvider).update(
              existing.copyWith(
                title: title,
                startTime: DateTime(_startDate.year, _startDate.month,
                    _startDate.day, s.hour, s.minute),
                endTime: DateTime(
                    _endDate.year, _endDate.month, _endDate.day, e.hour, e.minute),
                colorHex: _toHex(_selectedColor),
              ),
            );
      } else {
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
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing != null ? '期間予定を更新しました' : '期間予定を追加しました'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $error')),
      );
    }
  }

  /// 編集モードのみ: 削除確認 → 削除に成功したらこのダイアログも閉じる。
  Future<void> _onDelete() async {
    final existing = widget.existing!;
    setState(() => _saving = true);
    final deleted = await confirmDeletePeriodEvent(
      context: context,
      ref: ref,
      topic: existing,
    );
    if (!mounted) return;
    if (!deleted) {
      setState(() => _saving = false);
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('期間予定を削除しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? '期間予定を編集' : '期間予定を追加'),
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
        if (_isEdit)
          TextButton(
            onPressed: _saving ? null : _onDelete,
            style: TextButton.styleFrom(foregroundColor: AppColors.coralRed),
            child: const Text('削除'),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _saving ? null : _onSave,
          child: Text(_saving ? '保存中...' : (_isEdit ? '保存' : '追加')),
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
