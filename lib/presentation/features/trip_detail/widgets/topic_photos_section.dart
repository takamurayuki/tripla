import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../providers/photo_storage_provider.dart';

/// 予定編集シートの「写真」セクション。
///
/// - 横スクロールのサムネイル一覧 + 各サムネイル右上の × で削除
/// - 末尾の「+」 タイルから「カメラ / ギャラリー」 を選択して追加
///
/// 画像のロード / 保存は親 ([topic_editor_sheet.dart]) 側で行い、 ここは表示と
/// イベント発火のみ責務にする。
class TopicPhotosSection extends ConsumerWidget {
  const TopicPhotosSection({
    super.key,
    required this.photos,
    required this.onAddFromCamera,
    required this.onAddFromGallery,
    required this.onRemove,
  });

  /// アプリ docs からの相対パス。
  final List<String> photos;
  final VoidCallback onAddFromCamera;
  final VoidCallback onAddFromGallery;
  final ValueChanged<int> onRemove;

  void _onTapAdd(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('カメラで撮影'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onAddFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('ギャラリーから選択'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onAddFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(photoStorageProvider);
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
              const Icon(Icons.photo_camera_rounded,
                  size: 18, color: AppColors.triplaTeal),
              const SizedBox(width: 6),
              Text(
                '写真',
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
                  '${photos.length}',
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
            storage.isSupported
                ? 'この予定にまつわる写真を残しておこう。'
                : 'このプラットフォームでは写真の保存に未対応です。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length + (storage.isSupported ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == photos.length) {
                  return _AddTile(onTap: () => _onTapAdd(context));
                }
                return _PhotoTile(
                  relativePath: photos[index],
                  onRemove: () => onRemove(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paleSky.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 80,
          height: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_a_photo_rounded,
                  color: AppColors.triplaTeal, size: 22),
              const SizedBox(height: 4),
              const Text(
                '写真を追加',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.triplaTealDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends ConsumerWidget {
  const _PhotoTile({required this.relativePath, required this.onRemove});

  final String relativePath;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(photoStorageProvider);
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: FutureBuilder(
              future: storage.resolveAbsolute(relativePath),
              builder: (context, snapshot) {
                final file = snapshot.data;
                if (file == null) {
                  return Container(color: AppColors.softGray.withValues(alpha: 0.2));
                }
                return Image.file(
                  file,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.softGray.withValues(alpha: 0.2),
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_rounded,
                        size: 24, color: AppColors.softGray),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.black.withValues(alpha: 0.4),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: Icon(Icons.close_rounded,
                      size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
