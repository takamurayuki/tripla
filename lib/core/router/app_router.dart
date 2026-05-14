import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/features/home/home_screen.dart';
import '../../presentation/features/splash/splash_screen.dart';
import '../../presentation/features/topic_edit/topic_edit_screen.dart';
import '../../presentation/features/trip_create/trip_create_screen.dart';
import '../../presentation/features/trip_detail/trip_detail_screen.dart';

/// アプリ全体のルーティング。
///
/// Phase 1 マイルストーン 1.3 までで提供するルート:
/// /splash, /home, /trips/new, /trips/:tripId, /trips/:tripId/topics/:topicId
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/trips/new',
        name: 'tripCreate',
        builder: (context, state) => const TripCreateScreen(),
      ),
      GoRoute(
        path: '/trips/:tripId',
        name: 'tripDetail',
        builder: (context, state) {
          final id = state.pathParameters['tripId']!;
          return TripDetailScreen(tripId: id);
        },
        routes: [
          GoRoute(
            path: 'topics/:topicId',
            name: 'topicEdit',
            builder: (context, state) {
              final topicId = state.pathParameters['topicId']!;
              return TopicEditScreen(topicId: topicId);
            },
          ),
        ],
      ),
    ],
  );
});
