import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';

/// Footer bar showing "x / 6 hoàn thành" with a progress track.
class ExerciseProgressFooter extends StatelessWidget {
  const ExerciseProgressFooter({
    super.key,
    required this.completed,
    required this.total,
  });

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fraction = total > 0 ? completed / total : 0.0;
    final allDone = completed >= total && total > 0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      decoration: BoxDecoration(
        color: allDone ? AppColors.successContainer : cs.surfaceContainer,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: allDone
              ? AppColors.success.withValues(alpha: 0.3)
              : cs.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            allDone
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: allDone ? AppColors.success : cs.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.x2),
          Text(
            '$completed / $total hoàn thành',
            style: AppTypography.labelMedium.copyWith(
              color: allDone ? AppColors.success : cs.onSurface,
            ),
          ),
          const SizedBox(width: AppSpacing.x4),
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadius.fullAll,
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
                color: allDone ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
