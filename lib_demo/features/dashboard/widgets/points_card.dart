import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';

/// Compact card showing the user's total XP and optional weekly rank.
class PointsCard extends StatelessWidget {
  const PointsCard({
    super.key,
    required this.totalXp,
    this.weeklyRank,
  });

  final int totalXp;
  final int? weeklyRank;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.xpGold.withValues(alpha: 0.15),
              borderRadius: AppRadius.smAll,
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: AppColors.xpGold,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$totalXp XP',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.xpGold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                weeklyRank != null
                    ? 'Hạng $weeklyRank tuần này'
                    : 'Điểm tích luỹ',
                style: AppTypography.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
