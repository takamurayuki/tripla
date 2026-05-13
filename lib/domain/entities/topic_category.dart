import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 要件定義書 §6.1 TopicCategory。
enum TopicCategory {
  transport('移動', Icons.directions_bus_rounded, AppColors.skyBlue),
  sightseeing('観光', Icons.photo_camera_rounded, AppColors.bandanaGreen),
  meal('食事', Icons.restaurant_rounded, AppColors.tritaYellow),
  lodging('宿泊', Icons.hotel_rounded, AppColors.deepNavy),
  shopping('買い物', Icons.shopping_bag_rounded, AppColors.coralRed),
  other('その他', Icons.bookmark_outline_rounded, AppColors.softGray);

  const TopicCategory(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}
