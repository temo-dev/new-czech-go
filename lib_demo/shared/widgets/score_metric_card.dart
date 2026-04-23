import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';

/// Single metric card used on AI feedback screens.
/// Displays label, numeric score, and an arc progress indicator.
class ScoreMetricCard extends StatelessWidget {
  const ScoreMetricCard({
    super.key,
    required this.label,
    required this.score,
    this.maxScore = 100,
  });

  final String label;
  final int score;
  final int maxScore;

  Color _scoreColor() {
    final pct = score / maxScore;
    if (pct >= 0.85) return AppColors.scoreExcellent;
    if (pct >= 0.70) return AppColors.scoreGood;
    if (pct >= 0.50) return AppColors.scoreFair;
    return AppColors.scorePoor;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _scoreColor();
    final progress = (score / maxScore).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 5,
                  backgroundColor: cs.outlineVariant,
                  color: color,
                ),
                Text(
                  '$score',
                  style: AppTypography.titleSmall
                      .copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            label,
            style: AppTypography.labelSmall
                .copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
