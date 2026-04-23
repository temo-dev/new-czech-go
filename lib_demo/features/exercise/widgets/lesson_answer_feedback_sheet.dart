import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/shared/models/question_model.dart';
import 'package:app_czech/features/exercise/providers/lesson_feedback_provider.dart';

/// Bottom sheet displayed after a wrong answer in lesson flow.
/// Shows AI error analysis, explanation, and improvement tip.
class LessonAnswerFeedbackSheet extends ConsumerWidget {
  const LessonAnswerFeedbackSheet({
    super.key,
    required this.params,
    required this.onContinue,
  });

  final LessonFeedbackParams params;
  final VoidCallback onContinue;

  static Future<void> show(
    BuildContext context, {
    required WidgetRef ref,
    required Question question,
    required String userAnswerText,
    required String correctAnswerText,
    required VoidCallback onContinue,
  }) async {
    final isObjective = question.type == QuestionType.mcq ||
        question.type == QuestionType.fillBlank;
    if (!isObjective) {
      onContinue();
      return;
    }

    final params = LessonFeedbackParams(
      questionId: question.id,
      questionText: question.prompt,
      questionType: question.type,
      options: question.options,
      correctAnswerText: correctAnswerText,
      userAnswerText: userAnswerText,
      sectionSkill: question.skill.name,
    );

    // Pre-warm the provider before showing the sheet
    ref.read(lessonQuestionFeedbackProvider(params).future).ignore();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LessonAnswerFeedbackSheet(
        params: params,
        onContinue: onContinue,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackAsync = ref.watch(lessonQuestionFeedbackProvider(params));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.x5,
        right: AppSpacing.x5,
        top: AppSpacing.x4,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.x6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x4),

          // Header
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: AppSpacing.x2),
              Text(
                'Phân tích AI',
                style: AppTypography.titleSmall
                    .copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),

          // Feedback content
          feedbackAsync.when(
            loading: () => const _LoadingState(),
            error: (_, __) => const _ErrorState(),
            data: (feedback) => feedback == null
                ? const _ErrorState()
                : _FeedbackContent(feedback: feedback),
          ),

          const SizedBox(height: AppSpacing.x5),

          // Continue button
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onContinue();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl)),
            ),
            child: Text(
              'Tiếp tục',
              style: AppTypography.labelMedium
                  .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.x3),
          Text('AI đang phân tích...',
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Không thể tải phân tích AI. Hãy tiếp tục bài học.',
      style: AppTypography.bodySmall
          .copyWith(color: AppColors.onSurfaceVariant),
    );
  }
}

class _FeedbackContent extends StatelessWidget {
  const _FeedbackContent({required this.feedback});
  final QuestionAiFeedback feedback;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (feedback.errorAnalysis.isNotEmpty) ...[
          _FeedbackRow(
            icon: Icons.cancel_outlined,
            color: AppColors.error,
            label: 'Tại sao sai:',
            text: feedback.errorAnalysis,
          ),
          const SizedBox(height: AppSpacing.x3),
        ],
        if (feedback.correctExplanation.isNotEmpty) ...[
          _FeedbackRow(
            icon: Icons.check_circle_outline,
            color: const Color(0xFF059669),
            label: 'Đáp án đúng vì:',
            text: feedback.correctExplanation,
          ),
          const SizedBox(height: AppSpacing.x3),
        ],
        if (feedback.shortTip.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.x3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡 ', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Text(
                    feedback.shortTip,
                    style: AppTypography.bodySmall.copyWith(
                      color: const Color(0xFF7B5E00),
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (feedback.keyConceptLabel.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x2),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x3, vertical: AppSpacing.x1),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.25)),
              ),
              child: Text(
                feedback.keyConceptLabel,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FeedbackRow extends StatelessWidget {
  const _FeedbackRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: AppSpacing.x2),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTypography.bodySmall.copyWith(height: 1.5),
              children: [
                TextSpan(
                  text: '$label ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: text),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
