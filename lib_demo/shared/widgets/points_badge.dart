import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_radius.dart';

/// Star icon + formatted XP amount pill.
/// Used in Dashboard quick stats and UnlockBonus screen.
class PointsBadge extends StatelessWidget {
  const PointsBadge({
    super.key,
    required this.xp,
    this.compact = false,
  });

  final int xp;
  /// When true, shows compact inline version (no background pill).
  final bool compact;

  String _format(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final label = '${_format(xp)} XP';

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.payments_rounded, color: AppColors.xpGold, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.xpGold,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7), // amber-100
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.payments_rounded, color: AppColors.xpGold, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: const Color(0xFF92400E), // amber-800
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
