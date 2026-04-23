import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/course/models/course_models.dart';
import 'package:app_czech/shared/widgets/progress_ring.dart';

/// Card representing a course module with progress ring and locked overlay.
class ModuleCard extends StatelessWidget {
  const ModuleCard({
    super.key,
    required this.module,
    required this.onTap,
  });

  final ModuleSummary module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLocked = module.isLocked;
    final pct = module.progressFraction;

    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.x4),
        decoration: BoxDecoration(
          color: isLocked
              ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
              : cs.surfaceContainer,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: isLocked
                ? cs.outlineVariant.withValues(alpha: 0.4)
                : cs.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            // Progress ring or lock icon
            if (isLocked)
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(
                  Icons.lock_rounded,
                  color: cs.onSurfaceVariant,
                  size: 22,
                ),
              )
            else
              ProgressRing(
                value: pct,
                size: 52,
                strokeWidth: 5,
                color: pct == 1 ? AppColors.success : AppColors.primary,
                label: pct == 0
                    ? ''
                    : pct == 1
                        ? '✓'
                        : '${(pct * 100).round()}%',
                labelStyle: AppTypography.labelSmall.copyWith(
                  color: pct == 1 ? AppColors.success : AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(width: AppSpacing.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Module ${module.orderIndex + 1}',
                    style: AppTypography.labelSmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    module.title,
                    style: AppTypography.titleSmall.copyWith(
                      color: isLocked ? cs.onSurfaceVariant : cs.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    '${module.lessonCount} bài học'
                    '${module.completedCount > 0 ? ' · ${module.completedCount}/${module.lessonCount} hoàn thành' : ''}',
                    style: AppTypography.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!isLocked) ...[
              const SizedBox(width: AppSpacing.x2),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
