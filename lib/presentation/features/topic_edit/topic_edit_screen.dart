import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/handle_async_action.dart';
import '../../../domain/entities/topic.dart';
import '../../../domain/entities/topic_category.dart';
import '../../../domain/entities/transport_mode.dart';
import '../../providers/topic_providers.dart';
import '../../widgets/common/clearable_input.dart';

/// 要件定義書 §7.2 S-05 トピック編集画面。
///
/// - 上部 2 タブ: 概要 / コンテンツ
/// - 入力変更は 500ms debounce でオートセーブ (保存ボタンは持たない、§14.4)
/// - 削除はアプリバーのメニューから
class TopicEditScreen extends ConsumerWidget {
  const TopicEditScreen({super.key, required this.topicId});

  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicAsync = ref.watch(topicByIdProvider(topicId));
    return topicAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
      data: (topic) {
        if (topic == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('この予定は削除されたよ')),
          );
        }
        return _TopicEditView(initial: topic);
      },
    );
  }
}

class _TopicEditView extends ConsumerStatefulWidget {
  const _TopicEditView({required this.initial});

  final Topic initial;

  @override
  ConsumerState<_TopicEditView> createState() => _TopicEditViewState();
}

class _TopicEditViewState extends ConsumerState<_TopicEditView>
    with SingleTickerProviderStateMixin {
  static const _autosaveDelay = Duration(milliseconds: 500);
  static final _timeFormat = DateFormat('HH:mm');

  late final TabController _tabController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _departureController;
  late final TextEditingController _destinationController;
  late final TextEditingController _costController;

  late TopicCategory _category;
  TransportMode? _transportMode;
  DateTime? _startTime;
  DateTime? _endTime;
  late bool _isCompleted;

  Timer? _debounce;
  _SaveStatus _saveStatus = _SaveStatus.idle;

  /// 直近に保存した内容。dispose 時のフラッシュで使う。
  late Topic _current;

  bool get _isTransport => _category == TopicCategory.transport;

  @override
  void initState() {
    super.initState();
    _current = widget.initial;
    _tabController = TabController(length: 2, vsync: this);
    _titleController = TextEditingController(text: widget.initial.title)
      ..addListener(_scheduleSave);
    _descriptionController =
        TextEditingController(text: widget.initial.description ?? '')
          ..addListener(_scheduleSave);
    _departureController =
        TextEditingController(text: widget.initial.departure ?? '')
          ..addListener(_scheduleSave);
    _destinationController =
        TextEditingController(text: widget.initial.destination ?? '')
          ..addListener(_scheduleSave);
    _costController = TextEditingController(
      text: widget.initial.cost == null
          ? ''
          : widget.initial.cost!.toStringAsFixed(0),
    )..addListener(_scheduleSave);
    _category = widget.initial.category;
    _transportMode = widget.initial.transportMode;
    _startTime = widget.initial.startTime;
    _endTime = widget.initial.endTime;
    _isCompleted = widget.initial.isCompleted;
  }

  @override
  void dispose() {
    // 保留中の入力があれば dispose 前にスナップショットを取って fire-and-forget で保存する。
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      final snapshot = _buildSnapshot();
      unawaited(ref.read(topicRepositoryProvider).update(snapshot));
    }
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _departureController.dispose();
    _destinationController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _debounce?.cancel();
    if (_saveStatus != _SaveStatus.saving) {
      setState(() => _saveStatus = _SaveStatus.dirty);
    }
    _debounce = Timer(_autosaveDelay, _save);
  }

  Topic _buildSnapshot() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final departure = _departureController.text.trim();
    final destination = _destinationController.text.trim();
    final costText = _costController.text.trim();
    final cost = costText.isEmpty ? null : double.tryParse(costText);

    // copyWith は `?? this.field` で null を「変更なし」扱いするため、
    // メモ削除 / 費用クリア / 時刻クリア / 移動→予定切替 などで旧値が残る。
    // 編集時は Topic を直接組み立てて null をそのまま反映する。
    return Topic(
      id: _current.id,
      dayId: _current.dayId,
      parentTopicId: _current.parentTopicId,
      orderIndex: _current.orderIndex,
      category: _category,
      title: title.isEmpty ? '(無題の予定)' : title,
      description: description.isEmpty ? null : description,
      startTime: _startTime,
      endTime: _endTime,
      latitude: _current.latitude,
      longitude: _current.longitude,
      locationName: _current.locationName,
      address: _current.address,
      cost: cost,
      costCurrency: cost == null ? null : (_current.costCurrency ?? 'JPY'),
      isCompleted: _isCompleted,
      departure: _isTransport && departure.isNotEmpty ? departure : null,
      destination: _isTransport && destination.isNotEmpty ? destination : null,
      transportMode: _isTransport ? _transportMode : null,
      altPlans: _current.altPlans,
      links: _current.links,
      createdAt: _current.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _save() async {
    if (!mounted) return;
    setState(() => _saveStatus = _SaveStatus.saving);
    final snapshot = _buildSnapshot();
    _current = snapshot;
    try {
      await ref.read(topicRepositoryProvider).update(snapshot);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $error')),
      );
    }
    if (!mounted) return;
    setState(() => _saveStatus = _SaveStatus.saved);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final fallback = _startTime ?? widget.initial.startTime ?? DateTime.now();
    final base = (isStart ? _startTime : _endTime) ?? fallback;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (picked == null || !mounted) return;
    final dayDate = widget.initial.startTime ?? DateTime.now();
    final dt = DateTime(
      dayDate.year,
      dayDate.month,
      dayDate.day,
      picked.hour,
      picked.minute,
    );
    setState(() {
      if (isStart) {
        _startTime = dt;
      } else {
        _endTime = dt;
      }
    });
    _scheduleSave();
  }

  Future<void> _onDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('この予定を削除しますか？'),
        content: Text('「${_current.title}」を削除すると元に戻せないよ。'),
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
    _debounce?.cancel();
    final ok = await handleAsyncAction(
      context,
      () => ref.read(topicRepositoryProvider).delete(_current.id),
      errorMessage: '削除に失敗しました',
    );
    if (!ok || !mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paperWhite,
      appBar: AppBar(
        title: const Text('予定を編集'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.triplaTeal,
          labelColor: AppColors.triplaTeal,
          unselectedLabelColor: AppColors.softGray,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline_rounded), text: '概要'),
            Tab(icon: Icon(Icons.notes_rounded), text: 'コンテンツ'),
          ],
        ),
        actions: [
          _SaveIndicator(status: _saveStatus),
          PopupMenuButton<_MenuAction>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (a) {
              if (a == _MenuAction.delete) _onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _MenuAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded,
                      color: AppColors.coralRed),
                  title: Text('予定を削除',
                      style: TextStyle(color: AppColors.coralRed)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(context),
          _buildContentTab(context),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context) {
    final categories =
        TopicCategory.values.where((c) => c != TopicCategory.transport).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(
            icon: Icons.category_rounded,
            label: _isTransport ? '移動手段' : 'カテゴリ',
          ),
          const SizedBox(height: 8),
          if (_isTransport)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mode in TransportMode.values)
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(mode.icon,
                            size: 16, color: AppColors.triplaTeal),
                        const SizedBox(width: 4),
                        Text(mode.label),
                      ],
                    ),
                    selected: mode == _transportMode,
                    selectedColor:
                        AppColors.triplaTeal.withValues(alpha: 0.18),
                    onSelected: (_) {
                      setState(() => _transportMode = mode);
                      _scheduleSave();
                    },
                  ),
              ],
            )
          else
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
                    selected: cat == _category,
                    selectedColor: cat.color.withValues(alpha: 0.2),
                    onSelected: (_) {
                      setState(() => _category = cat);
                      _scheduleSave();
                    },
                  ),
              ],
            ),
          const SizedBox(height: 20),
          if (_isTransport) ...[
            _SectionLabel(
                icon: Icons.trip_origin_rounded, label: '出発地'),
            const SizedBox(height: 6),
            TextField(
              controller: _departureController,
              decoration: InputDecoration(
                hintText: '例: 東京駅',
                suffixIcon: clearSuffixFor(_departureController),
              ),
            ),
            const SizedBox(height: 16),
            _SectionLabel(icon: Icons.flag_outlined, label: '到着地'),
            const SizedBox(height: 6),
            TextField(
              controller: _destinationController,
              decoration: InputDecoration(
                hintText: '例: 京都駅',
                suffixIcon: clearSuffixFor(_destinationController),
              ),
            ),
          ] else ...[
            _SectionLabel(icon: Icons.title_rounded, label: 'タイトル'),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: '例: 清水寺観光',
                suffixIcon: clearSuffixFor(_titleController),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _SectionLabel(icon: Icons.schedule_rounded, label: '時間'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _TimeField(
                  label: '開始',
                  value: _startTime,
                  formatter: _timeFormat,
                  onPick: () => _pickTime(isStart: true),
                  onClear: _startTime == null
                      ? null
                      : () {
                          setState(() => _startTime = null);
                          _scheduleSave();
                        },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('〜',
                    style: TextStyle(color: AppColors.softGray)),
              ),
              Expanded(
                child: _TimeField(
                  label: '終了',
                  value: _endTime,
                  formatter: _timeFormat,
                  onPick: () => _pickTime(isStart: false),
                  onClear: _endTime == null
                      ? null
                      : () {
                          setState(() => _endTime = null);
                          _scheduleSave();
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            value: _isCompleted,
            onChanged: (v) {
              setState(() => _isCompleted = v);
              _scheduleSave();
            },
            title: const Text('この予定を完了済みにする'),
            secondary: const Icon(Icons.check_circle_outline),
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            activeThumbColor: AppColors.triplaTeal,
          ),
        ],
      ),
    );
  }

  Widget _buildContentTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(icon: Icons.notes_rounded, label: 'メモ'),
          const SizedBox(height: 6),
          TextField(
            controller: _descriptionController,
            maxLines: 8,
            minLines: 4,
            decoration: const InputDecoration(
              hintText: 'メモや持ち物、URL、思い出など自由に書けるよ',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel(icon: Icons.payments_outlined, label: '費用 (任意)'),
          const SizedBox(height: 6),
          TextField(
            controller: _costController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              prefixText: '¥ ',
              hintText: '0',
            ),
          ),
        ],
      ),
    );
  }
}

enum _MenuAction { delete }

enum _SaveStatus { idle, dirty, saving, saved }

class _SaveIndicator extends StatelessWidget {
  const _SaveIndicator({required this.status});

  final _SaveStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (status) {
      _SaveStatus.idle =>
        (Icons.cloud_done_outlined, '保存済み', AppColors.softGray),
      _SaveStatus.dirty =>
        (Icons.edit_note_rounded, '入力中…', AppColors.softGray),
      _SaveStatus.saving =>
        (Icons.cloud_sync_rounded, '保存中…', AppColors.triplaTeal),
      _SaveStatus.saved =>
        (Icons.cloud_done_rounded, '保存済み', AppColors.triplaTeal),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Center(
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.triplaTealDark),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.triplaTealDark,
          ),
        ),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.formatter,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final DateFormat formatter;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPick,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onClear == null
              ? const Icon(Icons.schedule_rounded)
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClear,
                ),
        ),
        child: Text(
          value == null ? '未設定' : formatter.format(value!),
          style: TextStyle(
            fontSize: 16,
            color: value == null ? AppColors.softGray : AppColors.darkBrown,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
