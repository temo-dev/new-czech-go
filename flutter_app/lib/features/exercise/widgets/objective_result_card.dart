import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';

/// Shows the result of an objective (listening/reading) attempt.
///
/// Pass [showPassage]=true (with [exerciseId] and [client]) for reading
/// exercises — renders an async-loaded collapsible passage below the breakdown.
class ObjectiveResultCard extends StatelessWidget {
  const ObjectiveResultCard({
    super.key,
    required this.result,
    required this.onRetry,
    this.showPassage = false,
    this.exerciseId = '',
    this.client,
  });

  final AttemptResult result;
  final VoidCallback onRetry;
  final bool showPassage;
  final String exerciseId;
  final ApiClient? client;

  @override
  Widget build(BuildContext context) {
    final feedback = result.feedback;
    final objResult = feedback?.objectiveResult;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Score header ─────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(AppSpacing.x4),
          decoration: BoxDecoration(
            color: _scoreColor(objResult).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _scoreColor(objResult).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Text(
                objResult != null
                    ? '${objResult.score}/${objResult.maxScore}'
                    : '--',
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
                    if (feedback?.overallSummary.isNotEmpty == true)
                      Text(
                        feedback!.overallSummary,
                        style: AppTypography.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x4),

        // ── Per-question breakdown ────────────────────────────────────────────
        if (objResult != null && objResult.breakdown.isNotEmpty) ...[
          Text(
            AppLocalizations.of(context).objectiveBreakdownTitle,
            style: AppTypography.titleSmall,
          ),
          const SizedBox(height: AppSpacing.x2),
          ...objResult.breakdown.map((q) => _QuestionCard(q: q)),
          const SizedBox(height: AppSpacing.x4),
        ],

        // ── Passage (doc only) ───────────────────────────────────────────────
        if (showPassage && exerciseId.isNotEmpty && client != null) ...[
          _PassageSection(client: client!, exerciseId: exerciseId),
          const SizedBox(height: AppSpacing.x4),
        ],

        // ── Retry button ─────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              AppLocalizations.of(context).retryCta,
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.primary,
              ),
            ),
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

// ── Question card ─────────────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.q});
  final QuestionResult q;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bg = q.isCorrect
        ? AppColors.success.withValues(alpha: 0.08)
        : AppColors.error.withValues(alpha: 0.08);
    final borderColor = q.isCorrect
        ? AppColors.success.withValues(alpha: 0.25)
        : AppColors.error.withValues(alpha: 0.25);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3,
          vertical: AppSpacing.x3,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status icon ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                q.isCorrect
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: q.isCorrect ? AppColors.success : AppColors.error,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.x2),
            // ── Content ──────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.objectiveQuestionLabel(q.questionNo),
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  if (q.questionText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      q.questionText,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  if (q.isCorrect)
                    Text(
                      q.correctAnswer.isNotEmpty
                          ? q.correctAnswer
                          : l.objectiveNoAnswer,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else ...[
                    // Learner's wrong answer
                    _AnswerRow(
                      label: l.objectiveYourAnswer,
                      value: q.learnerAnswer.isNotEmpty
                          ? q.learnerAnswer
                          : l.objectiveNoAnswer,
                      valueColor: AppColors.error,
                    ),
                    const SizedBox(height: 2),
                    // Correct answer
                    _AnswerRow(
                      label: l.objectiveCorrectAnswer,
                      value: q.correctAnswer,
                      valueColor: AppColors.success,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Passage section (doc only) ────────────────────────────────────────────────

class _PassageSection extends StatefulWidget {
  const _PassageSection({required this.client, required this.exerciseId});

  final ApiClient client;
  final String exerciseId;

  @override
  State<_PassageSection> createState() => _PassageSectionState();
}

class _PassageSectionState extends State<_PassageSection> {
  String? _passage;
  bool _loading = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final raw = await widget.client.getExercise(widget.exerciseId);
      final detail = ExerciseDetail.fromJson(raw);
      if (!mounted) return;
      setState(() {
        _passage = detail.cteniText.isNotEmpty ? detail.cteniText : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _passage = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    if (_loading) {
      return const LinearProgressIndicator(
        minHeight: 2,
        color: AppColors.primary,
      );
    }

    final text = _passage;
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (v) => setState(() => _expanded = v),
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x3,
            vertical: 0,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.x3,
            0,
            AppSpacing.x3,
            AppSpacing.x3,
          ),
          title: Text(
            _expanded ? l.hidePassage : l.viewPassage,
            style: AppTypography.labelMedium,
          ),
          children: [
            SelectableText(
              text,
              style: AppTypography.bodySmall.copyWith(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
