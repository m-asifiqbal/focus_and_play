// All routes in one place. Tabs (Home, Insights, Settings) are a
// StatefulShellRoute; everything else is pushed on the root navigator above it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/game_id.dart';
import '../../domain/level_config.dart';
import '../../features/home/home_screen.dart';
import '../../features/insights/achievements_screen.dart';
import '../../features/insights/game_insights_screen.dart';
import '../../features/insights/insights_screen.dart';
import '../../features/island/island_screen.dart';
import '../../features/onboarding/onboarding_screens.dart';
import '../../features/onboarding/try_puzzle_screen.dart';
import '../../features/play/out_of_lives_screen.dart';
import '../../features/play/play_screen.dart';
import '../../features/results/ad_break_screen.dart';
import '../../features/results/result_screen.dart';
import '../../features/results/tier_complete_screen.dart';
import '../../features/settings/backup_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/shell/splash_screen.dart';
import '../../state/save_controller.dart';

abstract final class Routes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const tryPuzzle = '/onboarding/try';
  static const pickIsland = '/onboarding/island';
  static const profile = '/onboarding/profile';
  static const home = '/home';
  static const insights = '/insights';
  static const settings = '/settings';
  static const result = '/result';
  static const tier = '/tier';
  static const outOfLives = '/out-of-lives';
  static const adBreak = '/ad-break';
  static const achievements = '/achievements';
  static const backup = '/backup';

  static String island(GameId g) => '/island/${g.key}';
  static String play(GameId g, int level) => '/play/${g.key}/$level';
  static String daily() => '/play/daily/0';
  static String gameInsights(GameId g) => '/insights/${g.key}';
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Where the app opens (tests start on a specific screen).
final initialRouteProvider = Provider<String>((ref) => Routes.splash);

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: ref.read(initialRouteProvider),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: Routes.tryPuzzle, builder: (_, _) => const TryPuzzleScreen()),
      GoRoute(path: Routes.pickIsland, builder: (_, _) => const PickIslandScreen()),
      GoRoute(path: Routes.profile, builder: (_, _) => const ProfileSetupScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.insights, builder: (_, _) => const InsightsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen())]),
        ],
      ),
      GoRoute(
        path: '/island/:game',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => IslandScreen(game: GameId.fromKey(s.pathParameters['game']!)),
      ),
      GoRoute(
        path: '/play/:game/:level',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, s) {
          final level = int.tryParse(s.pathParameters['level'] ?? '') ?? 1;
          final spec = s.pathParameters['game'] == 'daily'
              ? LevelConfig.daily(ref.read(clockProvider)())
              : LevelConfig.forLevel(GameId.fromKey(s.pathParameters['game']!), level.clamp(1, 60));
          return PlayScreen(spec: spec, key: ValueKey('${spec.game.key}-${spec.level}-${spec.dayKey}'));
        },
      ),
      GoRoute(path: Routes.result, parentNavigatorKey: rootNavigatorKey, builder: (_, s) => ResultScreen(outcome: s.extra! as LevelOutcome)),
      GoRoute(path: Routes.tier, parentNavigatorKey: rootNavigatorKey, builder: (_, s) => TierCompleteScreen(outcome: s.extra! as LevelOutcome)),
      GoRoute(path: Routes.outOfLives, parentNavigatorKey: rootNavigatorKey, builder: (_, s) => OutOfLivesScreen(spec: s.extra as LevelSpec?)),
      GoRoute(path: Routes.adBreak, parentNavigatorKey: rootNavigatorKey, builder: (_, s) => AdBreakScreen(next: s.extra! as String)),
      GoRoute(path: '/insights/:game', parentNavigatorKey: rootNavigatorKey, builder: (_, s) => GameInsightsScreen(game: GameId.fromKey(s.pathParameters['game']!))),
      GoRoute(path: Routes.achievements, parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const AchievementsScreen()),
      GoRoute(path: Routes.backup, parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const BackupScreen()),
    ],
  );
});
