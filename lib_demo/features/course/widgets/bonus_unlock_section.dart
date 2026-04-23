import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';

/// Bonus unlock section shown at the bottom of the lesson.
/// Disabled until all 6 blocks are completed; then shows an unlock CTA.
class BonusUnlockSection extends StatelessWidget {
  const BonusUnlockSection({
    super.key,
    required this.allBlocksDone,
    required this.bonusUnlocked,
    required this.bonusXpCost,
    this.onUnlock,
  });

  final bool allBlocksDone;
  final bool bonusUnlocked;
  final int bonusXpCost;
  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (bonusUnlocked) {
      return _BonusUnlockedCard();
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: allBlocksDone
            ? AppColors.xpGold.withValues(alpha: 0.08)
            : cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: allBlocksDone
              ? AppColors.xpGold.withValues(alpha: 0.4)
              : cs.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.stars_rounded,
                size: 36,
                color: allBlocksDone
                    ? AppColors.xpGold
                    : cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              if (!allBlocksDone)
                const Icon(Icons.lock_rounded, size: 16, color: Colors.white70),
            ],
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nội dung thưởng',
                  style: AppTypography.titleSmall.copyWith(
                    color: allBlocksDone
                        ? cs.onSurface
                        : cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  allBlocksDone
                      ? 'Hoàn thành 6/6 bài tập để mở khoá!'
                      : 'Hoàn thành tất cả bài tập để mở khoá.',
                  style: AppTypography.bodySmall.copyWith(
                    color: allBlocksDone
                        ? cs.onSurfaceVariant
                        : cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          if (allBlocksDone) ...[
            const SizedBox(width: AppSpacing.x3),
            FilledButton.icon(
              onPressed: onUnlock,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.xpGold,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x3,
                  vertical: AppSpacing.x2,
                ),
                textStyle: AppTypography.labelMedium,
              ),
              icon: const Icon(Icons.bolt_rounded, size: 16),
              label: Text('$bonusXpCost XP'),
            ),
          ],
        ],
      ),
    );
  }
}

class _BonusUnlockedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.xpGold.withValues(alpha: 0.1),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.xpGold.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, size: 32, color: AppColors.xpGold),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nội dung thưởng đã mở khoá!',
                    style: AppTypography.titleSmall),
                Text(
                  'Truy cập tài liệu bổ sung và bài tập nâng cao.',
                  style: AppTypography.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
