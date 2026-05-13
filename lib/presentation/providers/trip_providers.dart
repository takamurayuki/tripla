import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/trip_repository.dart';
import '../../domain/entities/trip.dart';
import 'database_provider.dart';

/// 認証未実装のため Phase 1 中は固定の擬似ユーザー ID を使う。
/// Phase 2 で Supabase Auth 導入時に AuthProvider から取得するよう差し替え。
const String kLocalOwnerId = 'local-user';

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(ref.watch(databaseProvider));
});

/// 全旅程の Stream。HomeScreen で watch する。
final tripListProvider = StreamProvider<List<Trip>>((ref) {
  return ref.watch(tripRepositoryProvider).watchAll();
});
