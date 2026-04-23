import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/ai_teacher/models/ai_teacher_review.dart';
import 'package:app_czech/features/ai_teacher/widgets/ai_teacher_review_widgets.dart';
import 'package:app_czech/features/mock_test/models/exam_analysis.dart';
import 'package:app_czech/features/mock_test/providers/exam_analysis_provider.dart';
import 'package:app_czech/shared/widgets/error_state.dart';
import 'package:app_czech/shared/widgets/loading_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MockTestSubjectiveReviewScreen extends ConsumerWidget {
  const MockTestSubjectiveReviewScreen({
    super.key,
    required this.attemptId,
    required this.questionId,
  });

  final String attemptId;
  final String questionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysisAsync = ref.watch(examAnalysisProvider(attemptId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Nhận xét chi tiết'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.mockTestResultPath(attemptId));
            }
          },
        ),
      ),
      body: analysisAsync.when(
        loading: () => const _ReviewSkeleton(),
        error: (_, __) => ErrorState(
          message: 'Không thể tải nhận xét chi tiết của bài thi.',
          onRetry: () => ref.invalidate(examAnalysisProvider(attemptId)),
        ),
        data: (analysis) => _ReviewBody(
          attemptId: attemptId,
          questionId: questionId,
          analysis: analysis,
        ),
      ),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({
    required this.attemptId,
    required this.questionId,
    required this.analysis,
  });

  final String attemptId;
  final String questionId;
  final ExamAnalysis? analysis;

  @override
  Widget build(BuildContext context) {
    if (analysis == null || analysis!.isProcessing) {
      return const _ExamReviewPendingState();
    }

    if (analysis!.isError) {
      return ErrorState(
        message: analysis!.errorMessage ?? 'Không thể hoàn tất chấm bài thi.',
        onRetry: () => context.go(AppRoutes.mockTestResultPath(attemptId)),
      );
    }

    final review = analysis!.teacherReviewForQuestion(questionId);
    if (review == null) {
      return const ErrorState(
        message: 'Nhận xét chi tiết cho câu này chưa sẵn sàng.',
      );
    }

    return AiTeacherDetailView(
      review: review,
      title: _titleForReview(review),
      subtitle:
          'AI Teacher đã chấm toàn bộ bài thi và tổng hợp nhận xét chi tiết cho câu này.',
    );
  }

  String _titleForReview(AiTeacherReview review) {
    return switch (review.modality) {
      AiTeacherReviewModality.speaking => 'Kết quả Nói',
      AiTeacherReviewModality.writing => 'Kết quả Viết',
      AiTeacherReviewModality.objective => 'Nhận xét chi tiết',
    };
  }
}

class _ExamReviewPendingState extends StatelessWidget {
  const _ExamReviewPendingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: AppSpacing.x4),
            const Text(
              'AI đang chấm toàn bộ bài thi',
              style: AppTypography.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              'Nhận xét chi tiết sẽ xuất hiện ở đây ngay khi phần speaking/writing được materialize vào kết quả bài thi.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewSkeleton extends StatelessWidget {
  const _ReviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return LoadingShimmer(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(
            5,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x4),
              child: Container(
                height: index == 0 ? 96 : 128,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
