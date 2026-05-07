import 'package:flutter/material.dart';

import 'package:flutter_app/core/theme/app_spacing.dart';
import 'package:flutter_app/features/home/widgets/level_badge.dart';
import 'package:flutter_app/features/home/widgets/level_progress_ring.dart';
import 'package:flutter_app/features/home/widgets/promotion_banner.dart';
import 'package:flutter_app/models/models.dart';

/// HomeLevelHeader composes the V21 home hero into a single embeddable
/// widget: the LevelBadge (top-right), the LevelProgressRing (centred
/// hero), and the PromotionBanner (sticky card below the ring).
///
/// Pure presentation — the caller wires the API fetch + refresh-on-pop.
/// The header is safe to embed inside any scrollable Column.
class HomeLevelHeader extends StatelessWidget {
  const HomeLevelHeader({
    super.key,
    required this.progress,
    required this.onTapBadge,
    required this.onTapPromotion,
  });

  final LevelProgressResponse progress;
  final VoidCallback onTapBadge;
  final void Function(String mockTestId) onTapPromotion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4, AppSpacing.x2, AppSpacing.x4, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: LevelBadge(
              currentLevel: progress.currentLevel,
              unlockedLevels: progress.unlockedLevels,
              onTap: onTapBadge,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        Center(
          child: LevelProgressRing(
            currentLevel: progress.currentLevel,
            nextLevel: progress.nextLevel,
            skillMastery: progress.skillMastery,
            coveragePct: progress.coveragePct,
            coverageThresholdPct: progress.coverageThresholdPct,
            promotionUnlocked: progress.promotionUnlocked,
          ),
        ),
        PromotionBanner(
          promotionUnlocked: progress.promotionUnlocked,
          targetLevel: progress.nextLevel,
          unlockedLevels: progress.unlockedLevels,
          promotionTestId: progress.promotionTestID,
          onTap: onTapPromotion,
        ),
      ],
    );
  }
}
