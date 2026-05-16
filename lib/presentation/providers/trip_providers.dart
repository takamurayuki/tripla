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

/// マイスケジュール (mode=schedule singleton) の Stream。 未作成なら null。
/// ownerId はホーム画面の currentUserIdProvider 値を渡す想定。
final scheduleTripProvider =
    StreamProvider.autoDispose.family<Trip?, String>((ref, ownerId) {
  return ref.watch(tripRepositoryProvider).watchSchedule(ownerId);
});
