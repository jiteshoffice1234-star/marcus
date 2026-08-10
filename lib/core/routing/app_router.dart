import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai_tutor/presentation/ai_tutor_screen.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/exams/presentation/test_runner_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/learn/presentation/chapter_screen.dart';
import '../../features/learn/presentation/learn_home_screen.dart';
import '../../features/learn/presentation/level_screen.dart';
import '../../features/learn/presentation/topic_screen.dart';
import '../../features/onboarding/presentation/onboarding_flow.dart';
import '../../features/practice/presentation/practice_home_screen.dart';
import '../../features/practice/presentation/question_player_screen.dart';
import '../../features/profile/presentation/achievements_screen.dart';
import '../../features/profile/presentation/bookmarks_screen.dart';
import '../../features/profile/presentation/notes_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/reference/presentation/reference_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/simulator/presentation/simulator_detail_screen.dart';
import '../../features/simulator/presentation/simulator_home_screen.dart';
import '../../shared/widgets/app_shell.dart';
import '../providers/providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: ref.watch(routerRefreshListenableProvider),
    redirect: (context, state) {
      final learner = ref.read(learnerStateProvider).valueOrNull;
      if (learner == null) return null; // still bootstrapping
      final location = state.uri.path;
      if (!learner.profile.onboarded) {
        return location == '/onboarding' ? null : '/onboarding';
      }
      if (location == '/onboarding' || location == '/auth') return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingFlow(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/learn',
              builder: (context, state) => const LearnHomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/practice',
              builder: (context, state) => const PracticeHomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/simulator',
              builder: (context, state) => const SimulatorHomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ]),
        ],
      ),
      // Full-screen detail routes (pushed on the root navigator).
      GoRoute(
        path: '/learn/level/:levelId',
        builder: (context, state) =>
            LevelScreen(levelId: state.pathParameters['levelId']!),
      ),
      GoRoute(
        path: '/learn/chapter/:chapterId',
        builder: (context, state) =>
            ChapterScreen(chapterId: state.pathParameters['chapterId']!),
      ),
      GoRoute(
        path: '/learn/topic/:topicId',
        builder: (context, state) =>
            TopicScreen(topicId: state.pathParameters['topicId']!),
      ),
      GoRoute(
        path: '/practice/player',
        builder: (context, state) => QuestionPlayerScreen(
          topicId: state.uri.queryParameters['topicId'],
          mode: state.uri.queryParameters['mode'] ?? 'quick',
          count: int.tryParse(state.uri.queryParameters['count'] ?? '') ?? 10,
          sourceTestId: state.uri.queryParameters['testId'],
        ),
      ),
      GoRoute(
        path: '/test/:testId',
        builder: (context, state) =>
            TestRunnerScreen(testId: state.pathParameters['testId']!),
      ),
      GoRoute(
        path: '/simulator/:simId',
        builder: (context, state) =>
            SimulatorDetailScreen(simId: state.pathParameters['simId']!),
      ),
      GoRoute(
        path: '/ai-tutor',
        builder: (context, state) => AiTutorScreen(
          topicId: state.uri.queryParameters['topicId'],
          questionId: state.uri.queryParameters['questionId'],
        ),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/reference',
        builder: (context, state) => const ReferenceScreen(),
      ),
      GoRoute(
        path: '/notes',
        builder: (context, state) => const NotesScreen(),
      ),
      GoRoute(
        path: '/bookmarks',
        builder: (context, state) => const BookmarksScreen(),
      ),
      GoRoute(
        path: '/achievements',
        builder: (context, state) => const AchievementsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
