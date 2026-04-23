import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/ai_teacher/models/ai_teacher_review.dart';
import 'package:app_czech/features/ai_teacher/widgets/ai_teacher_review_widgets.dart';
import 'package:app_czech/shared/models/question_model.dart';

/// Slides up after submission to show the correct answer and explanation.
/// Can be embedded inline (isInline: true) or shown as a bottom sheet.
class ExplanationPanel extends StatelessWidget {
  const ExplanationPanel({
    super.key,
    required this.question,
    required this.isCorrect,
    this.submittedAnswer,
    this.source = 'practice',
    this.exerciseId,
    this.lessonId,
    this.examAttemptId,
    this.isInline = true,
  });

  final Question question;
  final bool isCorrect;
  final QuestionAnswer? submittedAnswer;
  final String source;
  final String? exerciseId;
  final String? lessonId;
  final String? examAttemptId;
  final bool isInline;

  /// Show as a modal bottom sheet. Returns when user taps "Tiếp tục".
  static Future<void> show(
    BuildContext context, {
    required Question question,
    required bool isCorrect,
    QuestionAnswer? submittedAnswer,
    String source = 'practice',
    String? exerciseId,
    String? lessonId,
    String? examAttemptId,
    VoidCallback? onContinue,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheetWrapper(
        question: question,
        isCorrect: isCorrect,
        submittedAnswer: submittedAnswer,
        source: source,
        exerciseId: exerciseId,
        lessonId: lessonId,
        examAttemptId: examAttemptId,
        onContinue: onContinue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ExplanationContent(
      question: question,
      isCorrect: isCorrect,
      submittedAnswer: submittedAnswer,
      source: source,
      exerciseId: exerciseId,
      lessonId: lessonId,
      examAttemptId: examAttemptId,
    );
  }
}

// ── Bottom sheet wrapper ───────────────────────────────────────────────────────

class _BottomSheetWrapper extends StatelessWidget {
  const _BottomSheetWrapper({
    required this.question,
    required this.isCorrect,
    this.submittedAnswer,
    required this.source,
    this.exerciseId,
    this.lessonId,
    this.examAttemptId,
    this.onContinue,
  });

  final Question question;
  final bool isCorrect;
  final QuestionAnswer? submittedAnswer;
  final String source;
  final String? exerciseId;
  final String? lessonId;
  final String? examAttemptId;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4, AppSpacing.x3, AppSpacing.x4, AppSpacing.x4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.x4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _ExplanationContent(
                question: question,
                isCorrect: isCorrect,
                submittedAnswer: submittedAnswer,
                source: source,
                exerciseId: exerciseId,
                lessonId: lessonId,
                examAttemptId: examAttemptId,
              ),
              const SizedBox(height: AppSpacing.x4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onContinue?.call();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.x4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Tiếp tục',
                      style: AppTypography.labelLarge
                          .copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Content ────────────────────────────────────────────────────────────────────

class _ExplanationContent extends StatelessWidget {
  const _ExplanationContent({
    required this.question,
    required this.isCorrect,
    this.submittedAnswer,
    this.source = 'practice',
    this.exerciseId,
    this.lessonId,
    this.examAttemptId,
  });

  final Question question;
  final bool isCorrect;
  final QuestionAnswer? submittedAnswer;
  final String source;
  final String? exerciseId;
  final String? lessonId;
  final String? examAttemptId;

  bool get _isSubjective =>
      question.type == QuestionType.writing ||
      question.type == QuestionType.speaking;

  @override
  Widget build(BuildContext context) {
    if (_isSubjective) {
      return _buildSubjectiveContent(context);
    }
    return _buildObjectiveContent(context);
  }

  // Writing / Speaking — no "Đúng/Sai", show criteria + model answer
  Widget _buildSubjectiveContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Submitted banner
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4, vertical: AppSpacing.x3),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.15),
            ),
          ),
          child: Row(
            children: [
              Icon(
                question.type == QuestionType.writing
                    ? Icons.edit_note_rounded
                    : Icons.mic_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Text(
                  question.type == QuestionType.writing
                      ? 'Đã nộp bài viết — bài tự luận được chấm riêng'
                      : 'Đã nộp bài nói — bài tự luận được chấm riêng',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Tiêu chí chấm
        if (question.explanation.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x4),
          Text(
            'Tiêu chí chấm điểm',
            style: AppTypography.labelMedium
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            question.explanation,
            style: AppTypography.bodyMedium.copyWith(height: 1.6),
          ),
        ],

        // Bài mẫu
        if (question.correctAnswer != null &&
            question.correctAnswer!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x4),
          Text(
            question.type == QuestionType.writing
                ? 'Bài mẫu tham khảo'
                : 'Câu trả lời gợi ý',
            style: AppTypography.labelMedium
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.x2),
          Container(
            padding: const EdgeInsets.all(AppSpacing.x3),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Text(
              question.correctAnswer!,
              style: AppTypography.bodyMedium.copyWith(
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // MCQ / FillBlank — standard "Đúng/Sai" + explanation
  Widget _buildObjectiveContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Result banner
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4, vertical: AppSpacing.x3),
          decoration: BoxDecoration(
            color: isCorrect
                ? const Color(0xFFECFDF5)
                : AppColors.errorContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCorrect
                  ? const Color(0xFFD1FAE5)
                  : AppColors.error.withOpacity(0.15),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isCorrect ? Icons.verified_rounded : Icons.cancel_rounded,
                color: isCorrect ? const Color(0xFF059669) : AppColors.error,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.x3),
              Text(
                isCorrect ? 'Chính xác!' : 'Chưa đúng',
                style: AppTypography.labelSmall.copyWith(
                  color: isCorrect ? const Color(0xFF059669) : AppColors.error,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x4),

        // Correct answer (if wrong)
        if (!isCorrect && question.correctAnswer != null) ...[
          Text('Đáp án đúng',
              style: AppTypography.labelMedium
                  .copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.x1),
          Text(
            question.correctAnswer!,
            style: AppTypography.bodyMedium.copyWith(
              color: const Color(0xFF16A34A),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
        ],

        // Explanation
        if (question.explanation.isNotEmpty) ...[
          Text('Giải thích',
              style: AppTypography.labelMedium
                  .copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.x2),
          Text(
            question.explanation,
            style: AppTypography.bodyMedium.copyWith(height: 1.6),
          ),
          if (_objectiveReviewRequest != null) ...[
            const SizedBox(height: AppSpacing.x4),
            AiTeacherInlineReviewCard(
              request: _objectiveReviewRequest!,
              pendingLabel: isCorrect
                  ? 'AI Teacher đang chuẩn bị lời củng cố...'
                  : 'AI Teacher đang phân tích lỗi và gợi ý sửa...',
              emptyMessage: 'Chưa có AI Teacher review cho bài làm này.',
            ),
          ],
        ],
      ],
    );
  }

  AiTeacherReviewRequest? get _objectiveReviewRequest {
    final answer = submittedAnswer;
    if (answer == null) return null;
    if (_isSubjective) return null;
    if ((answer.selectedOptionId?.isEmpty ?? true) &&
        (answer.writtenAnswer?.trim().isEmpty ?? true)) {
      return null;
    }

    return AiTeacherReviewRequest.objective(
      source: source,
      question: question,
      answer: answer,
      exerciseId: exerciseId,
      lessonId: lessonId,
      examAttemptId: examAttemptId,
    );
  }
}
