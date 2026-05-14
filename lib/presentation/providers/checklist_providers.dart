import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/checklist_repository.dart';
import '../../domain/entities/checklist_item.dart';
import 'database_provider.dart';

final checklistRepositoryProvider = Provider<ChecklistRepository>((ref) {
  return ChecklistRepository(ref.watch(databaseProvider));
});

/// 詳細画面を閉じたら解放されるよう autoDispose。
final checklistItemsProvider =
    StreamProvider.autoDispose.family<List<ChecklistItem>, String>(
        (ref, tripId) {
  return ref.watch(checklistRepositoryProvider).watchByTrip(tripId);
});
