import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/topic_repository.dart';
import '../../domain/entities/topic.dart';
import 'database_provider.dart';
import 'day_providers.dart';

final topicRepositoryProvider = Provider<TopicRepository>((ref) {
  return TopicRepository(ref.watch(databaseProvider));
});

/// 指定 Day 配下の Topic 群 Stream。Day タブを離れたら解放されるよう autoDispose。
final topicListProvider =
    StreamProvider.autoDispose.family<List<Topic>, String>((ref, dayId) {
  return ref.watch(topicRepositoryProvider).watchByDay(dayId);
});

/// 指定 ID の Topic 単体 Stream。編集画面で watch する。
/// 削除されると null を流す。画面を閉じたら解放されるよう autoDispose。
final topicByIdProvider =
    StreamProvider.autoDispose.family<Topic?, String>((ref, topicId) {
  return ref.watch(topicRepositoryProvider).watchById(topicId);
});

/// 指定 Trip 配下の全 Topic を 1 本の Stream で監視。
/// dayList が更新されると自動的に新しい dayIds で再購読される。
/// ダッシュボードのように「Day 数分の Stream を 1 つに集約したい」場面で使う。
final tripTopicsProvider = StreamProvider.autoDispose
    .family<List<Topic>, String>((ref, tripId) {
  final days = ref.watch(dayListProvider(tripId)).valueOrNull;
  if (days == null || days.isEmpty) return Stream.value(const []);
  final dayIds = days.map((d) => d.id).toList();
  return ref.watch(topicRepositoryProvider).watchByDayIds(dayIds);
});
