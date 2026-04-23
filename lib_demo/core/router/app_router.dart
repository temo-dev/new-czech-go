import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/router/guards/auth_guard.dart';
import 'package:app_czech/shared/providers/subscription_provider.dart';

import 'package:app_czech/features/shell/app_shell.dart';
import 'package:app_czech/features/landing/screens/landing_screen.dart';
import 'package:app_czech/features/auth/screens/login_screen.dart';
import 'package:app_czech/features/auth/screens/signup_screen.dart';
import 'package:app_czech/features/auth/screens/forgot_password_screen.dart';
import 'package:app_czech/features/dashboard/screens/dashboard_screen.dart';
import 'package:app_czech/features/course/screens/course_catalog_screen.dart';
import 'package:app_czech/features/course/screens/course_detail_screen.dart';
import 'package:app_czech/features/course/screens/module_detail_screen.dart';
import 'package:app_czech/features/course/screens/lesson_player_screen.dart';
import 'package:app_czech/features/exercise/screens/exercise_intro_screen.dart';
import 'package:app_czech/features/exercise/screens/exercise_question_screen.dart';
import 'package:app_czech/features/exercise/screens/exercise_explanation_screen.dart';
import 'package:app_czech/features/exercise/screens/practice_screen.dart';
import 'package:app_czech/features/simulator/screens/simulator_intro_screen.dart';
import 'package:app_czech/features/simulator/screens/simulator_question_screen.dart';
import 'package:app_czech/features/simulator/screens/simulator_result_screen.dart';
import 'package:app_czech/features/mock_test/screens/exam_catalog_screen.dart';
import 'package:app_czech/features/mock_test/screens/mock_test_intro_screen.dart';
import 'package:app_czech/features/mock_test/screens/mock_test_question_screen.dart';
import 'package:app_czech/features/mock_test/screens/mock_test_result_screen.dart';
import 'package:app_czech/features/mock_test/screens/mock_test_subjective_review_screen.dart';
import 'package:app_czech/features/speaking_ai/screens/speaking_prompt_screen.dart';
import 'package:app_czech/features/speaking_ai/screens/speaking_recording_screen.dart';
import 'package:app_czech/features/speaking_ai/screens/speaking_feedback_screen.dart';
import 'package:app_czech/features/writing_ai/screens/writing_prompt_screen.dart';
import 'package:app_czech/features/writing_ai/screens/writing_feedback_screen.dart';
import 'package:app_czech/features/leaderboard/screens/leaderboard_screen.dart';
import 'package:app_czech/features/progress/screens/progress_screen.dart';
import 'package:app_czech/features/notifications/screens/notifications_screen.dart';
import 'package:app_czech/features/teacher_feedback/screens/teacher_inbox_screen.dart';
import 'package:app_czech/features/teacher_feedback/screens/teacher_thread_screen.dart';
import 'package:app_czech/features/chat/screens/inbox_screen.dart';
import 'package:app_czech/features/chat/screens/chat_room_screen.dart';
import 'package:app_czech/features/profile/screens/profile_screen.dart';
import 'package:app_czech/features/profile/screens/settings_screen.dart';
import 'package:app_czech/features/course/screens/unlock_bonus_screen.dart';
import 'package:app_czech/shared/widgets/error_state.dart';

part 'app_router.g.dart';

/// RouterNotifier bridges Riverpod auth state → GoRouter's refreshListenable.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    // Re-evaluate routes whenever auth state changes
    ref.listen(subscriptionStatusProvider, (_, __) => notifyListeners());
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
}

@riverpod
GoRouter appRouter(Ref ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    errorBuilder: (context, state) => ErrorState(message: state.error?.message),
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuthenticated = session != null;
      final location = state.uri.toString();

      // Bootstrap redirect
      if (location == AppRoutes.splash) {
        if (!isAuthenticated) return AppRoutes.landing;
        // Check onboarding (handled inside dashboard redirect if needed)
        return AppRoutes.dashboard;
      }

      // Redirect authenticated users away from auth screens
      if (isAuthenticated &&
          (location.startsWith('/auth') || location == AppRoutes.landing)) {
        return AppRoutes.dashboard;
      }

      // Auth guard for /app/**
      if (location.startsWith('/app')) {
        return authGuard(state);
      }

      return null;
    },
    routes: [
      // ── Bootstrap ──────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SizedBox.shrink(), // handled by redirect
      ),

      // ── Public ─────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.landing,
        builder: (_, __) => const LandingScreen(),
      ),

      // ── Auth ───────────────────────────────────────────────────────────────
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.signup, builder: (_, __) => const SignupScreen()),
      GoRoute(
          path: AppRoutes.forgotPassword,
          builder: (_, __) => const ForgotPasswordScreen()),

      // ── Free mock test (no auth required) ─────────────────────────────────
      GoRoute(
        path: AppRoutes.mockTestIntro,
        builder: (_, state) => MockTestIntroScreen(
          examId: state.uri.queryParameters['examId'],
        ),
      ),
      GoRoute(
        path: AppRoutes.mockTestQuestion,
        builder: (_, state) => MockTestQuestionScreen(
          attemptId: state.pathParameters['attemptId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.mockTestResult,
        builder: (_, state) => MockTestResultScreen(
          attemptId: state.pathParameters['attemptId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.mockTestSubjectiveReview,
        builder: (_, state) => MockTestSubjectiveReviewScreen(
          attemptId: state.pathParameters['attemptId'] ?? '',
          questionId: state.pathParameters['questionId'] ?? '',
        ),
      ),

      // ── AI feedback — standalone (no shell nav bar; reachable from public
      //    routes like /mock-test/**  without triggering duplicate shell keys)
      GoRoute(
          path: AppRoutes.speakingFeedback,
          builder: (_, __) => const SpeakingFeedbackScreen()),
      GoRoute(
          path: AppRoutes.writingFeedback,
          builder: (_, __) => const WritingFeedbackScreen()),

      // ── Authenticated shell ─────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
              path: AppRoutes.dashboard,
              builder: (_, __) => const DashboardScreen()),

          // Courses
          GoRoute(
            path: AppRoutes.courses,
            builder: (_, __) => const CourseCatalogScreen(),
            routes: [
              GoRoute(
                path: ':courseId',
                builder: (_, state) => CourseDetailScreen(
                    courseId: state.pathParameters['courseId']!),
                routes: [
                  GoRoute(
                    path: 'modules/:moduleId',
                    builder: (_, state) => ModuleDetailScreen(
                      courseId: state.pathParameters['courseId']!,
                      moduleId: state.pathParameters['moduleId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'lessons/:lessonId',
                        builder: (_, state) => LessonPlayerScreen(
                          courseId: state.pathParameters['courseId']!,
                          moduleId: state.pathParameters['moduleId']!,
                          lessonId: state.pathParameters['lessonId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Exam catalog (Luyện đề tab)
          GoRoute(
            path: AppRoutes.examCatalog,
            builder: (_, __) => const ExamCatalogScreen(),
          ),

          // Single-exercise practice (from lesson player)
          GoRoute(
            path: AppRoutes.practiceExercise,
            builder: (_, state) {
              final exerciseId = state.pathParameters['exerciseId']!;
              final extra = state.extra as Map<String, dynamic>?;
              return PracticeScreen(
                exerciseId: exerciseId,
                lessonId: extra?['lessonId'] as String?,
                lessonBlockId: extra?['lessonBlockId'] as String?,
                courseId: extra?['courseId'] as String?,
                moduleId: extra?['moduleId'] as String?,
              );
            },
          ),

          // Exercise practice
          GoRoute(
              path: AppRoutes.practiceIntro,
              builder: (_, __) => const ExerciseIntroScreen()),
          GoRoute(
            path: AppRoutes.practiceQuestion,
            builder: (_, state) => ExerciseQuestionScreen(
              index: int.parse(state.pathParameters['index'] ?? '0'),
            ),
          ),
          GoRoute(
              path: AppRoutes.practiceExplanation,
              builder: (_, __) => const ExerciseExplanationScreen()),

          // Exam simulator (subscription-gated)
          GoRoute(
              path: AppRoutes.simulatorIntro,
              builder: (_, __) => const SimulatorIntroScreen()),
          GoRoute(
            path: AppRoutes.simulatorQuestion,
            builder: (_, state) => SimulatorQuestionScreen(
              index: int.parse(state.pathParameters['index'] ?? '0'),
            ),
          ),
          GoRoute(
              path: AppRoutes.simulatorResult,
              builder: (_, __) => const SimulatorResultScreen()),

          // Speaking AI (subscription-gated)
          GoRoute(
              path: AppRoutes.speakingPrompt,
              builder: (_, __) => const SpeakingPromptScreen()),
          GoRoute(
              path: AppRoutes.speakingRecording,
              builder: (_, __) => const SpeakingRecordingScreen()),

          // Writing AI (subscription-gated)
          GoRoute(
              path: AppRoutes.writingPrompt,
              builder: (_, __) => const WritingPromptScreen()),

          // Community & progress
          GoRoute(
              path: AppRoutes.leaderboard,
              builder: (_, __) => const LeaderboardScreen()),
          GoRoute(
              path: AppRoutes.progress,
              builder: (_, __) => const ProgressScreen()),
          GoRoute(
              path: AppRoutes.notifications,
              builder: (_, __) => const NotificationsScreen()),

          // Chat / DM
          GoRoute(
            path: AppRoutes.inbox,
            builder: (_, __) => const InboxScreen(),
            routes: [
              GoRoute(
                path: ':roomId',
                builder: (_, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return ChatRoomScreen(
                    roomId: state.pathParameters['roomId']!,
                    peerName: extra?['peerName'] as String?,
                    peerAvatarUrl: extra?['peerAvatarUrl'] as String?,
                  );
                },
              ),
            ],
          ),

          // Teacher feedback
          GoRoute(
              path: AppRoutes.teacherInbox,
              builder: (_, __) => const TeacherInboxScreen()),
          GoRoute(
            path: '/app/teacher/thread/:threadId',
            builder: (_, state) => TeacherThreadScreen(
              threadId: state.pathParameters['threadId']!,
            ),
          ),

          // Profile
          GoRoute(
              path: AppRoutes.profile,
              builder: (_, __) => const ProfileScreen()),
          GoRoute(
              path: AppRoutes.settings,
              builder: (_, __) => const SettingsScreen()),

          // Unlock bonus practice
          GoRoute(
            path: AppRoutes.unlockBonus,
            builder: (_, state) => UnlockBonusScreen(
              lessonId: state.pathParameters['lessonId']!,
            ),
          ),
        ],
      ),
    ],
  );
}
