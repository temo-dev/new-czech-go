import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_radius.dart';

/// Rank pill: `#12 tuần này` in a primaryFixed rounded container.
/// Used in Dashboard quick stats and Leaderboard screen.
class RankBadge extends StatelessWidget {
  const RankBadge({
    super.key,
    required this.rank,
    this.suffix = 'tuần này',
    this.compact = false,
  });

  final int rank;
  final String suffix;
  /// When true, shows compact inline text only.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rankText = '#$rank';

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.leaderboard_rounded,
              color: AppColors.primary, size: 16),
          const SizedBox(width: 4),
          Text(
            '$rankText $suffix',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.leaderboard_rounded,
              color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Text(
            '$rankText $suffix',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
