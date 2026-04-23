import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/shared/widgets/status_badge.dart';

/// Bento metric card — used in Speaking/Writing AI feedback screens.
/// Shows: icon + score (EB Garamond italic) + label + optional status badge.
///
/// HTML: bg-surfaceContainerLow rounded-xl p-4 border border-outline-variant/30
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.score,
    this.maxScore = 100,
    this.icon,
    this.iconColor,
    this.badgeLabel,
    this.badgeVariant = StatusBadgeVariant.good,
    this.showProgressBar = true,
  });

  final String label;
  final int score;
  final int maxScore;
  final IconData? icon;
  final Color? iconColor;
  final String? badgeLabel;
  final StatusBadgeVariant badgeVariant;
  final bool showProgressBar;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.primary;
    final pct = score / maxScore;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              if (badgeLabel != null)
                StatusBadge(label: badgeLabel!, variant: badgeVariant),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$score%',
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.onBackground,
            ),
          ),
          if (showProgressBar) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 4,
                backgroundColor: AppColors.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _barColor(score),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _barColor(int score) {
    if (score >= 85) return AppColors.scoreExcellent;
    if (score >= 70) return AppColors.primary;
    if (score >= 50) return AppColors.scoreFair;
    return AppColors.scorePoor;
  }
}

/// 2×2 grid of MetricCards — used in Speaking/Writing AI feedback.
class MetricCardGrid extends StatelessWidget {
  const MetricCardGrid({
    super.key,
    required this.metrics,
  });

  final List<MetricCard> metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: metrics,
    );
  }
}

/// Skill progress bar row — label + icon + colored bar + percentage.
/// Used in Progress screen, Writing AI feedback.
class SkillProgressRow extends StatelessWidget {
  const SkillProgressRow({
    super.key,
    required this.label,
    required this.value,    // 0.0–1.0
    this.icon,
    this.color,
    this.showPercent = true,
  });

  final String label;
  final double value;
  final IconData? icon;
  final Color? color;
  final bool showPercent;

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? AppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: barColor),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.onBackground,
                      ),
                    ),
                    if (showPercent)
                      Text(
                        '${(value * 100).round()}%',
                        style: AppTypography.labelMedium.copyWith(
                          color: barColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
