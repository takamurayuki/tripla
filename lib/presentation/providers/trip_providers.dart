import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/trip_repository.dart';
import '../../domain/entities/trip.dart';
import 'database_provider.dart';

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(ref.watch(databaseProvider));
});

/// 全旅程の Stream。HomeScreen で常時 watch するので autoDispose しない。
final tripListProvider = StreamProvider<List<Trip>>((ref) {
  return ref.watch(tripRepositoryProvider).watchAll();
});

/// 単一 Trip の Stream。詳細画面で watch する。
/// 詳細画面を閉じたら購読解除されるよう autoDispose。
final tripByIdProvider =
    StreamProvider.autoDispose.family<Trip?, String>((ref, tripId) {
  return ref.watch(tripRepositoryProvider).watchById(tripId);
});
