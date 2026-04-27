import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';

/// Shows the result of an objective (listening/reading) attempt.
class ObjectiveResultCard extends StatelessWidget {
  const ObjectiveResultCard({
    super.key,
    required this.result,
    required this.onRetry,
  });

  final AttemptResult result;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final feedback = result.feedback;
    final objResult = feedback?.objectiveResult;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Score header
        Container(
          padding: const EdgeInsets.all(AppSpacing.x4),
          decoration: BoxDecoration(
            color: _scoreColor(objResult).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _scoreColor(objResult).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Text(
                objResult != null ? '${objResult.score}/${objResult.maxScore}' : '--',
                style: AppTypography.headlineLarge.copyWith(
                  color: _scoreColor(objResult),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feedback?.readinessLevel ?? '',
                      style: AppTypography.labelLarge.copyWith(color: _scoreColor(objResult)),
                    ),
                    if (feedback?.overallSummary.isNotEmpty == true)
                      Text(feedback!.overallSummary, style: AppTypography.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x4),

        // Per-question breakdown
        if (objResult != null && objResult.breakdown.isNotEmpty) ...[
          Text(AppLocalizations.of(context).objectiveBreakdownTitle, style: AppTypography.titleSmall),
          const SizedBox(height: AppSpacing.x2),
          ...objResult.breakdown.map((q) => _QuestionRow(q: q)),
          const SizedBox(height: AppSpacing.x4),
        ],

        // Retry button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(AppLocalizations.of(context).retryCta, style: AppTypography.labelLarge.copyWith(color: AppColors.primary)),
          ),
        ),
      ],
    );
  }

  Color _scoreColor(ObjectiveResult? r) {
    if (r == null) return AppColors.outline;
    final frac = r.maxScore > 0 ? r.score / r.maxScore : 0.0;
    if (frac >= 0.8) return AppColors.success;
    if (frac >= 0.5) return AppColors.info;
    return AppColors.error;
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({required this.q});
  final QuestionResult q;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            q.isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: q.isCorrect ? AppColors.success : AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTypography.bodySmall.copyWith(color: AppColors.onSurface),
                children: [
                  TextSpan(text: AppLocalizations.of(context).objectiveQuestionLabel(q.questionNo), style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: q.learnerAnswer.isNotEmpty ? q.learnerAnswer : AppLocalizations.of(context).objectiveNoAnswer),
                  if (!q.isCorrect) ...[
                    const TextSpan(text: ' → '),
                    TextSpan(
                      text: q.correctAnswer,
                      style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
