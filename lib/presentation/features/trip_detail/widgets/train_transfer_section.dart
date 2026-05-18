import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/train_transfer.dart';
import '../../../widgets/common/clearable_input.dart';

/// 移動 (電車) 用の乗換情報セクション。
///
/// - 乗換駅 / 路線 / ホーム番号 / 乗換時間 (分) / メモ を順番に追加
/// - ドラッグで並び替え可能、 行末の × で削除
///
/// 保存ボタンで Topic に反映 (このセクション自体は in-memory リスト操作のみ)。
class TrainTransferSection extends StatelessWidget {
  const TrainTransferSection({
    super.key,
    required this.transfers,
    required this.onChanged,
  });

  final List<TrainTransfer> transfers;
  final ValueChanged<List<TrainTransfer>> onChanged;

  Future<void> _onAdd(BuildContext context) async {
    final added = await _showTransferDialog(context: context);
    if (added != null) {
      onChanged([...transfers, added]);
    }
  }

  Future<void> _onEdit(BuildContext context, int index) async {
    final updated =
        await _showTransferDialog(context: context, existing: transfers[index]);
    if (updated != null) {
      final next = [...transfers];
      next[index] = updated;
      onChanged(next);
    }
  }

  void _onRemove(int index) {
    final next = [...transfers]..removeAt(index);
    onChanged(next);
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final next = [...transfers];
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    onChanged(next);
  }

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
                '乗換情報',
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
                  '${transfers.length}',
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
            '駅・路線・ホーム番号・乗換時間 を順番に登録できます。 ドラッグで並び替え可。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (transfers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'まだ乗換情報はありません',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.softGray,
                    ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: transfers.length,
              onReorder: _onReorder,
              proxyDecorator: (child, _, _) => Material(
                color: Colors.transparent,
                elevation: 4,
                shadowColor: AppColors.triplaTeal.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                child: child,
              ),
              itemBuilder: (context, i) {
                final t = transfers[i];
                return Padding(
                  key: ValueKey('transfer-${t.id}'),
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _TransferRow(
                    index: i,
                    transfer: t,
                    onTap: () => _onEdit(context, i),
                    onRemove: () => _onRemove(i),
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _onAdd(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('乗換を追加'),
          ),
        ],
      ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({
    required this.index,
    required this.transfer,
    required this.onTap,
    required this.onRemove,
  });

  final int index;
  final TrainTransfer transfer;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  String _summary() {
    final parts = <String>[
      ?transfer.line,
      if (transfer.platform != null && transfer.platform!.isNotEmpty)
        '${transfer.platform!} 番線',
      if (transfer.transferMinutes != null)
        '乗換 ${transfer.transferMinutes!} 分',
      ?transfer.note,
    ];
    return parts.isEmpty ? '' : parts.join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary();
    return Material(
      color: AppColors.paleSky.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_indicator_rounded,
                    size: 18, color: AppColors.softGray),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.train_rounded,
                  size: 18, color: AppColors.triplaTealDark),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      transfer.station,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.triplaTealDark,
                      ),
                    ),
                    if (summary.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          summary,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'この乗換を削除',
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

/// 乗換情報の追加 / 編集ダイアログ。
Future<TrainTransfer?> _showTransferDialog({
  required BuildContext context,
  TrainTransfer? existing,
}) async {
  final stationCtl = TextEditingController(text: existing?.station ?? '');
  final lineCtl = TextEditingController(text: existing?.line ?? '');
  final platformCtl = TextEditingController(text: existing?.platform ?? '');
  final minutesCtl = TextEditingController(
    text: existing?.transferMinutes?.toString() ?? '',
  );
  final noteCtl = TextEditingController(text: existing?.note ?? '');
  const uuid = Uuid();

  try {
    return await showDialog<TrainTransfer>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(existing == null ? '乗換を追加' : '乗換を編集'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: stationCtl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '乗換駅',
                    hintText: '例: 品川',
                    suffixIcon: clearSuffixFor(stationCtl),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lineCtl,
                  decoration: InputDecoration(
                    labelText: '路線 / 列車 (任意)',
                    hintText: '例: JR山手線 / のぞみ 21 号',
                    suffixIcon: clearSuffixFor(lineCtl),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: platformCtl,
                        decoration: InputDecoration(
                          labelText: 'ホーム (任意)',
                          hintText: '例: 3',
                          suffixIcon: clearSuffixFor(platformCtl),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: minutesCtl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '乗換 (分, 任意)',
                          hintText: '例: 5',
                          suffixIcon: clearSuffixFor(minutesCtl),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtl,
                  decoration: InputDecoration(
                    labelText: 'メモ (任意)',
                    hintText: '例: 中央改札を経由',
                    suffixIcon: clearSuffixFor(noteCtl),
                  ),
                  maxLines: 2,
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
                final station = stationCtl.text.trim();
                if (station.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('乗換駅を入力してください')),
                  );
                  return;
                }
                final minutesText = minutesCtl.text.trim();
                int? minutes;
                if (minutesText.isNotEmpty) {
                  minutes = int.tryParse(minutesText);
                  if (minutes == null || minutes < 0) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('乗換時間は 0 以上の数字を入力してください')),
                    );
                    return;
                  }
                }
                final line = lineCtl.text.trim();
                final platform = platformCtl.text.trim();
                final note = noteCtl.text.trim();
                Navigator.of(dialogContext).pop(TrainTransfer(
                  id: existing?.id ?? uuid.v4(),
                  station: station,
                  line: line.isEmpty ? null : line,
                  platform: platform.isEmpty ? null : platform,
                  transferMinutes: minutes,
                  note: note.isEmpty ? null : note,
                ));
              },
              child: Text(existing == null ? '追加' : '保存'),
            ),
          ],
        );
      },
    );
  } finally {
    stationCtl.dispose();
    lineCtl.dispose();
    platformCtl.dispose();
    minutesCtl.dispose();
    noteCtl.dispose();
  }
}
