import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';

/// Compact card showing the user's current daily streak.
class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.streakDays});

  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isActive = streakDays > 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Text(
            isActive ? '🔥' : '💤',
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(width: AppSpacing.x3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _streakLabel(streakDays),
                style: AppTypography.titleMedium.copyWith(
                  color: isActive ? AppColors.warning : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Chuỗi ngày học',
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

  String _streakLabel(int days) {
    if (days == 0) return 'Bắt đầu hôm nay!';
    if (days == 1) return '1 ngày';
    return '$days ngày';
  }
}
