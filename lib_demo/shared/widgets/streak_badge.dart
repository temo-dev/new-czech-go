import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_radius.dart';

/// Fire icon + streak day count pill (primaryFixed bg).
/// Used in Dashboard header and Progress screen.
class StreakBadge extends StatelessWidget {
  const StreakBadge({
    super.key,
    required this.streakDays,
    this.compact = false,
  });

  final int streakDays;
  /// When true, shows compact inline version (no background pill).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded,
              color: AppColors.warning, size: 16),
          const SizedBox(width: 4),
          Text(
            '$streakDays ngày',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.warning,
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
          const Icon(Icons.local_fire_department_rounded,
              color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Text(
            '$streakDays ngày',
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
