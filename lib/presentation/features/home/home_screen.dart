import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/trip.dart';
import '../../providers/trip_providers.dart';
import '../../widgets/header/tripla_header.dart';
import '../../widgets/trita/trita_speech_bubble.dart';
import '../../widgets/trita/trita_state.dart';
import '../../widgets/trita/trita_widget.dart';
import 'widgets/trip_card.dart';

/// S-03 ホーム画面。
///
/// 旅程一覧をローカル DB から監視 (StreamProvider) し、空状態と一覧を切り替える。
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripListProvider);

    return Scaffold(
      appBar: const TriplaHeader(),
      body: tripsAsync.when(
        loading: () => const _HomeLoading(),
        error: (error, _) => _HomeError(message: '$error'),
        data: (trips) =>
            trips.isEmpty ? const _HomeEmptyState() : _HomeTripList(trips: trips),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/trips/new'),
        icon: const Icon(Icons.add),
        label: const Text('新規作成'),
      ),
    );
  }
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TritaWidget(state: TritaState.thinking, size: 160),
          SizedBox(height: 16),
          TritaSpeechBubble(message: '少し待ってね...'),
        ],
      ),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const TritaWidget(state: TritaState.thinking, size: 160),
            const SizedBox(height: 16),
            const TritaSpeechBubble(message: 'うまく読み込めなかった...'),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const TritaWidget(state: TritaState.holdCamera, size: 200),
            const SizedBox(height: 16),
            const TritaSpeechBubble(message: '次の旅行はどこ？'),
            const SizedBox(height: 32),
            Text(
              'まだ旅程がありません',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '「新規作成」から最初の旅をはじめよう',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.softGray,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTripList extends StatelessWidget {
  const _HomeTripList({required this.trips});

  final List<Trip> trips;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: trips.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final trip = trips[index];
        return TripCard(
          trip: trip,
          onTap: () {
            // 旅程詳細はマイルストーン 1.2 で実装予定。
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${trip.title} の詳細画面は次のマイルストーンで実装予定'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        );
      },
    );
  }
}
