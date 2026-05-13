import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/features/home/home_screen.dart';
import '../../presentation/features/splash/splash_screen.dart';
import '../../presentation/features/trip_create/trip_create_screen.dart';

/// アプリ全体のルーティング。Phase 1 マイルストーン 1 では
/// splash / home / 旅程作成 までを提供する。
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
    ],
  );
});
