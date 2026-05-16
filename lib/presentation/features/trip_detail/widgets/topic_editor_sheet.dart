import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/handle_async_action.dart';
import '../../../../domain/entities/day.dart';
import '../../../../domain/entities/topic.dart';
import '../../../../domain/entities/topic_alt_plan.dart';
import '../../../../domain/entities/topic_category.dart';
import '../../../../domain/entities/topic_link.dart';
import '../../../../domain/entities/transport_mode.dart';
import '../../../../domain/entities/trip_mode.dart';
import '../../../providers/topic_providers.dart';
import '../../../widgets/common/clearable_input.dart';

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
  TripMode tripMode = TripMode.plan,
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
        tripMode: tripMode,
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
    this.tripMode = TripMode.plan,
  });

  final Day day;
  final Topic? existing;
  final String? insertAfterTopicId;
  final TripMode tripMode;

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

  /// 編集中の代替プラン (移動 / 予定 どちらでも使う)。
  /// 「採用」ボタンでフォームの値とスワップする。
  List<TopicAltPlan> _altPlans = [];

  /// 編集中のリンク。保存ボタンで Topic に反映される。
  List<TopicLink> _links = [];

  final _uuid = const Uuid();

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
      _altPlans = List<TopicAltPlan>.from(ex.altPlans);
      _links = List<TopicLink>.from(ex.links);
    }
  }

  /// 現在のフォーム値から TopicAltPlan を構築 (採用案以外を保存するときに使う)。
  /// 移動モード / 予定モードで埋めるフィールドを切り替える。
  TopicAltPlan _planFromForm({String? id, String? label}) {
    final note = _descriptionController.text.trim();
    final startT = _parseTime(_startController.text);
    final endT = _parseTime(_endController.text);
    if (_mode == _Mode.transport) {
      final dep = _departureController.text.trim();
      final dest = _destinationController.text.trim();
      return TopicAltPlan(
        id: id ?? _uuid.v4(),
        label: label,
        departure: dep.isEmpty ? null : dep,
        destination: dest.isEmpty ? null : dest,
        transportMode: _transportMode,
        startTime: startT == null ? null : _toDateTime(startT),
        endTime: endT == null ? null : _toDateTime(endT),
        note: note.isEmpty ? null : note,
      );
    }
    final title = _titleController.text.trim();
    return TopicAltPlan(
      id: id ?? _uuid.v4(),
      label: label,
      title: title.isEmpty ? null : title,
      category: _planCategory,
      startTime: startT == null ? null : _toDateTime(startT),
      endTime: endT == null ? null : _toDateTime(endT),
      note: note.isEmpty ? null : note,
    );
  }

  /// altPlans の現在の状態を DB に即時反映する。
  /// 既存 Topic 編集時のみ動作 (新規作成時はまだ Topic 自体がないので「保存」ボタンを待つ)。
  Future<void> _persistAltPlans() async {
    if (!_isEditing) return;
    final ex = widget.existing!;
    await handleAsyncAction(
      context,
      () => ref.read(topicRepositoryProvider).update(
            ex.copyWith(altPlans: _altPlans),
          ),
      errorMessage: '代替プランの保存に失敗しました',
    );
  }

  /// 「現在の入力を代替プランに保存」 — フォームの値を新規プランとして altPlans に積み、
  /// 既存 Topic ならその場で DB にも反映する (保存忘れで消えないように)。
  Future<void> _saveCurrentAsAltPlan() async {
    setState(() {
      _altPlans = [..._altPlans, _planFromForm()];
    });
    await _persistAltPlans();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing
            ? '代替プランに追加しました'
            : '代替プランに追加しました (保存時に確定)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 「このプランを採用」 — index のプランをフォームに展開し、
  /// 元のフォーム値を新規プランとして altPlans の同じ位置に挿入する (スワップ)。
  /// altPlans の変更は即 DB 反映する。
  /// 現在のモード (移動 / 予定) に対応するフィールドを更新する。
  Future<void> _adoptPlan(int index) async {
    final picked = _altPlans[index];
    final swappedOut = _planFromForm();
    setState(() {
      _descriptionController.text = picked.note ?? '';
      _startController.text = _formatTime(picked.startTime);
      _endController.text = _formatTime(picked.endTime);
      if (_mode == _Mode.transport) {
        _departureController.text = picked.departure ?? '';
        _destinationController.text = picked.destination ?? '';
        if (picked.transportMode != null) {
          _transportMode = picked.transportMode!;
        }
      } else {
        _titleController.text = picked.title ?? '';
        if (picked.category != null) {
          _planCategory = picked.category!;
        }
      }
      // altPlans から採用プランを取り除き、スワップ元を同じ位置に挿入
      final next = [..._altPlans];
      next[index] = swappedOut;
      _altPlans = next;
    });
    await _persistAltPlans();
  }

  Future<void> _removePlan(int index) async {
    setState(() {
      _altPlans = [..._altPlans]..removeAt(index);
    });
    await _persistAltPlans();
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

  DateTime _toDateTime(TimeOfDay t) {
    final d = widget.day.date;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    final isTransport = _mode == _Mode.transport;
    final startT = _parseTime(_startController.text.trim());
    final endT = _parseTime(_endController.text.trim());
    // validate() を通った時点で必須・形式・範囲チェックは済んでいるが、
    // null 安全のため再確認 (理論上ここに来るとき null は来ない)。
    if (startT == null || endT == null) return;

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
      // 移動 / 予定どちらでも代替プランは保存する。
      final plansToSave = _altPlans;
      if (_isEditing) {
        // copyWith は `?? this.field` で null を「変更なし」と扱うため、
        // 「メモ削除」や「移動→予定への切替で出発地/到着地/手段を空に」
        // した場合に旧値が残ってしまう。
        // そのため編集時は Topic を直接組み立てて、null をそのまま反映する。
        final ex = widget.existing!;
        final updated = Topic(
          id: ex.id,
          dayId: ex.dayId,
          parentTopicId: ex.parentTopicId,
          orderIndex: ex.orderIndex,
          category: category,
          title: title,
          description: description.isEmpty ? null : description,
          startTime: _toDateTime(startT),
          endTime: _toDateTime(endT),
          latitude: ex.latitude,
          longitude: ex.longitude,
          locationName: ex.locationName,
          address: ex.address,
          cost: ex.cost,
          costCurrency: ex.costCurrency,
          isCompleted: ex.isCompleted,
          departure: departure == null || departure.isEmpty ? null : departure,
          destination:
              destination == null || destination.isEmpty ? null : destination,
          transportMode: transport,
          altPlans: plansToSave,
          links: _links,
          createdAt: ex.createdAt,
          updatedAt: DateTime.now(),
        );
        await repo.update(updated);
      } else {
        final newId = await repo.create(
          dayId: widget.day.id,
          category: category,
          title: title,
          description: description.isEmpty ? null : description,
          startTime: _toDateTime(startT),
          endTime: _toDateTime(endT),
          departure: departure == null || departure.isEmpty ? null : departure,
          destination:
              destination == null || destination.isEmpty ? null : destination,
          transportMode: transport,
          altPlans: plansToSave,
          links: _links,
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

  Future<TopicLink?> _showLinkDialog({
    required BuildContext context,
    TopicLink? existing,
  }) async {
    final labelController =
        TextEditingController(text: existing?.label ?? '');
    final urlController = TextEditingController(text: existing?.url ?? '');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<TopicLink>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(existing == null ? 'リンクを追加' : 'リンクを編集'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: labelController,
                  decoration: InputDecoration(
                    labelText: 'ラベル (任意)',
                    hintText: '例: 予約サイト',
                    suffixIcon: clearSuffixFor(labelController),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: urlController,
                  autofocus: existing == null,
                  decoration: InputDecoration(
                    labelText: 'URL',
                    hintText: 'https://...',
                    suffixIcon: clearSuffixFor(urlController),
                  ),
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return 'URL を入力してください';
                    final uri = Uri.tryParse(text);
                    if (uri == null ||
                        !uri.hasScheme ||
                        !(uri.scheme == 'http' || uri.scheme == 'https')) {
                      return 'http(s) で始まる URL を入力してください';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(dialogContext).pop(TopicLink(
                  id: existing?.id ?? _uuid.v4(),
                  label: labelController.text.trim(),
                  url: urlController.text.trim(),
                ));
              },
              child: Text(existing == null ? '追加' : '保存'),
            ),
          ],
        );
      },
    );
    return result;
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
    // Stack で本文 + 左上に固定の × ボタンを重ねる。
    // 本文をスクロールしても × は固定位置で見え続ける。
    return Stack(
      children: [
        Form(
          key: _formKey,
          child: SingleChildScrollView(
            // 左上の × ボタンと被らないよう top を 56 に。
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
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
                // 予定 / 移動 セグメント
                _ModeSegment(
                  mode: _mode,
                  onChanged: (m) => setState(() => _mode = m),
                ),
                const SizedBox(height: 16),
                if (_mode == _Mode.transport)
                  ..._buildTransportFields(context),
                if (_mode == _Mode.plan) ..._buildPlanFields(context),
                const SizedBox(height: 12),
                _TimeRangeRow(
                  startController: _startController,
                  endController: _endController,
                  startLabel: _mode == _Mode.transport ? '出発' : '開始',
                  endLabel: _mode == _Mode.transport ? '到着' : '終了',
                  parseTime: _parseTime,
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
                const SizedBox(height: 16),
                _LinksSection(
                  links: _links,
                  onAdd: () async {
                    final added = await _showLinkDialog(context: context);
                    if (added != null) {
                      setState(() => _links = [..._links, added]);
                    }
                  },
                  onEdit: (index) async {
                    final updated = await _showLinkDialog(
                      context: context,
                      existing: _links[index],
                    );
                    if (updated != null) {
                      setState(() {
                        final next = [..._links];
                        next[index] = updated;
                        _links = next;
                      });
                    }
                  },
                  onRemove: (index) {
                    setState(() {
                      _links = [..._links]..removeAt(index);
                    });
                  },
                ),
                // 代替プランセクション (移動 / 予定 どちらでも表示)
                const SizedBox(height: 16),
                _AltPlanSection(
                  plans: _altPlans,
                  onSaveCurrent: _saveCurrentAsAltPlan,
                  onAdopt: _adoptPlan,
                  onRemove: _removePlan,
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
        ),
        // 左上に固定の × 閉じるボタン。 スクロールしても常に同じ位置に居続ける。
        Positioned(
          top: 4,
          left: 4,
          child: Material(
            color: Colors.transparent,
            child: IconButton(
              tooltip: '閉じる',
              icon: const Icon(Icons.close_rounded),
              color: AppColors.softGray,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPlanFields(BuildContext context) {
    // schedule モードでは「宿泊」は対象外、 「観光」 は「イベント」 として表示する。
    final categories =
        TopicCategoryDisplay.selectableForPlanMode(widget.tripMode);
    return [
      TextFormField(
        controller: _titleController,
        autofocus: !_isEditing,
        decoration: InputDecoration(
          labelText: 'タイトル',
          hintText: '例: 清水寺観光',
          suffixIcon: clearSuffixFor(_titleController),
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
                  Icon(cat.iconFor(widget.tripMode),
                      size: 16, color: cat.color),
                  const SizedBox(width: 4),
                  Text(cat.labelFor(widget.tripMode)),
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
        decoration: InputDecoration(
          labelText: '出発地',
          hintText: '例: 東京駅',
          prefixIcon: const Icon(Icons.trip_origin_rounded),
          suffixIcon: clearSuffixFor(_departureController),
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _destinationController,
        decoration: InputDecoration(
          labelText: '到着地',
          hintText: '例: 京都駅',
          prefixIcon: const Icon(Icons.flag_outlined),
          suffixIcon: clearSuffixFor(_destinationController),
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

/// 移動モードの代替プラン一覧 + 「現在の入力を代替プランに保存」ボタン。
///
/// - 「現在の入力を代替プランに保存」: フォームの内容をスナップショットとして altPlans に追加
/// - 行タップ「採用」: そのプランをフォームに展開し、元のフォーム値を altPlans に保持 (スワップ)
/// - 行右の × : altPlans から削除
class _AltPlanSection extends StatelessWidget {
  const _AltPlanSection({
    required this.plans,
    required this.onSaveCurrent,
    required this.onAdopt,
    required this.onRemove,
  });

  final List<TopicAltPlan> plans;
  final VoidCallback onSaveCurrent;
  final ValueChanged<int> onAdopt;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.paperBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.alt_route_rounded,
                  size: 18, color: AppColors.triplaTeal),
              const SizedBox(width: 6),
              Text(
                '代替プラン',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.triplaTealDark,
                    ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.triplaTeal.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${plans.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.triplaTealDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '今の入力を別プランとして残しておけば、当日の状況に合わせて切り替えられるよ。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (plans.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'まだ代替プランはありません',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.softGray,
                    ),
              ),
            )
          else
            for (var i = 0; i < plans.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == plans.length - 1 ? 0 : 8),
                child: _AltPlanRow(
                  index: i,
                  plan: plans[i],
                  onAdopt: () => onAdopt(i),
                  onRemove: () => onRemove(i),
                ),
              ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onSaveCurrent,
            icon: const Icon(Icons.add_rounded),
            label: const Text('現在の入力を代替プランに保存'),
          ),
        ],
      ),
    );
  }
}

class _AltPlanRow extends StatelessWidget {
  const _AltPlanRow({
    required this.index,
    required this.plan,
    required this.onAdopt,
    required this.onRemove,
  });

  final int index;
  final TopicAltPlan plan;
  final VoidCallback onAdopt;
  final VoidCallback onRemove;

  String _label() {
    final base = String.fromCharCode(0x41 + index); // A, B, C ...
    return plan.label?.isNotEmpty == true ? plan.label! : 'プラン$base';
  }

  String _summary() {
    final time = _timeRange(plan.startTime, plan.endTime);
    if (plan.isTransportShape) {
      final mode = plan.transportMode?.label;
      final dep = plan.departure;
      final dest = plan.destination;
      final parts = <String>[
        ?mode,
        if (dep != null && dest != null) '$dep → $dest'
        else if (dep != null) '$dep 発'
        else if (dest != null) '$dest 着',
        if (time.isNotEmpty) time,
      ];
      return parts.isEmpty ? '(内容未設定)' : parts.join(' / ');
    }
    // 予定モード
    final parts = <String>[
      if (plan.title != null && plan.title!.isNotEmpty) plan.title!,
      if (plan.category != null) plan.category!.label,
      if (time.isNotEmpty) time,
    ];
    return parts.isEmpty ? '(内容未設定)' : parts.join(' / ');
  }

  static String _timeRange(DateTime? s, DateTime? e) {
    String fmt(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (s == null && e == null) return '';
    if (s == null) return '〜${fmt(e!)}';
    if (e == null) return '${fmt(s)}〜';
    return '${fmt(s)}〜${fmt(e)}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paleSky.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onAdopt,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              Icon(
                plan.isTransportShape
                    ? (plan.transportMode?.icon ?? Icons.alt_route_rounded)
                    : (plan.category?.icon ?? Icons.alt_route_rounded),
                size: 18,
                color: plan.isTransportShape
                    ? AppColors.triplaTealDark
                    : (plan.category?.color ?? AppColors.triplaTealDark),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _label(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.triplaTealDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _summary(),
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'このプランを採用',
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  color: AppColors.triplaTeal,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  onPressed: onAdopt,
                ),
              ),
              Tooltip(
                message: 'このプランを削除',
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  color: AppColors.softGray,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onRemove,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 開始/終了の 2 つの時刻フィールドをまとめて配置する Row。
///
/// - 必須/形式/「終了 > 開始」チェックを各フィールドの validator に組み込み、
///   フィールド直下に赤文字エラーを表示
/// - 開始時刻の変更を listen し、終了側のドロップダウン候補を
///   「開始時刻より後の時間/分」だけに絞り込んで再描画する
class _TimeRangeRow extends StatefulWidget {
  const _TimeRangeRow({
    required this.startController,
    required this.endController,
    required this.startLabel,
    required this.endLabel,
    required this.parseTime,
  });

  final TextEditingController startController;
  final TextEditingController endController;
  final String startLabel;
  final String endLabel;
  final TimeOfDay? Function(String) parseTime;

  @override
  State<_TimeRangeRow> createState() => _TimeRangeRowState();
}

class _TimeRangeRowState extends State<_TimeRangeRow> {
  @override
  void initState() {
    super.initState();
    widget.startController.addListener(_onStartChanged);
  }

  @override
  void dispose() {
    widget.startController.removeListener(_onStartChanged);
    super.dispose();
  }

  void _onStartChanged() {
    if (mounted) setState(() {}); // 終了側の minTime を再評価するため
  }

  String? _validateStart(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '${widget.startLabel}時刻を入力してください';
    if (widget.parseTime(text) == null) return '00:00〜23:59 で指定してね';
    return null;
  }

  String? _validateEnd(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '${widget.endLabel}時刻を入力してください';
    final endT = widget.parseTime(text);
    if (endT == null) return '00:00〜23:59 で指定してね';
    final startT = widget.parseTime(widget.startController.text.trim());
    if (startT != null) {
      final s = startT.hour * 60 + startT.minute;
      final e = endT.hour * 60 + endT.minute;
      if (e <= s) return '${widget.startLabel}時刻より後にしてください';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final startT = widget.parseTime(widget.startController.text.trim());
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _TimeInputField(
            controller: widget.startController,
            label: widget.startLabel,
            validator: _validateStart,
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
          child: _TimeInputField(
            controller: widget.endController,
            label: widget.endLabel,
            validator: _validateEnd,
            minTime: startT,
          ),
        ),
      ],
    );
  }
}

/// プルダウンだけで入力する時刻フィールド。
///
/// - 中央に常時 `:` を表示
/// - HH / MM の値はそれぞれの ▾ ボタンタップで一覧から選ぶ (タイプ入力なし)
/// - 未選択時はヒント (`HH` / `MM`) を薄く表示
/// - 親 [controller] には `'HH:MM'` または空文字を反映
/// - [validator] を受け取り、エラーは入力フィールド直下に赤文字で表示
/// - [minTime] があれば HH / MM の候補を「これより後」に絞り込む
class _TimeInputField extends StatefulWidget {
  const _TimeInputField({
    required this.controller,
    required this.label,
    this.validator,
    this.minTime,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final TimeOfDay? minTime;

  @override
  State<_TimeInputField> createState() => _TimeInputFieldState();
}

class _TimeInputFieldState extends State<_TimeInputField> {
  int? _hour;
  int? _minute;
  final _fieldKey = GlobalKey<FormFieldState<String>>();

  @override
  void initState() {
    super.initState();
    _syncFromParent();
    widget.controller.addListener(_syncFromParent);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromParent);
    super.dispose();
  }

  void _syncFromParent() {
    final text = widget.controller.text.trim();
    final m = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(text);
    int? h;
    int? mm;
    if (m != null) {
      h = int.tryParse(m.group(1)!);
      mm = int.tryParse(m.group(2)!);
    }
    if (_hour != h || _minute != mm) {
      setState(() {
        _hour = h;
        _minute = mm;
      });
    }
  }

  void _syncToParent() {
    String result;
    if (_hour == null && _minute == null) {
      result = '';
    } else {
      final hh = (_hour ?? 0).toString().padLeft(2, '0');
      final mp = (_minute ?? 0).toString().padLeft(2, '0');
      result = '$hh:$mp';
    }
    if (widget.controller.text != result) {
      widget.controller.text = result;
    }
    _fieldKey.currentState?.didChange(result);
  }

  /// HH ドロップダウンの選択肢。minTime があれば「下限以降の時間」のみ。
  List<int> _allowedHours() {
    final min = widget.minTime;
    if (min == null) return List.generate(24, (i) => i);
    return [for (var i = min.hour; i < 24; i++) i];
  }

  /// MM ドロップダウンの選択肢。
  /// 現在の HH が minTime と同じ時間なら、minTime の分より大きい値だけ許可。
  List<int> _allowedMinutes() {
    final min = widget.minTime;
    if (min == null) return List.generate(60, (i) => i);
    final h = _hour;
    if (h == null) return List.generate(60, (i) => i);
    if (h == min.hour) {
      return [for (var i = min.minute + 1; i < 60; i++) i];
    }
    if (h > min.hour) return List.generate(60, (i) => i);
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: _fieldKey,
      initialValue: widget.controller.text,
      validator: widget.validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (state) => InputDecorator(
        decoration: InputDecoration(
          labelText: widget.label,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          errorText: state.errorText,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TimePartButton(
              value: _hour,
              hint: 'HH',
              tooltip: '時を選ぶ',
              values: _allowedHours(),
              onSelected: (v) {
                setState(() {
                  _hour = v;
                  // 新しい HH に合わせて MM が許可範囲外なら一旦クリア
                  if (_minute != null && !_allowedMinutes().contains(_minute)) {
                    _minute = null;
                  }
                });
                _syncToParent();
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                ':',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.softGray,
                ),
              ),
            ),
            _TimePartButton(
              value: _minute,
              hint: 'MM',
              tooltip: '分を選ぶ',
              values: _allowedMinutes(),
              onSelected: (v) {
                setState(() => _minute = v);
                _syncToParent();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// HH / MM 各 1 つ分のプルダウンボタン。
/// 未選択時はヒント文字 (HH / MM) を薄く表示し、選択するとその値を表示。
class _TimePartButton extends StatelessWidget {
  const _TimePartButton({
    required this.value,
    required this.hint,
    required this.tooltip,
    required this.values,
    required this.onSelected,
  });

  final int? value;
  final String hint;
  final String tooltip;
  final List<int> values;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final enabled = values.isNotEmpty;
    final display = value?.toString().padLeft(2, '0') ?? hint;
    final textColor = value == null
        ? AppColors.softGray.withValues(alpha: 0.5)
        : AppColors.darkBrown;
    return PopupMenuButton<int>(
      tooltip: tooltip,
      enabled: enabled,
      initialValue:
          (value != null && values.contains(value)) ? value : null,
      onSelected: onSelected,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 64, maxHeight: 320),
      itemBuilder: (_) => [
        for (final i in values)
          PopupMenuItem<int>(
            value: i,
            height: 36,
            child: Center(
              child: Text(
                i.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              display,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: enabled
                  ? AppColors.triplaTeal
                  : AppColors.softGray.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// 予定に紐づくリンク一覧 + 「+ リンクを追加」ボタンのセクション。
class _LinksSection extends StatelessWidget {
  const _LinksSection({
    required this.links,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
  });

  final List<TopicLink> links;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.paperBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.link_rounded,
                  size: 18, color: AppColors.triplaTeal),
              const SizedBox(width: 6),
              Text(
                'リンク',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.triplaTealDark,
                    ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.triplaTeal.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${links.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.triplaTealDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '予約サイトや地図など、関連する URL を貼り付けておけます。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (links.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'まだリンクはありません',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.softGray,
                    ),
              ),
            )
          else
            for (var i = 0; i < links.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == links.length - 1 ? 0 : 8),
                child: _LinkEditRow(
                  link: links[i],
                  onTap: () => onEdit(i),
                  onRemove: () => onRemove(i),
                ),
              ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_link_rounded),
            label: const Text('リンクを追加'),
          ),
        ],
      ),
    );
  }
}

class _LinkEditRow extends StatelessWidget {
  const _LinkEditRow({
    required this.link,
    required this.onTap,
    required this.onRemove,
  });

  final TopicLink link;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  String get _displayLabel =>
      link.label.isNotEmpty ? link.label : _domain(link.url);

  static String _domain(String url) {
    final uri = Uri.tryParse(url);
    return uri?.host ?? url;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paleSky.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              const Icon(Icons.link_rounded,
                  size: 18, color: AppColors.triplaTealDark),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _displayLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.triplaTealDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (link.label.isNotEmpty)
                      Text(
                        link.url,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'このリンクを削除',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                color: AppColors.softGray,
                icon: const Icon(Icons.close_rounded),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
