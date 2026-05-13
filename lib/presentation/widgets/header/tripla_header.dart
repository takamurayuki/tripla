import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 要件定義書 §F-007 ヘッダ固定メニュー。
/// スクロール時も常時表示される AppBar として実装する。
class TriplaHeader extends StatelessWidget implements PreferredSizeWidget {
  const TriplaHeader({
    super.key,
    this.title = 'トリプラ',
    this.leading,
    this.showNotification = true,
    this.showProfile = true,
    this.onTapNotification,
    this.onTapProfile,
    this.actions,
  });

  final String title;
  final Widget? leading;
  final bool showNotification;
  final bool showProfile;
  final VoidCallback? onTapNotification;
  final VoidCallback? onTapProfile;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading,
      title: Text(title),
      actions: [
        if (actions != null) ...actions!,
        if (showNotification)
          IconButton(
            tooltip: '通知',
            onPressed: onTapNotification,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        if (showProfile)
          IconButton(
            tooltip: 'プロフィール',
            onPressed: onTapProfile,
            icon: const Icon(Icons.account_circle_outlined),
          ),
        const SizedBox(width: 4),
      ],
      backgroundColor: AppColors.paleSky,
      surfaceTintColor: Colors.transparent,
    );
  }
}
