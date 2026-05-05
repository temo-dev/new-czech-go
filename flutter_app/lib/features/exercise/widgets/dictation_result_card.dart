import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';

/// V18 — DictationResultCard renders the per-sentence accuracy + diff for a
/// completed psani_3_dictation attempt.
///
/// Three zones (no tabs to keep it readable on small phones):
///  1. Hero — overall score X/N + PASS/FAIL badge.
///  2. Per-sentence accuracy bars (green ≥ 80%, orange < 80%).
///  3. Per-sentence diff cards: reference text with deletions/insertions
///     highlighted via inline TextSpan, plus optional LLM feedback line.
///
/// When LLM annotation is unavailable, [DictationSentenceScoreView.diffChunks]
/// is empty and the card falls back to plain reference + learner text. A
/// banner at the top notes the missing detailed feedback.
class DictationResultCard extends StatelessWidget {
  const DictationResultCard({
    super.key,
    required this.result,
  });

  final DictationResultView result;

  bool get _hasAnyLLM =>
      result.sentences.any((s) => s.feedbackVI.isNotEmpty || s.diffChunks.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Hero(result: result),
          const SizedBox(height: AppSpacing.x4),
          if (!_hasAnyLLM)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x3,
                vertical: AppSpacing.x2,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l.dictationLLMUnavailable,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          if (!_hasAnyLLM) const SizedBox(height: AppSpacing.x3),
          Text(
            l.dictationResultPerSentence,
            style: AppTypography.titleSmall,
          ),
          const SizedBox(height: AppSpacing.x2),
          ...result.sentences.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x3),
              child: _SentenceCard(score: s),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.result});
  final DictationResultView result;

  @override
  Widget build(BuildContext context) {
    final passed = result.passed;
    final badgeColor = passed ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.secondary, AppColors.secondary.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              style: AppTypography.scoreDisplay.copyWith(color: Colors.white),
              children: [
                TextSpan(text: '${result.overallScore}'),
                TextSpan(
                  text: ' / ${result.maxPoints}',
                  style: AppTypography.titleLarge.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              passed ? 'ĐẠT ${result.passThresholdPercent}%' : 'CHƯA ĐẠT',
              style: AppTypography.labelMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SentenceCard extends StatelessWidget {
  const _SentenceCard({required this.score});
  final DictationSentenceScoreView score;

  Color get _accuracyColor =>
      score.accuracy >= 0.8 ? AppColors.success : AppColors.primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accuracyColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${score.idx + 1}',
                  style: AppTypography.labelMedium.copyWith(
                    color: _accuracyColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: score.accuracy.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor:
                        AppColors.onSurface.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation(_accuracyColor),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Text(
                '${(score.accuracy * 100).round()}%',
                style: AppTypography.labelMedium.copyWith(
                  color: _accuracyColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          _DictationDiff(score: score),
          if (score.feedbackVI.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x2),
            Text(
              score.feedbackVI,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Inline diff renderer using LLM-provided diff_chunks when available; falls
/// back to displaying plain reference + learner text on separate lines.
class _DictationDiff extends StatelessWidget {
  const _DictationDiff({required this.score});
  final DictationSentenceScoreView score;

  @override
  Widget build(BuildContext context) {
    if (score.diffChunks.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line(label: 'Đáp án', text: score.reference, color: AppColors.success),
          const SizedBox(height: 4),
          _line(label: 'Bạn viết', text: score.learner, color: AppColors.onSurface),
        ],
      );
    }

    final spans = <TextSpan>[];
    for (final chunk in score.diffChunks) {
      switch (chunk.kind) {
        case 'replaced':
          if (chunk.targetText.isNotEmpty) {
            spans.add(_redSpan(chunk.targetText));
          }
          if (chunk.sourceText.isNotEmpty) {
            spans.add(_greenSpan(chunk.sourceText));
          }
          break;
        case 'deleted':
          spans.add(_redSpan(chunk.targetText));
          break;
        case 'inserted':
          spans.add(_greenSpan(chunk.sourceText));
          break;
        default:
          spans.add(TextSpan(
            text: chunk.sourceText.isNotEmpty ? chunk.sourceText : chunk.targetText,
            style: AppTypography.bodyMedium,
          ));
      }
    }
    return RichText(
      text: TextSpan(
        style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
        children: spans,
      ),
    );
  }

  TextSpan _redSpan(String text) => TextSpan(
        text: text,
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.error,
          decoration: TextDecoration.lineThrough,
        ),
      );

  TextSpan _greenSpan(String text) => TextSpan(
        text: text,
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.success,
          fontWeight: FontWeight.w700,
        ),
      );

  Widget _line({required String label, required String text, required Color color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
