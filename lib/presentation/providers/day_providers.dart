import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/day_repository.dart';
import '../../domain/entities/day.dart';
import 'database_provider.dart';

final dayRepositoryProvider = Provider<DayRepository>((ref) {
  return DayRepository(ref.watch(databaseProvider));
});

/// 指定 Trip 配下の Day 群 Stream。詳細画面で watch する。
/// 詳細画面を閉じたら購読解除されるよう autoDispose。
final dayListProvider =
    StreamProvider.autoDispose.family<List<Day>, String>((ref, tripId) {
  return ref.watch(dayRepositoryProvider).watchByTrip(tripId);
});
