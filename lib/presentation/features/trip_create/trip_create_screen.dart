import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/current_user_provider.dart';
import '../../providers/trip_providers.dart';
import '../../widgets/common/clearable_input.dart';
import '../../widgets/trita/trita_state.dart';
import '../../widgets/trita/trita_widget.dart';

/// 旅程の新規作成画面。
///
/// Phase 1 マイルストーン 1 ではタイトル / 期間 / 説明 の最小フォーム。
/// Phase 1 マイルストーン 1.2 で「カバー画像 / 通貨 / メンバー」を拡張予定。
class TripCreateScreen extends ConsumerStatefulWidget {
  const TripCreateScreen({super.key});

  @override
  ConsumerState<TripCreateScreen> createState() => _TripCreateScreenState();
}

class _TripCreateScreenState extends ConsumerState<TripCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTimeRange? _dateRange;
  bool _saving = false;

  static final _dateFormat = DateFormat('yyyy/MM/dd');

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDateRange: _dateRange ??
          DateTimeRange(
            start: now,
            end: now.add(const Duration(days: 2)),
          ),
      helpText: '旅行の期間を選択',
      cancelText: 'キャンセル',
      confirmText: '決定',
      saveText: '決定',
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('旅行の期間を選択してください')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(tripRepositoryProvider).create(
            ownerId: ref.read(currentUserIdProvider),
            title: _titleController.text.trim(),
            startDate: _dateRange!.start,
            endDate: _dateRange!.end,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
          );
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('旅程を作成しました')),
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
    final dateText = _dateRange == null
        ? '期間を選択'
        : '${_dateFormat.format(_dateRange!.start)} - '
            '${_dateFormat.format(_dateRange!.end)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('新しい旅程'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: '閉じる',
          onPressed: () => context.pop(),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              const Center(
                child: TritaWidget(state: TritaState.mapOpen, size: 160),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'どこに行く？',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'タイトル',
                  hintText: '例: 京都2泊3日',
                  suffixIcon: clearSuffixFor(_titleController),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'タイトルを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDateRange,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '期間',
                    prefixIcon: Icon(Icons.calendar_month_rounded),
                  ),
                  child: Text(
                    dateText,
                    style: TextStyle(
                      color: _dateRange == null
                          ? AppColors.softGray
                          : AppColors.darkBrown,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'メモ (任意)',
                  hintText: '旅のテーマ、メンバー、楽しみなことなど',
                  prefixIcon: const Icon(Icons.notes_rounded),
                  suffixIcon: clearSuffixFor(_descriptionController),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 32),
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
                label: Text(_saving ? '保存中...' : 'この内容で作成'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
