import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/enums/game_type.dart';
import '../../presentation/dashboard/dashboard_screen.dart';
import '../../presentation/games/schulte_grid/schulte_grid_screen.dart';
import '../../presentation/games/reaction_time/reaction_time_screen.dart';
import '../../presentation/games/number_memory/number_memory_screen.dart';
import '../../presentation/games/stroop_test/stroop_test_screen.dart';
import '../../presentation/games/visual_memory/visual_memory_screen.dart';
import '../../presentation/games/sequence_memory/sequence_memory_screen.dart';
import '../../presentation/games/number_matrix/number_matrix_screen.dart';
import '../../presentation/games/reverse_memory/reverse_memory_screen.dart';
import '../../presentation/games/sliding_puzzle/sliding_puzzle_screen.dart';
import '../../presentation/games/tower_of_hanoi/tower_of_hanoi_screen.dart';
import '../../presentation/result/result_screen.dart';
import '../../presentation/analytics/analytics_screen.dart';
import '../../presentation/settings/settings_screen.dart';

abstract final class AppRoutes {
  static const dashboard = '/';
  static const analytics = '/analytics';
  static const settings = '/settings';
  static const result = '/result';

  // Game routes
  static const schulteGrid = '/game/schulte-grid';
  static const reactionTime = '/game/reaction-time';
  static const numberMemory = '/game/number-memory';
  static const stroopTest = '/game/stroop-test';
  static const visualMemory = '/game/visual-memory';
  static const sequenceMemory = '/game/sequence-memory';
  static const numberMatrix = '/game/number-matrix';
  static const reverseMemory = '/game/reverse-memory';
  static const slidingPuzzle = '/game/sliding-puzzle';
  static const towerOfHanoi = '/game/tower-of-hanoi';

  static String gameRoute(GameType type) => switch (type) {
    GameType.schulteGrid => schulteGrid,
    GameType.reactionTime => reactionTime,
    GameType.numberMemory => numberMemory,
    GameType.stroopTest => stroopTest,
    GameType.visualMemory => visualMemory,
    GameType.sequenceMemory => sequenceMemory,
    GameType.numberMatrix => numberMatrix,
    GameType.reverseMemory => reverseMemory,
    GameType.slidingPuzzle => slidingPuzzle,
    GameType.towerOfHanoi => towerOfHanoi,
  };
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.dashboard,
  debugLogDiagnostics: false,
  routes: [
    GoRoute(
      path: AppRoutes.dashboard,
      pageBuilder: (ctx, state) => _slidePage(const DashboardScreen()),
    ),
    GoRoute(
      path: AppRoutes.analytics,
      pageBuilder: (ctx, state) => _slidePage(const AnalyticsScreen()),
    ),
    GoRoute(
      path: AppRoutes.settings,
      pageBuilder: (ctx, state) => _slidePage(const SettingsScreen()),
    ),
    GoRoute(
      path: AppRoutes.result,
      pageBuilder: (ctx, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return _slidePage(ResultScreen(data: extra ?? {}));
      },
    ),
    // ─── Game Routes ──────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.schulteGrid,
      pageBuilder: (ctx, state) => _slidePage(const SchulteGridScreen()),
    ),
    GoRoute(
      path: AppRoutes.reactionTime,
      pageBuilder: (ctx, state) => _slidePage(const ReactionTimeScreen()),
    ),
    GoRoute(
      path: AppRoutes.numberMemory,
      pageBuilder: (ctx, state) => _slidePage(const NumberMemoryScreen()),
    ),
    GoRoute(
      path: AppRoutes.stroopTest,
      pageBuilder: (ctx, state) => _slidePage(const StroopTestScreen()),
    ),
    GoRoute(
      path: AppRoutes.visualMemory,
      pageBuilder: (ctx, state) => _slidePage(const VisualMemoryScreen()),
    ),
    GoRoute(
      path: AppRoutes.sequenceMemory,
      pageBuilder: (ctx, state) => _slidePage(const SequenceMemoryScreen()),
    ),
    GoRoute(
      path: AppRoutes.numberMatrix,
      pageBuilder: (ctx, state) => _slidePage(const NumberMatrixScreen()),
    ),
    GoRoute(
      path: AppRoutes.reverseMemory,
      pageBuilder: (ctx, state) => _slidePage(const ReverseMemoryScreen()),
    ),
    GoRoute(
      path: AppRoutes.slidingPuzzle,
      pageBuilder: (ctx, state) => _slidePage(const SlidingPuzzleScreen()),
    ),
    GoRoute(
      path: AppRoutes.towerOfHanoi,
      pageBuilder: (ctx, state) => _slidePage(const TowerOfHanoiScreen()),
    ),
  ],
);

/// Direction-aware slide page transition:
/// LTR: new page slides in from right (pushes old to left)
/// RTL: new page slides in from left (pushes old to right)
CustomTransitionPage<void> _slidePage(Widget child) =>
    CustomTransitionPage<void>(
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final isRtl = Directionality.of(context) == TextDirection.rtl;
        // LTR: slide from right (1, 0); RTL: slide from left (-1, 0)
        final begin = Offset(isRtl ? -1.0 : 1.0, 0.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: Curves.easeInOutCubic),
        );
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 280),
    );
