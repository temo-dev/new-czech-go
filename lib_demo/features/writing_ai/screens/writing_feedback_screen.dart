import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/ai_teacher/models/ai_teacher_review.dart';
import 'package:app_czech/features/ai_teacher/providers/ai_teacher_review_provider.dart';
import 'package:app_czech/features/ai_teacher/widgets/ai_teacher_review_widgets.dart';
import 'package:app_czech/features/course/providers/course_providers.dart';
import 'package:app_czech/shared/models/question_model.dart';
import 'package:app_czech/shared/widgets/error_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Writing feedback screen — matches writing_ai_feedback.html Stitch design.
class WritingFeedbackScreen extends ConsumerWidget {
  const WritingFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final attemptId = extra?['attemptId'] as String?;
    final questionId = extra?['questionId'] as String? ?? '';
    final exerciseId = extra?['exerciseId'] as String? ?? '';
    final lessonId = extra?['lessonId'] as String? ?? '';
    final lessonBlockId = extra?['lessonBlockId'] as String? ?? '';
    final courseId = extra?['courseId'] as String? ?? '';
    final moduleId = extra?['moduleId'] as String? ?? '';
    final source = extra?['source'] as String? ??
        (lessonId.isNotEmpty ? 'lesson' : 'practice');

    if (attemptId == null) {
      return _buildShell(context, child: const _ScoringInProgress());
    }

    final request = AiTeacherReviewRequest(
      source: source,
      questionId: questionId,
      exerciseId: exerciseId.isNotEmpty ? exerciseId : null,
      lessonId: lessonId.isNotEmpty ? lessonId : null,
      aiAttemptId: attemptId,
      questionType: QuestionType.writing,
    );
    final reviewAsync = ref.watch(aiTeacherReviewEntryProvider(request));

    ref.listen(aiTeacherReviewEntryProvider(request), (_, next) {
      next.whenData((response) {
        if (response.isReady &&
            lessonId.isNotEmpty &&
            lessonBlockId.isNotEmpty &&
            courseId.isNotEmpty &&
            moduleId.isNotEmpty) {
          _syncLessonProgress(
            ref,
            courseId: courseId,
            moduleId: moduleId,
            lessonId: lessonId,
            lessonBlockId: lessonBlockId,
          );
        }
      });
    });

    return _buildShell(
      context,
      child: reviewAsync.when(
        loading: () => const _ScoringInProgress(),
        error: (_, __) => ErrorState(
          message: 'Không thể tải kết quả.',
          onRetry: () => ref.invalidate(aiTeacherReviewEntryProvider(request)),
        ),
        data: (response) {
          if (response.isPending) {
            return _ScoringInProgress(
              message: response.message,
            );
          }
          if (response.isError || response.review == null) {
            return ErrorState(
              message: response.message ?? 'Không thể tải kết quả.',
              onRetry: () =>
                  ref.invalidate(aiTeacherReviewEntryProvider(request)),
            );
          }
          return AiTeacherDetailView(
            review: response.review!,
            title: 'Kết quả Viết',
            subtitle:
                'AI Teacher đang chấm và chỉ ra lỗi trong bài viết của bạn.',
          );
        },
      ),
    );
  }

  Widget _buildShell(BuildContext context, {required Widget child}) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(
                color: AppColors.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.onBackground.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.primary,
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.dashboard);
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Kết quả Viết',
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.primary,
                      fontSize: 22,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
      body: child,
    );
  }
}

Future<void> _syncLessonProgress(
  WidgetRef ref, {
  required String courseId,
  required String moduleId,
  required String lessonId,
  required String lessonBlockId,
}) async {
  try {
    await markBlockComplete(
      lessonId: lessonId,
      lessonBlockId: lessonBlockId,
    );
    refreshCourseProgressProviders(
      ref,
      courseId: courseId,
      moduleId: moduleId,
      lessonId: lessonId,
    );
  } catch (error, stackTrace) {
    debugPrint('Failed to sync writing lesson progress: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class _ScoringInProgress extends StatelessWidget {
  const _ScoringInProgress({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Đang chấm điểm...',
              style: AppTypography.headlineSmall.copyWith(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message ?? 'AI đang phân tích bài viết của bạn.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
